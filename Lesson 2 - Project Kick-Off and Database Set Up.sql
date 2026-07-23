use role sysadmin;

create or replace database AGS_GAME_AUDIENCE;
drop schema AGS_GAME_AUDIENCE.PUBLIC;
create or replace schema RAW;
create or replace table AGS_GAME_AUDIENCE.RAW.GAME_LOGS (
    RAW_LOG VARIANT
);
create or replace stage uni_kishore
    url = 's3://uni-kishore'
    directory = (enable = true)
;
list  @uni_kishore/kickoff;
create or replace file format FF_JSON_LOGS
    TYPE = JSON
    strip_outer_array = true
;

select $1
from @uni_kishore/kickoff
(file_format => FF_JSON_LOGS)
;

COPY INTO GAME_LOGS
FROM @uni_kishore/kickoff/
FILES = ('DNGW_Sample_from_Agnies_Game.json')
FILE_FORMAT = (FORMAT_NAME = FF_JSON_LOGS)
;
create or replace view AGS_GAME_AUDIENCE.RAW.logs 
as 
select
RAW_LOG:agent as agent,
RAW_LOG:datetime_iso8601::TIMESTAMP_NTZ as datetime_iso8601,
RAW_LOG:user_event as user_event,
RAW_LOG:user_login as user_login,
*
from GAME_LOGS;
select top 10 * from logs;

use role accountadmin;
use schema util_db.public;
-- DO NOT EDIT THIS CODE
select GRADER(step, (actual = expected), actual, expected, description) as graded_results from
(
 SELECT
 'DNGW01' as step
  ,(
      select count(*)  
      from ags_game_audience.raw.logs
      where is_timestamp_ntz(to_variant(datetime_iso8601))= TRUE 
   ) as actual
, 250 as expected
, 'Project DB and Log File Set Up Correctly' as description
); 