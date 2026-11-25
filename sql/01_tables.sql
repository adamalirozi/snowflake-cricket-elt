-- =============================================================================
-- 01_tables.sql
-- Tables and sequences for all three layers.
-- =============================================================================

use database cricket_analytics;

-- ---------------------------------------------------------------------------
-- RAW
-- ---------------------------------------------------------------------------
-- One row per JSON file, stored as VARIANT, plus the source file name.
create or replace table raw.raw_data (
    raw_file  variant,
    filename  varchar(100)
);

-- Default powerplay overs, used when a match file does not record them.
create or replace table raw.default_powerplays (
    match_type  varchar(10),
    start_over  int,
    end_over    int
);

insert into raw.default_powerplays values
    ('ODI', 1, 10),
    ('T20', 1, 6);

-- ---------------------------------------------------------------------------
-- STAGING  (truncated and reloaded for every new batch of files)
-- ---------------------------------------------------------------------------
create or replace table staging.stg_raw_data like raw.raw_data;

create or replace table staging.stg_match_info (
    match_type     varchar(200),
    gender         varchar(200),
    season         varchar(200),
    city           varchar(200),
    venue          varchar(200),
    match_date     date,
    team1          varchar(200),
    team2          varchar(200),
    toss_winner    varchar(200),
    toss_decision  varchar(200),
    match_winner   varchar(200),
    margin         varchar(200),
    event_name     varchar(200),
    event_type     varchar(200),
    pom            varchar(200),
    filename       varchar(100)
);

create or replace table staging.stg_match_innings (
    inning_id              number(38,0),
    over                   number(38,0),
    batting_team           varchar(200),
    ball_in_over           number(38,0),
    batter                 varchar(200),
    bowler                 varchar(200),
    non_striker            varchar(200),
    runs_batter            number(38,0),
    extra_type             varchar(200),
    runs_extras            number(38,0),
    runs_total             number(38,0),
    dismissal_kind         varchar(200),
    out_player             varchar(200),
    powerplays_start_over  float,
    powerplays_end_over    float,
    is_powerplay           number(1,0),
    filename               varchar(100)
);

create or replace table staging.stg_players (
    player_name  varchar(200),
    team_name    varchar(200)
);

create or replace table staging.stg_teams (
    team_name  varchar(200),
    team_type  varchar(200)
);

-- ---------------------------------------------------------------------------
-- DW  (star schema: match_innings is the fact table)
-- ---------------------------------------------------------------------------
create or replace table dw.teams (
    team_id    number(19,0),
    team_name  varchar(200),
    team_type  varchar(200)
);

create or replace table dw.players (
    player_id    number(38,0),
    player_name  varchar(100),
    teams        array            -- team_ids the player has appeared for
);

create or replace table dw.match_info (
    match_id         number(19,0),
    match_type       varchar(200),
    gender           varchar(200),
    season           varchar(200),
    city             varchar(200),
    venue            varchar(200),
    match_date       date,
    team1_id         number(19,0),
    team2_id         number(19,0),
    toss_winner_id   number(19,0),
    toss_decision    varchar(200),
    match_winner_id  number(19,0),
    margin           varchar(200),
    event_name       varchar(200),
    event_type       varchar(200),
    pom_id           number(19,0),
    filename         varchar(100)
);

create or replace table dw.match_innings (
    match_id         number(19,0),
    inning_id        number(38,0),
    over             number(38,0),
    batting_team_id  number(19,0),
    ball_in_over     number(38,0),
    batter           varchar(200),
    bowler           varchar(200),
    non_striker      varchar(200),
    runs_batter      number(38,0),
    extra_type       varchar(200),
    runs_extras      number(38,0),
    runs_total       number(38,0),
    dismissal_kind   varchar(200),
    out_player       varchar(200),
    is_powerplay     number(1,0)
);

create or replace sequence dw.seq_teams;
create or replace sequence dw.seq_players;
create or replace sequence dw.seq_matches;
