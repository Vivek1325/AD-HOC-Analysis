-- Q1)Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT market from dim_customer
where region = 'APAC' and customer = 'Atliq Exclusive';
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Q2) What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
-- unique_products_2020, unique_products_2021, percentage_chg
WITH 
unique_2020 as (SELECT count(distinct(product_code)) AS uq_prod FROM fact_sales_monthly  WHERE fiscal_year = 2020 ),
unique_2021 as (SELECT count(distinct(product_code)) AS uq_prod FROM fact_sales_monthly  WHERE fiscal_year = 2021 )
select unique_2020.uq_prod as unique_products_2020, unique_2021.uq_prod as unique_products_2021,
(unique_2021.uq_prod - unique_2020.uq_prod)/unique_2020.uq_prod * 100 as percentage_chg from unique_2020, unique_2021;
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Q3)Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. The final output contains
-- 2 fields, segment, product_count
SELECT segment, COUNT(distinct(product_code)) as product_count from dim_product
group by segment
order by product_count desc;
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Q4) Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields - segment, product_count_2020, 
-- product_count_2021, difference
WITH 
t_2020 as 
(select segment, COUNT(DISTINCT(dp.product_code)) as unique_2020 from fact_sales_monthly as fsm
inner join dim_product as dp on dp.product_code = fsm.product_code
where fsm.fiscal_year = 2020
group by segment),
t_2021 as 
(select segment, COUNT(DISTINCT(dp.product_code)) as unique_2021 from fact_sales_monthly as fsm
inner join dim_product as dp on dp.product_code = fsm.product_code
where fsm.fiscal_year = 2021
group by segment)
select t_2020.segment, unique_2020 as product_count_2020, unique_2021 as product_count_2020, (unique_2021 - unique_2020) as difference
from t_2020 inner join t_2021 on t_2020.segment = t_2021.segment
order by difference desc;
-- ------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Q5) Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields product_code, product, manufacturing_cost
-- dim_product , fact_manufacturing_cost
SELECT dp.product_code, product, manufacturing_cost from dim_product as dp
inner join fact_manufacturing_cost as fmc
on dp.product_code = fmc.product_code
where manufacturing_cost = (select MAX(manufacturing_cost) from fact_manufacturing_cost) 
or manufacturing_cost = (select min(manufacturing_cost) from fact_manufacturing_cost) ;
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Q6)Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
-- The final output contains these fields customer_code, customer, average_discount_percentage
select fpid.customer_code, dc.customer, dis_pct as average_discount_percentage from 
(select customer_code, ROUND(AVG(pre_invoice_discount_pct)*100, 2) as dis_pct from fact_pre_invoice_deductions where fiscal_year = 2021 group by customer_code) as fpid
inner join (select * from dim_customer where market = 'India') as dc on
dc.customer_code = fpid.customer_code
order by dis_pct desc
limit 5;
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Q7)Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and 
-- high-performing months and take strategic decisions.The final report contains these columns: Month, Year, Gross sales Amount
select * from fact_sales_monthly where product_code = 'A0118150102';
select * from fact_gross_price;

SELECT CONCAT(MONTHNAME(FS.date), ' (', YEAR(FS.date), ')') AS 'Month', FS.fiscal_year,
       ROUND(SUM(G.gross_price*FS.sold_quantity), 2) AS Gross_sales_Amount
FROM fact_sales_monthly FS JOIN dim_customer C ON FS.customer_code = C.customer_code
						   JOIN fact_gross_price G ON FS.product_code = G.product_code
WHERE C.customer = 'Atliq Exclusive'
GROUP BY  Month, FS.fiscal_year 
ORDER BY FS.fiscal_year ;

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Q8) In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity,Quarter total_sold_quantity

select  CASE 
		WHEN date BETWEEN  '2019-09-01' AND '2019-11-30' THEN 1
        WHEN date BETWEEN  '2019-12-01' AND '2020-02-29' THEN 2
        WHEN date BETWEEN  '2020-03-01' AND '2020-05-31' THEN 3
        WHEN date BETWEEN  '2020-06-01' AND '2020-08-31' THEN 4
        END AS Quarter,
SUM(sold_quantity)  AS total_sold_quantity  FROM fact_sales_monthly
WHERE fiscal_year = '2020'
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Q9) Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? The final output contains these fields, 
-- channel, gross_sales_mln, percentage

-- channel from dim_customer
-- gross_sales = gross_price(from fact_gross_price) * total_quantity( from fact_sales_monthly)
-- percentage is just a calculated column

WITH cte as (
Select channel, CONCAT(ROUND(SUM(fgp.gross_price * fsm.sold_quantity)/1000000, 2), ' M') as gross_sales_mln from fact_gross_price as fgp inner join fact_sales_monthly as fsm
ON fgp.product_code = fsm.product_code
inner join dim_customer as dc ON fsm.customer_code = dc.customer_code
GROUP BY channel
)
select * , CONCAT(ROUND(( gross_sales_mln)*100/sum(gross_sales_mln) over(),2), '%') as percentage from cte order by percentage desc;

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Q10)Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these
 -- fields division, product_code, product, total_sold_quantity, rank_order
 
WITH cte1 AS (
SELECT dp.division, fsm.product_code, dp.product, SUM(fsm.sold_quantity) AS Total_sold_quantity
FROM dim_product dp JOIN fact_sales_monthly fsm
ON dp.product_code = fsm.product_code
WHERE fsm.fiscal_year = 2021 
GROUP BY  fsm.product_code, division, dp.product),
cte2 AS (
SELECT division, product_code, product, Total_sold_quantity,
        RANK() OVER(PARTITION BY division ORDER BY Total_sold_quantity DESC) AS 'Rank_Order' 
FROM cte1)
SELECT cte1.division, cte1.product_code, cte1.product, cte2.Total_sold_quantity, cte2.Rank_Order
FROM cte1 JOIN cte2
ON cte1.product_code = cte2.product_code
WHERE cte2.Rank_Order <= 3

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------