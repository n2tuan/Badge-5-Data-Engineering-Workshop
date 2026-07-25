use role sysadmin;
use schema ags_game_audience.raw;
create or replace stage UNI_KISHORE_PIPELINE
    url = 's3://uni-kishore-pipeline'
    directory = (enable = true)
;
list @UNI_KISHORE_PIPELINE;
select $1
from @UNI_KISHORE_PIPELINE/logs_101_110_0_0_0.json
(file_format => FF_JSON_LOGS)
;
select get_ddl('VIEW','LOGS');
create or replace table PL_GAME_LOGS(
	RAW_LOG VARIANT
);
COPY INTO PL_GAME_LOGS
FROM @UNI_KISHORE_PIPELINE/
FILE_FORMAT = (FORMAT_NAME = FF_JSON_LOGS)
;
select count(*) from PL_GAME_LOGS;
truncate table PL_GAME_LOGS;
create or replace task GET_NEW_FILES
    warehouse = 'COMPUTE_WH'
    schedule = '10 minute'
    as
    COPY INTO PL_GAME_LOGS
    FROM @UNI_KISHORE_PIPELINE/
    FILE_FORMAT = (FORMAT_NAME = FF_JSON_LOGS)
    
;
execute task GET_NEW_FILES;
create or replace view PL_LOGS(
	IP_ADDRESS,
	DATETIME_ISO8601,
	USER_EVENT,
	USER_LOGIN,
	RAW_LOG
) as 
select
RAW_LOG:ip_address as ip_address,
RAW_LOG:datetime_iso8601::TIMESTAMP_NTZ as datetime_iso8601,
RAW_LOG:user_event as user_event,
RAW_LOG:user_login as user_login,
*
from PL_GAME_LOGS
where RAW_LOG:ip_address is not null;
create or replace task AGS_GAME_AUDIENCE.RAW.LOAD_LOGS_ENHANCED
	warehouse=COMPUTE_WH
	schedule='5 minute'
	as merge into AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED le
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
    from AGS_GAME_AUDIENCE.RAW.PL_logs logs 
    join IPINFO_GEOLOC.demo.location loc
    on IPINFO_GEOLOC.public.to_join_key(logs.ip_address) = loc.join_key
    and IPINFO_GEOLOC.public.to_int(logs.ip_address) between loc.start_ip_int and end_ip_int
    join ags_game_audience.raw.time_of_day_lu tod
    on HOUR(GAME_EVENT_LTZ) = tod.hour) t
    on le.GAMER_NAME = t.GAMER_NAME and le.GAME_EVENT_NAME = t.GAME_EVENT_NAME and le.GAME_EVENT_UTC = t.GAME_EVENT_UTC
    WHEN NOT MATCHED THEN
    INSERT (ip_address, GAMER_NAME, GAME_EVENT_NAME, GAME_EVENT_UTC, CITY, REGION, COUNTRY, GAMER_LTZ_NAME, GAME_EVENT_LTZ, DOW_NAME, TOD_NAME)
    VALUES (t.ip_address, t.GAMER_NAME, t.GAME_EVENT_NAME, t.GAME_EVENT_UTC, t.CITY, t.REGION, t.COUNTRY, t.GAMER_LTZ_NAME, t.GAME_EVENT_LTZ, t.DOW_NAME, t.TOD_NAME);

truncate table AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED;
select top 10 * from AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED;
--Turning on a task is done with a RESUME command
alter task AGS_GAME_AUDIENCE.RAW.GET_NEW_FILES resume;
alter task AGS_GAME_AUDIENCE.RAW.LOAD_LOGS_ENHANCED resume;

--Turning OFF a task is done with a SUSPEND command
alter task AGS_GAME_AUDIENCE.RAW.GET_NEW_FILES suspend;
alter task AGS_GAME_AUDIENCE.RAW.LOAD_LOGS_ENHANCED suspend;

--Step 1 - how many files in the bucket?
list @AGS_GAME_AUDIENCE.RAW.UNI_KISHORE_PIPELINE;

--Step 2 - number of rows in raw table (should be file count x 10)
select count(*) from AGS_GAME_AUDIENCE.RAW.PL_GAME_LOGS;

--Step 3 - number of rows in raw view (should be file count x 10)
select count(*) from AGS_GAME_AUDIENCE.RAW.PL_LOGS;
select top 10 * from AGS_GAME_AUDIENCE.RAW.PL_LOGS;
--Step 4 - number of rows in enhanced table (should be file count x 10 but fewer rows is okay because not all IP addresses are available from the IPInfo share)
select count(*) from AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED;
select top 10 * from AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED;
grant execute managed task on account to role SYSADMIN;
create or replace task AGS_GAME_AUDIENCE.RAW.GET_NEW_FILES
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    schedule = '5 minute'
    as
    COPY INTO PL_GAME_LOGS
    FROM @UNI_KISHORE_PIPELINE/
    FILE_FORMAT = (FORMAT_NAME = FF_JSON_LOGS)
    
;
create or replace task AGS_GAME_AUDIENCE.RAW.LOAD_LOGS_ENHANCED
	USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
	after AGS_GAME_AUDIENCE.RAW.GET_NEW_FILES
	as merge into AGS_GAME_AUDIENCE.ENHANCED.LOGS_ENHANCED le
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
    from AGS_GAME_AUDIENCE.RAW.PL_logs logs 
    join IPINFO_GEOLOC.demo.location loc
    on IPINFO_GEOLOC.public.to_join_key(logs.ip_address) = loc.join_key
    and IPINFO_GEOLOC.public.to_int(logs.ip_address) between loc.start_ip_int and end_ip_int
    join ags_game_audience.raw.time_of_day_lu tod
    on HOUR(GAME_EVENT_LTZ) = tod.hour) t
    on le.GAMER_NAME = t.GAMER_NAME and le.GAME_EVENT_NAME = t.GAME_EVENT_NAME and le.GAME_EVENT_UTC = t.GAME_EVENT_UTC
    WHEN NOT MATCHED THEN
    INSERT (ip_address, GAMER_NAME, GAME_EVENT_NAME, GAME_EVENT_UTC, CITY, REGION, COUNTRY, GAMER_LTZ_NAME, GAME_EVENT_LTZ, DOW_NAME, TOD_NAME)
    VALUES (t.ip_address, t.GAMER_NAME, t.GAME_EVENT_NAME, t.GAME_EVENT_UTC, t.CITY, t.REGION, t.COUNTRY, t.GAMER_LTZ_NAME, t.GAME_EVENT_LTZ, t.DOW_NAME, t.TOD_NAME);
use role accountadmin;
use schema util_db.public;
select GRADER(step, (actual = expected), actual, expected, description) as graded_results from
(
SELECT
'DNGW05' as step
 ,(
   select max(tally) from (
       select CASE WHEN SCHEDULED_FROM = 'SCHEDULE' 
                         and STATE= 'SUCCEEDED' 
              THEN 1 ELSE 0 END as tally 
   from table(ags_game_audience.information_schema.task_history (task_name=>'GET_NEW_FILES')))
  ) as actual
 ,1 as expected
 ,'Task succeeds from schedule' as description
 ); 