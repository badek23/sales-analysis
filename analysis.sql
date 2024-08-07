-- Began by importing the data and taking a quick look.

select * from "2024_sales_data" limit 100;

-- Some date columns (state_change_date, lead_created_date, current_opp_status_date) are not in a human-readable date format

-- Current_lead_status_date is in a date format but not a datetype, because SQLite doesn't have a datetype.
-- Research indicates this column is in a ISO 8601 string type format. The other date columns appear to be in Unix timestamp. We need to standardize the format.

-- I first tried fixing this in SQL but ran into null values whenever the ISO 8601 value had an hour in the single digit. After some trouble-shooting, instead of wasting time, I switched to fixing it in Excel and re-uploading the data.
-- I changed current_lead_status_date into Unix timestamp using the formula (H2-DATE(1970,1,1))*86400 in Excel. It will be easier to perform calculations on Unix timestamp.
-- Later we can transform them back into ISO 8601 string type so they are more human readable, if desired.


-- Alter table name so quotes are not necessary
/*
alter table "2024_sales_data" 
rename to sales_data;
*/

select * from sales_data limit 100;

-- Otherwise, all datatypes appear correct (for SQLite, which again has limited datatype functionality)

-- Next, check the distinct values of categorical columns to ensure everything is standardized (spelling, etc) and is sense-checked.
select distinct 
--	company
--	old_status_label
-- 	new_status_label
--	old_status_label, new_status_label
-- 	current_lead_status
-- 	current_opp_status
--	billing_period_unit
--	billing_period
	billing_period, billing_period_unit
from sales_data 
order by billing_period;
-- There is no month 12 in billing period - is there no billing period in December? Or is only full-year billing done that month?


-- Another thing to consider is whether there is duplicate data in this table caused by the multiple billing_period_unit values.
-- For example, do monthly billing period values add up to make the yearly billing period value? I would need to consider that later when making calculations.

select 
	distinct num_periods
from 
(
	select 
		company,
		count(distinct billing_period_unit) as num_periods
	from sales_data 
	group by 1
)
order by 1;
-- There are some companies that have two billing_period_units present. Let's look into them

select *
from 
(
	select 
		company,
		count(distinct billing_period_unit) as num_periods
	from sales_data 
	group by 1
)
where num_periods = 2
order by 1;
-- 6 different companies. Let's look at them


select * from sales_data
where company = "company1542";

select * from sales_data
where company = "company2424";

select * from sales_data
where company = "company3077";
-- By shear sum of opportunity_value it does not appear that the monthly billing periods roll up into the yearly.
-- These two billing periods must be for separate customers entirely.



-- The data otherwise seems clean, so moving on to queries.

-------- 1) Calculate the average time per company to become a customer

-- To calculate average time to become a customer, we isolate the time at which a lead begins and the time at which they become a customer
-- "Customer" is the only value that could indicate a current customer
select distinct current_lead_status from sales_data;

-- Create average by company of the current_lead_status_date minus the lead_created_date, only for those entries where current_lead_status is Customer 
-- Note that this chart outputs time to customer in seconds.
select 
	company,
	avg(time_to_customer) as avg_time_to_cust
from 
(
	select 
		*,
		current_lead_status_date - lead_created_date as time_to_customer --In seconds
	from sales_data
	where current_lead_status = "Customer"
)
group by 1
order by 1;

-- These values generally look good but there seems to be a few anomalies, such as negative average time to customer.
-- Let's look at an example (company1165) to see why

select *
from sales_data 
where current_lead_status = "Customer"
and company = "company1165";
-- This is only one entry. I hypothesize that this is human error; for example, perhaps the lead was created very close to when the lead converted to customer, and were input almost simultaneously.
-- I would need more information on the process behind how these datetimes are input so identify more clearly what the issue is.
-- However, it is important to note that there are also very low positive averages; such as company1002 at 2 seconds. Again, I hypothesize these issues are human error or an error with the input process.


-------- 2) Calculate how many customers have churned and reactivated

-- Take a look at what pairs of status labels could indicate churning and then reactivating
select distinct 
	old_status_label, new_status_label
from sales_data;
-- old_status_label should be "Churned"

select distinct 
	old_status_label, new_status_label
from sales_data
where old_status_label = "Churned";
-- the only possible new_status_label is "MR - Qualification"

select 
	count(*)
from sales_data 
where old_status_label = "Churned";
-- Only one customer... this feels far too low.
-- I considered adding other old_status_label values but no others indicated churn.

-- Upon further reflection, the difficulty with calculating this based on this dataset is that we only have the old status directly prior to the current status. 
-- So if a customer churned, then went through the inbound process again and was eventually reactivated, they would not be counted here.


-------- 3) Calculate the expected MRR (monthly recurring revenue) per month

-- current_opp_status of "Paying" is best to calculate the expected MRR
select distinct current_opp_status from sales_data;

-- There are other lead statuses that are concurrent with an opp status of Paying
-- Considered removing certain of these (ex. Blacklist) but as the customer is still paying, it is necessary to calculate expected MRR
select distinct 
	current_lead_status, 
	current_opp_status 
from sales_data
where current_opp_status = "Paying";

-- Expected MRR by month:
select 
	billing_period,
	sum(opportunity_value) as MRR
from sales_data
where current_opp_status = "Paying"
and billing_period_unit = "month"
group by billing_period
order by billing_period;
-- These numbers are fairly stable with an expected decrease around the winter holidays, when business slows


-------- 4) Calculate the number of (potential) customers per month up to today

-- What qualifies as a "potential" customer? I am interpreting this as all customers in this dataset
select * from sales_data;

-- All dates are several years ago, so any filter to focus on customers prior to today will not actually filter anything out.
select 
	datetime(current_lead_status_date,"unixepoch"),
	datetime(status_change_date,"unixepoch"),
	datetime(lead_created_date,"unixepoch"),
	datetime(current_opp_status_date,"unixepoch")
from sales_data;

-- However, I'll include the filter anyway
select 
	billing_period,
	count(*) as num_customers
from sales_data 
where billing_period_unit = "month"
and current_opp_status_date < unixepoch(current_timestamp)
group by 1
order by 1;




----------
-- FINAL ANSWERS
----------
-- Because I included the queries that explained my choices as well as some of the queries I used to sense check my answers, I'm consolidating the queries that directly answer the questions here.


-- 1
select 
	company,
	avg(time_to_customer) as avg_time_to_cust
from 
(
	select 
		*,
		current_lead_status_date - lead_created_date as time_to_customer --In seconds
	from sales_data
	where current_lead_status = "Customer"
)
group by 1
order by 1;

-- 2
select 
	count(*)
from sales_data 
where old_status_label = "Churned";

-- 3
select 
	billing_period,
	sum(opportunity_value) as MRR
from sales_data
where current_opp_status = "Paying"
and billing_period_unit = "month"
group by billing_period
order by billing_period;

-- 4
select 
	billing_period,
	count(*) as num_customers
from sales_data 
where billing_period_unit = "month"
and current_opp_status_date < unixepoch(current_timestamp)
group by 1
order by 1;


