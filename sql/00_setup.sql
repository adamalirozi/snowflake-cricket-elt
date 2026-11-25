-- =============================================================================
-- 00_setup.sql
-- Database, schemas and warehouse for the cricket ELT pipeline.
-- Run as a role that can create databases and warehouses (e.g. SYSADMIN).
-- =============================================================================

create database if not exists cricket_analytics;

create schema if not exists cricket_analytics.raw;      -- landing zone: JSON as-is
create schema if not exists cricket_analytics.staging;  -- flattened, typed, per batch
create schema if not exists cricket_analytics.dw;       -- star schema + all tasks

-- Trial accounts already have COMPUTE_WH; this is a no-op there.
create warehouse if not exists compute_wh
  warehouse_size      = xsmall
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true;
