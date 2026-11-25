-- =============================================================================
-- 06_checks_and_insights.sql
-- Monitoring queries, then example analysis on the warehouse.
-- =============================================================================

use database cricket_analytics;

-- ---------------------------------------------------------------------------
-- Pipeline health
-- ---------------------------------------------------------------------------
select system$pipe_status('raw.s3_pipe');

select name, state, scheduled_time, completed_time, error_message
from table(information_schema.task_history(
       scheduled_time_range_start => dateadd('hour', -24, current_timestamp())))
order by scheduled_time desc;

select 'teams'         as table_name, count(*) as row_count from dw.teams         union all
select 'players',                     count(*)              from dw.players       union all
select 'match_info',                  count(*)              from dw.match_info    union all
select 'match_innings',               count(*)              from dw.match_innings;

-- ---------------------------------------------------------------------------
-- Insights
-- ---------------------------------------------------------------------------

-- Innings totals, split into powerplay and the rest of the innings
select m.match_date,
       t.team_name                                   as batting_team,
       f.inning_id,
       sum(f.runs_total)                             as runs,
       count_if(f.out_player is not null)            as wickets,
       sum(iff(f.is_powerplay = 1, f.runs_total, 0)) as powerplay_runs,
       sum(iff(f.is_powerplay = 0, f.runs_total, 0)) as other_runs
from dw.match_innings f
join dw.match_info m on f.match_id        = m.match_id
join dw.teams      t on f.batting_team_id = t.team_id
group by all
order by m.match_date, f.inning_id;

-- Top run scorers (wides do not count as balls faced)
select batter,
       sum(runs_batter)                              as runs,
       count_if(coalesce(extra_type, '') <> 'wides') as balls_faced,
       round(100 * runs / nullif(balls_faced, 0), 1) as strike_rate
from dw.match_innings
group by batter
order by runs desc
limit 10;

-- Does winning the toss help?
select count(*)                                   as matches,
       count_if(toss_winner_id = match_winner_id) as toss_winner_won,
       round(100 * toss_winner_won
             / nullif(count_if(match_winner_id is not null), 0), 1) as pct_of_decided
from dw.match_info;
