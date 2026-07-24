use role sysadmin;
use schema AGS_GAME_AUDIENCE.RAW;
select parse_ip('100.41.16.160','inet'):ipv4;

create or replace schema ags_game_audience.enhanced;
select top 10 *
from IPINFO_GEOLOC.demo.location
where parse_ip('100.41.16.160','inet'):ipv4 between start_ip_int and end_ip_int;

select top 10 logs.*
       , loc.city
       , loc.region
       , loc.country
       , loc.timezone
from AGS_GAME_AUDIENCE.RAW.logs 
join IPINFO_GEOLOC.demo.location loc
on parse_ip(logs.ip_address,'inet'):ipv4 between loc.start_ip_int and end_ip_int;

select  logs.*
       , loc.city
       , loc.region
       , loc.country
       , loc.timezone
from AGS_GAME_AUDIENCE.RAW.logs 
join IPINFO_GEOLOC.demo.location loc
on IPINFO_GEOLOC.public.to_join_key(logs.ip_address) = loc.join_key
and IPINFO_GEOLOC.public.to_int(logs.ip_address) between loc.start_ip_int and end_ip_int;

select top 10 *
from IPINFO_GEOLOC.demo.location ;
select  logs.*
       , loc.city
       , loc.region
       , loc.country
       , loc.timezone
       , convert_timezone('UTC',loc.timezone,logs.DATETIME_ISO8601) as GAME_EVENT_LTZ
       , dayname(GAME_EVENT_LTZ) as dow_name
from AGS_GAME_AUDIENCE.RAW.logs 
join IPINFO_GEOLOC.demo.location loc
on IPINFO_GEOLOC.public.to_join_key(logs.ip_address) = loc.join_key
and IPINFO_GEOLOC.public.to_int(logs.ip_address) between loc.start_ip_int and end_ip_int
where USER_LOGIN = 'princess_prajina';
use schema AGS_GAME_AUDIENCE.RAW;
-- Your role should be SYSADMIN
-- Your database menu should be set to AGS_GAME_AUDIENCE
-- The schema should be set to RAW

--a Look Up table to convert from hour number to "time of day name"
create table ags_game_audience.raw.time_of_day_lu
(  hour number
   ,tod_name varchar(25)
);

--insert statement to add all 24 rows to the table
insert into time_of_day_lu
values
(6,'Early morning'),
(7,'Early morning'),
(8,'Early morning'),
(9,'Mid-morning'),
(10,'Mid-morning'),
(11,'Late morning'),
(12,'Late morning'),
(13,'Early afternoon'),
(14,'Early afternoon'),
(15,'Mid-afternoon'),
(16,'Mid-afternoon'),
(17,'Late afternoon'),
(18,'Late afternoon'),
(19,'Early evening'),
(20,'Early evening'),
(21,'Late evening'),
(22,'Late evening'),
(23,'Late evening'),
(0,'Late at night'),
(1,'Late at night'),
(2,'Late at night'),
(3,'Toward morning'),
(4,'Toward morning'),
(5,'Toward morning');
--Check your table to see if you loaded it properly
    select tod_name, listagg(hour,',') 
    from time_of_day_lu
    group by tod_name;
create table ags_game_audience.enhanced.logs_enhanced as(
    select  logs.ip_address
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
    on HOUR(GAME_EVENT_LTZ) = tod.hour
    --where USER_LOGIN = 'princess_prajina'
)
;
select top 10 *
from ags_game_audience.enhanced.logs_enhanced
;
use role accountadmin;
use schema util_db.public;
select GRADER(step, (actual = expected), actual, expected, description) as graded_results from
(
  SELECT
   'DNGW03' as step
   ,( select count(*) 
      from ags_game_audience.enhanced.logs_enhanced
      where dow_name = 'Sat'
      and tod_name = 'Early evening'   
      and gamer_name like '%prajina'
     ) as actual
   ,2 as expected
   ,'Playing the game on a Saturday evening' as description
); 