use role sysadmin;

create table ags_game_audience.enhanced.LOGS_ENHANCED_BU 
clone ags_game_audience.enhanced.LOGS_ENHANCED;

create or replace task ags_game_audience.raw.LOAD_LOGS_ENHANCED 
    warehouse = 'COMPUTE_WH'
    schedule = '5 minute'
    as select 'hello'
;
use role accountadmin;
grant execute task on account to role sysadmin;
use role sysadmin;
execute task ags_game_audience.raw.LOAD_LOGS_ENHANCED;
show tasks in account;
describe task ags_game_audience.raw.LOAD_LOGS_ENHANCED;
create or replace task ags_game_audience.raw.LOAD_LOGS_ENHANCED 
    warehouse = 'COMPUTE_WH'
    schedule = '5 minute'
    as
    merge into AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED le
    using (select  logs.ip_address
        , logs.user_login as GAMER_NAME
        , logs.user_event as GAME_EVENT_NAME
        , logs.datetime_iso8601 as GAME_EVENT_UTC
        , loc.city
        , loc.region
        , loc.country
        , loc.timezone as GAMER_LTZ_NAME
        , convert_timezone('UTC',loc.timezone,logs.DATETIME_ISO8601) as GAME_EVENT_LTZ
        , dayname(GAME_EVENT_LTZ) as dow_name
        , tod.tod_name
    from AGS_GAME_AUDIENCE.RAW.logs 
    join IPINFO_GEOLOC.demo.location loc
    on IPINFO_GEOLOC.public.to_join_key(logs.ip_address) = loc.join_key
    and IPINFO_GEOLOC.public.to_int(logs.ip_address) between loc.start_ip_int and end_ip_int
    join ags_game_audience.raw.time_of_day_lu tod
    on HOUR(GAME_EVENT_LTZ) = tod.hour) t
    on le.GAMER_NAME = t.GAMER_NAME and le.GAME_EVENT_NAME = t.GAME_EVENT_NAME and le.GAME_EVENT_UTC = t.GAME_EVENT_UTC
    WHEN NOT MATCHED THEN
    INSERT (ip_address, GAMER_NAME, GAME_EVENT_NAME, GAME_EVENT_UTC, CITY, REGION, COUNTRY, GAMER_LTZ_NAME, GAME_EVENT_LTZ, DOW_NAME, TOD_NAME)
    VALUES (t.ip_address, t.GAMER_NAME, t.GAME_EVENT_NAME, t.GAME_EVENT_UTC, t.CITY, t.REGION, t.COUNTRY, t.GAMER_LTZ_NAME, t.GAME_EVENT_LTZ, t.DOW_NAME, t.TOD_NAME) 
;
select count(*)
from AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED;
truncate table AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED ;

INSERT INTO ags_game_audience.raw.game_logs 
select PARSE_JSON('{"datetime_iso8601":"2025-01-01 00:00:00.000", "ip_address":"196.197.196.255", "user_event":"fake event", "user_login":"fake user"}');
--When you are confident your merge is working, you can delete the raw records 
delete from ags_game_audience.raw.game_logs where raw_log like '%fake user%';

--You should also delete the fake rows from the enhanced table
delete from AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED
where gamer_name = 'fake user';
use role accountadmin;
use schema util_db.public;
select GRADER(step, (actual = expected), actual, expected, description) as graded_results from
(
SELECT
'DNGW04' as step
 ,( select count(*)/iff (count(*) = 0, 1, count(*))
  from table(ags_game_audience.information_schema.task_history
              (task_name=>'LOAD_LOGS_ENHANCED'))) as actual
 ,1 as expected
 ,'Task exists and has been run at least once' as description 
 ); 