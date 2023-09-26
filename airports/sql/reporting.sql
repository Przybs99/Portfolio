/*
Defining `reporting` schema
*/
CREATE SCHEMA IF NOT EXISTS reporting
;
/*
Defining reporting.flight view, which:
- doesn't include cancelled flights
- include 'is_delayed' column
*/
CREATE OR REPLACE VIEW reporting.flight as
SELECT *,
       CASE
           WHEN dep_delay_new > 0 THEN 1
           ELSE 0
       END AS is_delayed
FROM flight
where cancelled = 0 
;
/*
Defining reporting.top_reliability_roads view, which includes:
- `origin_airport_id`,
- `origin_airport_name`,
- `dest_airport_id`,
- `dest_airport_name`,
- `year`,
- `cnt` - number of flights on route,
- `reliability` - delay ratio in route,
- `nb` - ranking reliability, 
columns
*/
CREATE OR REPLACE VIEW reporting.top_reliability_roads AS
select f.origin_airport_id,
	al.name as origin_airport_name,
	f.dest_airport_id,
	al2.name as dest_airport_name,
	year,
	count(*) as cnt,
	round(is_delayed_mean, 2) as reliability,
	dense_rank() over(order by round(is_delayed_mean, 2)) as nb
FROM flight f join airport_list al on f.origin_airport_id = al.origin_airport_id
			  join airport_list al2 on f.dest_airport_id = al2.origin_airport_id
			  join (select 
				   		origin_airport_id,
				   		dest_airport_id,
				   		avg(CASE
							   WHEN dep_delay_new > 0 THEN 1
							   ELSE 0
						END) AS is_delayed_mean
					from flight
				    group by origin_airport_id, dest_airport_id
				   ) as f2 on f.origin_airport_id = f2.origin_airport_id AND f.dest_airport_id = f2.dest_airport_id
group by f.origin_airport_id, f.dest_airport_id, al.name, al2.name, year, is_delayed_mean
having count(*) > 10000
;
/*
Defining reporting.year_to_year_comparision view, which includes:
- `year`
- `month`,
- `flights_amount`
- `reliability`
columns
*/
CREATE OR REPLACE VIEW reporting.year_to_year_comparision AS
select 
f.year,
f.month,
count(*) as flights_amount,
round(is_delayed_mean, 2) as reliability
from flight f join (select 
				   		year,
				   		month,
				   		avg(CASE
							   WHEN dep_delay_new > 0 THEN 1
							   ELSE 0
						END) AS is_delayed_mean
					from flight
				    group by year, month
				   ) as f2 on f.year = f2.year and f.month = f2.month
group by f.year, f.month, is_delayed_mean
order by f.year, f.month
;
/*
Defining reporting.day_to_day_comparision view, which includes:
- `year`
- `day_of_week`
- `flights_amount`
*/
CREATE OR REPLACE VIEW reporting.day_to_day_comparision AS
select 
year,
day_of_week,
count(*) as flights_amount
from flight 
group by year, day_of_week
order by year, day_of_week
;
/*
Defining reporting.day_by_day_reliability view, which includes:
- `date` 
- `reliability` 
*/
CREATE OR REPLACE VIEW reporting.day_by_day_reliability AS
select 
to_date((f.year||'-'||f.month||'-'||f.day_of_month), 'YYYY-mm-DD') as date,
round(is_delayed_mean, 2) as reliability
from flight f join (select 
				   		year,
				   		month,
						day_of_month,
				   		avg(CASE
							   WHEN dep_delay_new > 0 THEN 1
							   ELSE 0
						END) AS is_delayed_mean
					from flight
				    group by year, month, day_of_month
				   ) as f2 on f.year = f2.year and f.month = f2.month and f.day_of_month = f2.day_of_month
group by to_date((f.year||'-'||f.month||'-'||f.day_of_month), 'YYYY-mm-DD'), round(is_delayed_mean, 2)