-- =============================================================================
-- 05_enable_tasks.sql
-- Start (or stop) the whole task graph.
-- =============================================================================

use database cricket_analytics;

-- Resumes the root task and every task downstream of it.
select system$task_dependents_enable('cricket_analytics.dw.task_raw_data');

-- To stop the pipeline, suspending the root is enough:
-- alter task dw.task_raw_data suspend;
