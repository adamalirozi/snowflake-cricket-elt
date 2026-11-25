-- =============================================================================
-- 02_raw_ingestion.sql
-- S3 -> Snowflake auto-ingestion with Snowpipe, plus a stream on the raw table.
--
-- Replace the three placeholders before running:
--   <AWS_ACCOUNT_ID>   12-digit AWS account that owns the bucket
--   <IAM_ROLE_NAME>    IAM role Snowflake will assume to read the bucket
--   <S3_BUCKET>        bucket name; files are expected under /cricket/
--
-- The storage integration needs ACCOUNTADMIN (or CREATE INTEGRATION).
-- =============================================================================

use database cricket_analytics;
use schema raw;

-- 1. Storage integration -----------------------------------------------------
create or replace storage integration s3_int
  type                      = external_stage
  storage_provider          = 'S3'
  enabled                   = true
  storage_aws_role_arn      = 'arn:aws:iam::<AWS_ACCOUNT_ID>:role/<IAM_ROLE_NAME>'
  storage_allowed_locations = ('s3://<S3_BUCKET>/cricket/');

-- Copy STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID from this output
-- into the IAM role's trust policy.
describe storage integration s3_int;

-- 2. External stage ----------------------------------------------------------
create or replace stage raw.s3_ext_stage
  storage_integration = s3_int
  url                 = 's3://<S3_BUCKET>/cricket/'
  file_format         = (type = json);

-- 3. Snowpipe: load every new file as one VARIANT row ------------------------
create or replace pipe raw.s3_pipe
  auto_ingest = true
as
  copy into raw.raw_data
  from (select $1, metadata$filename as filename from @raw.s3_ext_stage)
  on_error = continue;

-- 4. Stream: tracks newly landed rows for the task graph ---------------------
--    Created before any files load, so the first batch is picked up too.
create or replace stream raw.stream_raw_data
  on table raw.raw_data
  append_only = true;

-- Copy the pipe's NOTIFICATION_CHANNEL (an SQS ARN) into an S3 event
-- notification on the bucket: "All object create events", prefix cricket/.
show pipes in schema raw;

-- Load files that were already in the bucket before the notification existed.
alter pipe raw.s3_pipe refresh;
