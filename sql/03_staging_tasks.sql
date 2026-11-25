-- =============================================================================
-- 03_staging_tasks.sql
-- Task graph, part 1: stream -> staging.
--
--   task_raw_data            (root, every minute, only when the stream has data)
--     ├── task_stg_teams
--     ├── task_stg_players
--     ├── task_stg_match
--     └── task_stg_match_innings
--
-- Tasks are created suspended; 05_enable_tasks.sql starts them.
-- =============================================================================

use database cricket_analytics;

-- Root: move the new batch out of the stream (this consumes the stream).
create or replace task dw.task_raw_data
  warehouse = compute_wh
  schedule  = '1 MINUTE'
  when system$stream_has_data('raw.stream_raw_data')
as
begin
  truncate table staging.stg_raw_data;
  insert into staging.stg_raw_data
  select raw_file, filename
  from raw.stream_raw_data;
end;

-- Teams
create or replace task dw.task_stg_teams
  warehouse = compute_wh
  after dw.task_raw_data
as
begin
  truncate table staging.stg_teams;
  insert into staging.stg_teams
  select f0.value::varchar                as team_name,
         raw_file:info.team_type::varchar as team_type
  from staging.stg_raw_data,
       lateral flatten(raw_file:info.teams) f0
  group by all;
end;

-- Players (info.players is an object keyed by team name)
create or replace task dw.task_stg_players
  warehouse = compute_wh
  after dw.task_raw_data
as
begin
  truncate table staging.stg_players;
  insert into staging.stg_players
  select f1.value::string as player_name,
         f0.key           as team_name
  from staging.stg_raw_data,
       lateral flatten(raw_file:info.players) f0,
       lateral flatten(f0.value)              f1
  group by all;
end;

-- Match info: one row per file
create or replace task dw.task_stg_match
  warehouse = compute_wh
  after dw.task_raw_data
as
begin
  truncate table staging.stg_match_info;
  insert into staging.stg_match_info
  select raw_file:info.match_type::string          as match_type,
         raw_file:info.gender::string              as gender,
         raw_file:info.season::string              as season,
         raw_file:info.city::string                as city,
         raw_file:info.venue::string               as venue,
         raw_file:info.dates[0]::date              as match_date,
         raw_file:info.teams[0]::string            as team1,
         raw_file:info.teams[1]::string            as team2,
         raw_file:info.toss.winner::string         as toss_winner,
         raw_file:info.toss.decision::string       as toss_decision,
         raw_file:info.outcome.winner::string      as match_winner,
         case
           when raw_file:info.outcome.by.wickets::string is not null
             then raw_file:info.outcome.by.wickets::string || ' wickets'
           when raw_file:info.outcome.by.runs::string is not null
             then raw_file:info.outcome.by.runs::string || ' runs'
           else 'no result'
         end                                       as margin,
         raw_file:info.event.name::string          as event_name,
         raw_file:info.team_type::string           as event_type,
         raw_file:info.player_of_match[0]::string  as pom,
         filename
  from staging.stg_raw_data;
end;

-- Ball-by-ball: innings -> overs -> deliveries, three levels of FLATTEN
create or replace task dw.task_stg_match_innings
  warehouse = compute_wh
  after dw.task_raw_data
as
begin
  truncate table staging.stg_match_innings;
  insert into staging.stg_match_innings
  select f0.index + 1                                  as inning_id,
         f.value:over::int + 1                         as over,
         f0.value:team::string                         as batting_team,
         f1.index + 1                                  as ball_in_over,
         f1.value:batter::string                       as batter,
         f1.value:bowler::string                       as bowler,
         f1.value:non_striker::string                  as non_striker,
         f1.value:runs.batter::int                     as runs_batter,
         object_keys(f1.value:extras)[0]::string       as extra_type,
         f1.value:runs.extras::int                     as runs_extras,
         f1.value:runs.total::int                      as runs_total,
         f1.value:wickets[0].kind::string              as dismissal_kind,
         f1.value:wickets[0].player_out::string        as out_player,
         -- Use the powerplay recorded in the file; fall back to the format default.
         coalesce(ceil(f0.value:powerplays[0].from), dp.start_over) as powerplays_start_over,
         coalesce(ceil(f0.value:powerplays[0].to),   dp.end_over)   as powerplays_end_over,
         case when over between powerplays_start_over and powerplays_end_over
              then 1 else 0 end                        as is_powerplay,
         filename
  from staging.stg_raw_data
  left join raw.default_powerplays dp
         on raw_file:info.match_type::string = dp.match_type,
       lateral flatten(raw_file:innings)    f0,
       lateral flatten(f0.value:overs)      f,
       lateral flatten(f.value:deliveries)  f1;
end;
