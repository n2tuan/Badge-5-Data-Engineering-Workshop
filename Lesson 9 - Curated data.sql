use role sysadmin;
use schema ags_game_audience.raw;
create or replace schema curated;

-- DO NOT EDIT THIS CODE
-- Put this code into a DASHBOARD TILE QUERY
use role accountadmin;
use schema util_db.public;
--We added a case statement to bucket the session lengths
select GRADER(step, (actual = expected), actual, expected, description) as graded_results from
(
SELECT
'DNGW07' as step
 ,( select count(*)/count(*) from snowflake.account_usage.query_history
    where query_text like '%case when game_session_length < 10%'
  ) as actual
 ,1 as expected
 ,'Curated Data Lesson completed' as description
 ); 
