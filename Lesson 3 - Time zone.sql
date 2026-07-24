select current_timestamp();

alter session set timezone = 'UTC';

--how did the time differ after changing the time zone for the worksheet?
alter session set timezone = 'Africa/Nairobi';
select current_timestamp();

alter session set timezone = 'Pacific/Funafuti';
select current_timestamp();

alter session set timezone = 'Asia/Ho_Chi_Minh';
select current_timestamp();

--show the account parameter called timezone
show parameters like 'timezone';

use schema AGS_GAME_AUDIENCE.RAW;
list @uni_kishore/updated_feed/;
select top 10 $1
from @uni_kishore/updated_feed/DNGW_updated_feed_0_0_0.json
(file_format => FF_JSON_LOGS)
;
copy into GAME_LOGS
from @uni_kishore/updated_feed/
files = ('DNGW_updated_feed_0_0_0.json')
file_format = (format_name = FF_JSON_LOGS)
;
select count(1) from GAME_LOGS;
select top 10 * from logs;
create or replace view AGS_GAME_AUDIENCE.RAW.logs 
as 
select
RAW_LOG:ip_address as ip_address,
RAW_LOG:datetime_iso8601::TIMESTAMP_NTZ as datetime_iso8601,
RAW_LOG:user_event as user_event,
RAW_LOG:user_login as user_login,
*
from GAME_LOGS
where RAW_LOG:ip_address is not null;
select top 10 * from logs where lower(user_login) like '%prajina%';

use role accountadmin;
use schema util_db.public;
select GRADER(step, (actual = expected), actual, expected, description) as graded_results from
(
SELECT
   'DNGW02' as step
   ,( select sum(tally) from(
        select (count(*) * -1) as tally
        from ags_game_audience.raw.logs 
        union all
        select count(*) as tally
        from ags_game_audience.raw.game_logs)     
     ) as actual
   ,250 as expected
   ,'View is filtered' as description
); 