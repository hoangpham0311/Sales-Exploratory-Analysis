-- Find the total sales
SELECT SUM(sales_amount) FROM gold_fact_sales; 
-- Find how many items sold
SELECT SUM(quantity) FROM gold_fact_sales gfs ;
-- Find the average selling price
SELECT AVG(price) FROM gold_fact_sales gfs;
-- Find the total number of orders
SELECT COUNT(DISTINCT order_number) FROM gold_fact_sales gfs;
-- Find the total number of products
SELECT COUNT(DISTINCT product_id) FROM gold_dim_products gdp;
-- Find the total number of customer ordering
SELECT COUNT(DISTINCT customer_id) FROM gold_dim_customers gdc;

-- Generate a report that shows all key metrics: 
SELECT 'Total sales' as measure_name, SUM(sales_amount) as measure_value FROM gold_fact_sales gfs 
UNION ALL
SELECT 'Total quantity', SUM(quantity) FROM gold_fact_sales gfs
UNION ALL
SELECT 'Average Price', AVG(price) FROM gold_fact_sales gfs
UNION ALL
SELECT 'Total Number Of Order', COUNT(DISTINCT order_number) FROM gold_fact_sales gfs
UNION ALL
SELECT 'Total Number Of Products', COUNT(DISTINCT product_id) FROM gold_dim_products gdp
UNION ALL
SELECT 'Total Number Of Customers', COUNT(DISTINCT customer_id) FROM gold_dim_customers gdc

-- Converts string value (' ') into NULL values	in birthdate column
UPDATE sqltest.gold_dim_customers
SET birthdate = NULL
WHERE birthdate = '';
		
-- Find the youngest and oldest customer
SELECT 
	min(birthdate),
	max(birthdate),
	timestampdiff(year,min(birthdate), CURRENT_DATE())
FROM gold_dim_customers gdc 

-- Find the date of the first and last order
SELECT 
	min(order_date), 
	max(order_date),
	timestampdiff(month, min(order_date),max(order_date)) as order_range_year
FROM gold_fact_sales gfs 

-- Total customers by countries
SELECT COUNT(customer_id), Country FROM gold_dim_customers gdc 
GROUP BY Country 
ORDER BY COUNT(customer_id) DESC;

-- Total customers by gender
SELECT COUNT(customer_id), gender FROM gold_dim_customers gdc 
GROUP BY gender
ORDER BY COUNT(customer_id) DESC

-- Total products by category: 
SELECT COUNT(product_id), AVG(cost), category 
FROM gold_dim_products gdp 
GROUP BY category;

-- Total rev generated for each category:
SELECT 
	SUM(sales_amount),
	category
FROM gold_fact_sales gfs 
LEFT JOIN gold_dim_products gdp ON gfs.product_key = gdp.product_key
GROUP BY category 
ORDER BY SUM(sales_amount) DESC ;

-- Top 5 products generate the highest revenue
SELECT
	SUM(sales_amount),
	gdp.product_name 
FROM gold_fact_sales gfs 
LEFT JOIN gold_dim_products gdp ON gfs.product_key = gdp.product_key
GROUP BY gdp.product_name 
ORDER BY SUM(sales_amount) DESC
LIMIT 5;

SELECT *
FROM 
(
SELECT
	gdp.product_name ,
	SUM(sales_amount),
	ROW_NUMBER() OVER(ORDER BY SUM(sales_amount) DESC) as rank_product
FROM gold_fact_sales gfs 
LEFT JOIN gold_dim_products gdp ON gfs.product_key = gdp.product_key
GROUP BY gdp.product_name ) sub
WHERE sub.rank_product <= 5;

-- TOP 10 customers generate the highest revenue
SELECT
	customer_number,
	sum(sales_amount)
FROM gold_fact_sales gfs 
LEFT JOIN gold_dim_customers gdc  ON gdc.customer_key  = gfs.customer_key
GROUP BY customer_number 
ORDER BY sum(sales_amount) DESC

-- ADVANCE ANALYTICS PROJECT
-- Change over time

SELECT 
	date_format(order_date,'%Y-%m-01') as month_year, 
	sum(sales_amount) as total_sales,
	count(distinct customer_key) as total_customer,
	sum(quantity) as total_quantity
FROM gold_fact_sales gfs 
WHERE gfs.order_date  is not NULL 
GROUP BY date_format(order_date,'%Y-%m-01')
ORDER BY date_format(order_date,'%Y-%m-01');

-- Cumulative Analysis
SELECT 
month_year , 
total_sales,
SUM(total_sales) OVER (ORDER BY month_year) as running_total_sales,
ROUND(AVG(avg_price) OVER (ORDER BY month_year),2) as moving_avg_price
FROM 
(
SELECT 
	date_format(order_date,'%Y-%m-01') as month_year, 
	sum(sales_amount) as total_sales,
	count(distinct customer_key) as total_customer,
	sum(quantity) as total_quantity,
	avg(price) as avg_price
FROM gold_fact_sales gfs 
WHERE gfs.order_date  is not NULL 
GROUP BY date_format(order_date,'%Y-%m-01'))t;

-- Performance Analysis
/* analyze yearly performance of products by comparing sales to both average and previous year sales */
-- Using subs query

SELECT *,
	AVG(total_sales) OVER (PARTITION BY product_name) AS product_avg_sales,
	total_sales - AVG(total_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE WHEN total_sales - AVG(total_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above average'
		WHEN total_sales - AVG(total_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below average'
		ELSE 'Average' END avg_change,
	LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prv_sales
FROM (
SELECT 
	YEAR(order_date) as order_year,
	product_name,
	SUM(sales_amount) as total_sales
FROM gold_fact_sales gfs
LEFT JOIN gold_dim_products gdp ON gdp.product_key = gfs.product_key
WHERE order_date is not NULL 
GROUP BY 1,2) t
ORDER BY product_name, order_year ;

-- Using CTE

WITH yearly_product_sales AS (
SELECT 
	YEAR(order_date) as order_year,
	product_name,
	SUM(sales_amount) as total_sales
FROM gold_fact_sales gfs
LEFT JOIN gold_dim_products gdp ON gdp.product_key = gfs.product_key
WHERE order_date is not NULL 
GROUP BY 1,2) 

SELECT
	*,
	AVG(total_sales) OVER (PARTITION BY product_name) AS product_avg_sales,
	total_sales - AVG(total_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE WHEN total_sales - AVG(total_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above average'
		WHEN total_sales - AVG(total_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below average'
		ELSE 'Average' END avg_change,
	LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prv_sales
FROM yearly_product_sales
ORDER BY product_name, order_year

-- Part To Whole Analysis
-- Categories contribue the most to overall sales

SELECT *, 
	SUM(category_sales) OVER () AS total_sales,
	ROUND((category_sales / SUM(category_sales) OVER ())*100,2) AS proportion,
	CONCAT(ROUND((category_sales / SUM(category_sales) OVER ())*100,2), '%') AS percentage_of_total
FROM (
SELECT 
	category,
	SUM(sales_amount) as category_sales
FROM gold_fact_sales gfs
LEFT JOIN gold_dim_products gdp ON gdp.product_key = gfs.product_key
GROUP BY category)t
ORDER BY category_sales DESC;

-- Data Segmentation
-- Segment product into cost ranges and count how many products fall into each segment

WITH product_segments AS (
SELECT 
	product_key,
	product_name,
	cost, 
	CASE WHEN cost < 100 THEN '<100'
		WHEN cost between 100 and 500 THEN '100-500'
		WHEN cost between 500 and 1000 THEN '500-1000'
		ELSE '>1000' END cost_range
FROM gold_dim_products)

SELECT 
	cost_range,	
	count(product_key) AS total_product
FROM product_segments
GROUP BY 1
ORDER BY 2 DESC;

/* Group customers into 3 segments based on spending: 
- VIP: at least 12m of history and spending > 5K
- Regular: at least 12m of history and spend <= 5K
- New: lifespan less than 12m 
Find total number of customers by each group
*/

WITH customer_segment AS (
SELECT 
	gfs.customer_key, 
	SUM(sales_amount) AS total_sales,
	CASE WHEN SUM(sales_amount) > 5000 THEN '>5000'
		ELSE '<5000' END spending_tier,
	MIN(order_date) AS first_order,
	MAX(order_date) AS last_order,
	timestampdiff(month, min(order_date),max(order_date)) as life_span, 
	CASE WHEN timestampdiff(month, min(order_date),max(order_date)) > 12 THEN '>12m'
		ELSE '<12m' END life_span_tier,
	CASE WHEN timestampdiff(month, min(order_date),max(order_date)) > 12 AND SUM(sales_amount) > 5000 THEN 'VIP'
		WHEN timestampdiff(month, min(order_date),max(order_date)) > 12 AND SUM(sales_amount) <= 5000 THEN 'Regular'
		ELSE 'New' END customer_type
FROM gold_fact_sales gfs
LEFT JOIN gold_dim_customers gdc ON gfs.customer_key = gdc.customer_key
GROUP BY 1) 

SELECT 
	customer_type, 
	COUNT(customer_key) AS number_of_customer
FROM customer_segment
GROUP BY 1;

-- Build Customer Report

/* 
============================================================================================================================
Customer Report
============================================================================================================================
Requirement: Consolidate key customer metrics and behaviors

Highlight: 
1. Gathers essential fields such as names, ages, and transaction details. 
2. Segments customer into categories (VIP, Regular, New) and age groups. 
3. Aggregates customer-level metrics: 
	- Total orders,
	- Total sales,
	- Total quantity purchased,
	- Total products, 
	- Life span (in months)
4. Calculates valuable KPIs: 
	- Recency (months since last order),
	- Average order value,
	- Average monthly spend

============================================================================================================================
*/ 

/* -------------------------------------------------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
--------------------------------------------------------------------------------------------------------------------------*/
CREATE VIEW gold_report_customer AS 

WITH base_query AS (
SELECT 
	product_key,
	order_number,
	order_date,
	gdc.customer_key,
	customer_number,
	CONCAT(first_name, ' ',last_name) as customer_name,
	timestampdiff(year, birthdate, current_date()) as age,
	sales_amount,
	quantity
FROM gold_fact_sales gfs 
LEFT JOIN  gold_dim_customers gdc ON gdc.customer_key = gfs.customer_key
WHERE order_date is not null)

, customer_aggregation AS (
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) as total_orders,
	SUM(sales_amount) as total_sales,
	SUM(quantity) as total_quantity,
	COUNT(DISTINCT product_key) as total_products,
	MAX(order_date) as last_order_date,
	timestampdiff(month, MIN(order_date), MAX(order_date)) as lifespan	
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	customer_name,
	age)
	
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE WHEN age <20 THEN 'Under 20'
		WHEN age between 20 and 29 THEN '20-29'
		WHEN age between 31 and 39 THEN '30-39'
		WHEN age between 41 and 49 THEN '40-49'
		ELSE '50 and above' END AS age_group,
	CASE WHEN lifespan > 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New' END AS customer_segment,
	total_orders,
	total_sales,
	-- Average Order Value = Total Sales / Total Number of Order
	total_sales/ total_orders as avg_order,
	total_quantity,
	total_products,
	last_order_date,
	timestampdiff(month,last_order_date, current_date() ) as recency,
	lifespan, 
	-- Average Monthly Spending = Total Sales / Number of Months
	CASE WHEN lifespan = 0 THEN total_sales
		ELSE total_sales/lifespan END AS avg_monthly_spend
FROM customer_aggregation;

-- Build Product Report
/* 
============================================================================================================================
Product Report
============================================================================================================================
Requirement: Consolidate key product metrics and behaviors

Highlight: 
1. Gathers essential fields such as product names, category, subcategory, and cost. 
2. Segments products by revenue to identify High Performers, Mid Range, or Low Performers. 
3. Aggregates product-level metrics: 
	- Total orders,
	- Total sales,
	- Total quantity sold,
	- Total customers (unique)
	- Life span (in months)
4. Calculates valuable KPIs: 
	- Recency (months since last order),
	- Average order revenue (AOR),
	- Average monthly revenue
============================================================================================================================
*/ 

/* -------------------------------------------------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
--------------------------------------------------------------------------------------------------------------------------*/
CREATE VIEW gold_report_product AS 

WITH base_query AS (
SELECT 
	order_number, 
	gfs.product_key, 
	customer_key,
	order_date, 
	sales_amount, 
	quantity, 
	product_name, 
	category,
	subcategory,
	cost
FROM gold_fact_sales gfs
LEFT JOIN gold_dim_products gdp ON gdp.product_key = gfs.product_key)

, product_aggregation AS (

SELECT 
	product_key, 
	product_name,
	category,
	subcategory, 
	cost,
	COUNT(DISTINCT order_number) as total_order,
	SUM(sales_amount) as total_sales,
	SUM(quantity) as total_quantity,
	COUNT(DISTINCT customer_key) as total_customer,
	MAX(order_date) as last_order_date,
	timestampdiff(month, min(order_date), max(order_date)) as lifespan,
	SUM(sales_amount)/ SUM(quantity) as avg_selling_price
FROM base_query
GROUP BY 
	product_key, 
	product_name,
	category,
	subcategory, 
	cost) 
	
SELECT 
	product_key, 
	product_name,
	category,
	subcategory, 
	cost,
	avg_selling_price,
	last_order_date,
	CASE WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer' END AS product_segment,
	total_order,
	total_sales,
	total_quantity,
	total_customer,
	timestampdiff(month,last_order_date, current_date() ) as recency,
	lifespan, 
-- average order revenue (AOR)
	total_sales/ total_order as average_order_revenue, 
-- average monthly revenue
	total_sales/ lifespan as average_monthly_revenue
FROM product_aggregation
