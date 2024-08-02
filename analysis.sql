--alter table "2024_sales_data" 
--rename to sales_data;

select * from sales_data limit 100;

-- The date columns (state_change_date, lead_created_date, current_opp_status_date) are not in any perceivable date format

-- Current_lead_status_date is in a date format but not a datetype, because SQLite doesn't have a datetype.
-- This column is in a ISO 8601 string type format. The other date columns appear to be in Unix timestamp. We need to standardize the format.

-- Change ISO 8601 string type format to Unix timestamps, since it will be easier to perform calculations on these.
-- Later we can transform them back into ISO 8601 string type so they are more human readable.

SELECT 
	company,
	opportunity_value,
	old_status_label,
	new_status_label,
	status_change_date,
	lead_created_date,
	current_lead_status,
	current_lead_status_date,
	unixepoch(current_lead_status_date) as current_lead_status_date2,
	current_opp_status,
	current_opp_status_date,
	billing_period_unit,
	billing_period
from sales_data;
-- Having an issue where current_lead_status_date2 is producing nulls when current_lead_status_date's hour is a single digit

-- Let's fix this
select 
	current_lead_status_date,
	length(current_lead_status_date) as length,
	current_lead_status_date2
from clean_sales_data;
-- Length of entries recieving nulls is 18

-- Use length of entries recieving nulls to identify these entries and add a 0 before the single digit hour
--create table clean_sales_data as
	select 
		company,
		opportunity_value,
		old_status_label,
		new_status_label,
		status_change_date,
		lead_created_date,
		current_lead_status,
		unixepoch(current_lead_status_date) as current_lead_status_date2,
		current_opp_status,
		current_opp_status_date,
		billing_period_unit,
		billing_period
		
		
		
	select DATETIME(current_lead_status_date) as current_lead_status_date2
	from 
	
	 
	create table temp_table2 as
		select 
			*,
			case
				when length(current_lead_status_date) = 18 then substr(current_lead_status_date,1,11) || "0" || substr(current_lead_status_date,12,18)
				else current_lead_status_date
				end as current_lead_status_date2,
			unixepoch(current_lead_status_date) as current_lead_status_date3
		from sales_data
--		where current_lead_status = "Customer"
;
;

select * from temp_table2;
select distinct typeof(current_lead_status_date2) from temp_table2;

select 
	company,
	avg(current_lead_status_date - DATETIME(lead_created_date ,"unixepoch")) as time_to_customer
from sales_data
group by company;  


select * from clean_sales_data;
-- Next, check values to ensure everything is standardized (spelling, etc).
select distinct 
--	company
--	old_status_label
 	new_status_label
--	old_status_label, new_status_label
-- 	current_lead_status
-- 	current_opp_status
--	billing_period_unit
--	billing_period
--	billing_period, billing_period_unit
from clean_sales_data 
--order by billing_period;
-- There is no month 12 in billing period - is there no billing period in December?


-- The data otherwise seems oddly very clean, so moving on to queries.

-- 1) Calculate the average time per company to become a customer

-- "Customer" is the only value that could indicate a current customer
select distinct current_lead_status from clean_sales_data2;


-- Some current_lead_status_date s are transforming into null columns. Figure out why. Create side by side columns to investigate

select 
	company,
	avg(time_to_customer)
from 
(
	select 
		*,
		current_lead_status_date - lead_created_date as time_to_customer
	from clean_sales_data
	where current_lead_status = "Customer"
)
group by 1
order by 1;

