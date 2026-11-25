-- =============================================================================
-- 04_dw_tasks.sql
-- Task graph, part 2: staging -> warehouse (incremental, idempotent).
--
--   (all four staging tasks) -> task_teams -> task_players
--                            -> task_match_info -> task_match_innings
--
-- Re-running a batch never duplicates rows: teams and matches are filtered
-- against what is already loaded, and players are MERGEd.
-- =============================================================================

use database cricket_analytics;

-- New teams only
create or replace task dw.task_teams
  warehouse = compute_wh
  after dw.task_stg_teams, dw.task_stg_players, dw.task_stg_match, dw.task_stg_match_innings
as
  insert into dw.teams
  select dw.seq_teams.nextval as team_id, s.team_name, s.team_type
  from staging.stg_teams s
  where s.team_name not in (select team_name from dw.teams);

-- Players: insert new ones, extend the team list of known ones
create or replace task dw.task_players
  warehouse = compute_wh
  after dw.task_teams
as
  merge into dw.players as target
  using (
    select p.player_name,
           array_agg(distinct t.team_id) as teams
    from staging.stg_players p
    join dw.teams t on p.team_name = t.team_name
    group by 1
  ) as source
  on target.player_name = source.player_name
  when matched then update set
    teams = array_distinct(array_cat(target.teams, source.teams))
  when not matched then insert (player_id, player_name, teams)
    values (dw.seq_players.nextval, source.player_name, source.teams);

-- Matches not loaded yet (keyed on source file name)
create or replace task dw.task_match_info
  warehouse = compute_wh
  after dw.task_players
as
  insert into dw.match_info
  select dw.seq_matches.nextval as match_id,
         mi.match_type, mi.gender, mi.season, mi.city, mi.venue, mi.match_date,
         t1.team_id  as team1_id,
         t2.team_id  as team2_id,
         t3.team_id  as toss_winner_id,
         mi.toss_decision,
         t4.team_id  as match_winner_id,
         mi.margin, mi.event_name, mi.event_type,
         p.player_id as pom_id,
         mi.filename
  from staging.stg_match_info mi
  join      dw.teams   t1 on mi.team1        = t1.team_name
  join      dw.teams   t2 on mi.team2        = t2.team_name
  join      dw.teams   t3 on mi.toss_winner  = t3.team_name
  left join dw.teams   t4 on mi.match_winner = t4.team_name
  left join dw.players p  on mi.pom          = p.player_name
  where mi.filename not in (select filename from dw.match_info);

-- Ball-by-ball facts for matches not loaded yet
create or replace task dw.task_match_innings
  warehouse = compute_wh
  after dw.task_match_info
as
  insert into dw.match_innings
  select mi.match_id, ing.inning_id, ing.over,
         t1.team_id as batting_team_id,
         ing.ball_in_over, ing.batter, ing.bowler, ing.non_striker,
         ing.runs_batter, ing.extra_type, ing.runs_extras, ing.runs_total,
         ing.dismissal_kind, ing.out_player, ing.is_powerplay
  from staging.stg_match_innings ing
  join dw.match_info mi on ing.filename     = mi.filename
  join dw.teams      t1 on ing.batting_team = t1.team_name
  where mi.match_id not in (select match_id from dw.match_innings);
