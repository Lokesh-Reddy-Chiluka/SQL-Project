use chinook;
-- --1.	Does any table have missing values or duplicates? If yes how would you handle it ?
      --- no duplicates in the table
      --  Check NULL values in customer table
select
sum(case when first_name is null then 1 else 0 end) as null_first_name,
sum(case when last_name is null then 1 else 0 end) as null_last_name,
sum(case when email is null then 1 else 0 end) as null_email,
sum(case when phone is null then 1 else 0 end) as null_phone,
sum(case when fax is null then 1 else 0 end) as null_fax,
sum(case when company is null then 1 else 0 end) as null_company,
sum(case when state is null then 1 else 0 end) as null_state,
sum(case when country is null then 1 else 0 end) as null_country,
sum(case when address is null then 1 else 0 end) as null_address,
sum(case when city is null then 1 else 0 end) as null_city
from customer;
 -- -- there are null values in colums phone-1,fax-4,company-49,state-29
 -- -- these are handled using update or coalesce function 
 set sql_safe_updates=0;
 UPDATE customer SET company = 'Unknown' WHERE company IS NULL;   -- 49 rows affected
UPDATE customer SET state = 'None' WHERE state IS NULL; -- 29 row(s) affected
UPDATE customer SET phone = '+0 000 000 0000' WHERE phone IS NULL; -- 1 row(s) affected
UPDATE customer SET fax = '+0 000 000 0000' WHERE fax IS NULL; -- 47 row(s) affected

-- -- Check NULL values in track table
select
    sum(case when composer is null then 1 else 0 end) as null_composer,
    sum(case when album_id is null then 1 else 0 end) as null_album_id,
    sum(case when genre_id is null then 1 else 0 end) as null_genre_id,
    sum(case when milliseconds is null then 1 else 0 end) as null_milliseconds
from track;
-- -- there are 978 null values in composer 
-- -- updating these null values 
UPDATE track SET composer = 'Unknown' WHERE composer IS NULL; -- 978 row(s) affected
-- -- check null values in employee table 
select * from employee
where employee_id is null or last_name is null or first_name is null or title is null
or reports_to is null or birthdate is null or hire_date is null or address is null or city is null
or state is null or country is null  -- one null value in reports_to
  -- -- updating this null value
  UPDATE employee set reports_to=0 where reports_to is null
-- --2.	Find the top-selling tracks and top artist in the USA and identify their most famous genres.
-- -- A.Top 10 tracks by units sold in USA
select t.name as track_name,ar.name as artist,g.name as genre,sum(il.quantity) as units_sold
from invoice_line as il join invoice as i on il.invoice_id = i.invoice_id
join track as t on il.track_id = t.track_id
join album as al on t.album_id = al.album_id
join artist as ar on al.artist_id = ar.artist_id
join genre as g on t.genre_id = g.genre_id
join customer as c on i.customer_id = c.customer_id
where c.country = 'usa'
group by t.track_id, t.name, ar.name, g.name
order by units_sold desc
limit 10;
   -- --B.Top 5 artists by revenue in USA
select ar.name as artist,round(sum(il.unit_price * il.quantity), 2) as revenue_usd
from invoice_line as il
join invoice as i on il.invoice_id = i.invoice_id
join customer as c on i.customer_id = c.customer_id
join track as t on il.track_id = t.track_id
join album as al on t.album_id = al.album_id
join artist as ar on al.artist_id = ar.artist_id
where c.country = 'usa'
group by ar.artist_id, ar.name
order by revenue_usd desc
limit 5;
   -- -- 2C Most famous genre per top USA artist
select ar.name as artist, g.name as top_genre,round(sum(il.unit_price * il.quantity), 2) as genre_revenue
from invoice_line as il
join invoice as i on il.invoice_id = i.invoice_id
join customer as c on i.customer_id = c.customer_id
join track as t on il.track_id = t.track_id
join album as al on t.album_id = al.album_id
join artist as ar on al.artist_id = ar.artist_id
join genre as g on t.genre_id = g.genre_id
where c.country = 'usa'
group by ar.artist_id, ar.name, g.genre_id, g.name
order by ar.name, genre_revenue desc;

-- -- 3.	What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?
-- --  loaction breakdown
select country, state, city, COUNT(*) AS customers
from customer
group by country, state, city
order by customers DESC;

-- -- 4.	Calculate the total revenue and number of invoices for each country, state, and city:
select billing_country,billing_state,billing_city,count(invoice_id) as total_invoices,sum(total) as total_revenue
from invoice
group by billing_country, billing_state, billing_city
order by total_revenue desc;

-- -- 5.Find the top 5 customers by total revenue in each country
with cte as (
    select c.customer_id,c.first_name,c.last_name,c.country,sum(i.total) as revenue,
	dense_rank() over(partition by c.country order by sum(i.total) desc) as rnk
    from customer as c join invoice as i on c.customer_id = i.customer_id
    group by c.customer_id, c.country
) 
select * from cte
where rnk <= 5;

-- -- 6.Identify the top-selling track for each customer
with cte as(
    select c.customer_id,t.name as track,sum(il.quantity) as purchases,
	rank() over(partition by c.customer_id order by sum(il.quantity) desc) as rnk
    from customer as c join invoice as i on c.customer_id = i.customer_id
    join invoice_line as il on i.invoice_id = il.invoice_id
    join track as t on il.track_id = t.track_id
    group by c.customer_id, t.name
)
select * from cte
where rnk = 1;

-- --7.	Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?
 -- frequency of purchases
select c.customer_id,c.first_name,c.last_name,count(i.invoice_id) as total_purchases
from customer as c join invoice as i
on c.customer_id = i.customer_id
group by c.customer_id, c.first_name, c.last_name
order by total_purchases desc;
  -- Average order value
select customer_id,round(avg(total), 2) as avg_order_value
from invoice
group by customer_id
order by avg_order_value desc;

-- -- 8.What is the customer churn rate?
 -- Customer churn rate measures the percentage of customers who stopped purchasing from the store during a specific period.
 -- we assume that customers who have not made any purchases in the last 3 months are considered churned customers
select count(*) as churned_customers
from customer
where customer_id not in (select distinct customer_id from invoice
    where invoice_date >= date_sub((select max(invoice_date) from invoice),interval 3 month)
);
 
 
 -- -- 9.Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.
-- Total Sales by Genre in the USA
select g.name as genre,sum(il.unit_price * il.quantity) as genre_sales,
round(100 * sum(il.unit_price * il.quantity) /sum(sum(il.unit_price * il.quantity)) over(),2) as percentage_of_total_sales
from invoice as i
join invoice_line as il on i.invoice_id = il.invoice_id
join track as t on il.track_id = t.track_id
join genre as g on t.genre_id = g.genre_id
where i.billing_country = 'usa'
group by g.name
order by genre_sales desc;

-- Best-Selling Genre and Artist Together
select g.name as genre,ar.name as artist,sum(il.unit_price * il.quantity) as sales
from invoice as i
join invoice_line as il on i.invoice_id = il.invoice_id
join track as t on il.track_id = t.track_id
join genre as g on t.genre_id = g.genre_id
join album as al on t.album_id = al.album_id
join artist as ar on al.artist_id = ar.artist_id
where i.billing_country = 'usa'
group by g.name, ar.name
order by sales desc;

-- -- 10.	Find customers who have purchased tracks from at least 3 different genres
select c.customer_id,count(distinct g.genre_id) as genres_purchased
from customer as c
join invoice as i on c.customer_id = i.customer_id
join invoice_line as il on i.invoice_id = il.invoice_id
join track as  t on il.track_id = t.track_id
join genre as g on t.genre_id = g.genre_id
group by c.customer_id
having count(distinct g.genre_id) >= 3;

-- -- 11.	Rank genres based on their sales performance in the USA
select g.name as genre,sum(il.quantity) as units_sold,round(sum(il.unit_price * il.quantity), 2) as revenue_usd,
    rank() over (order by sum(il.unit_price * il.quantity) desc) as revenue_rank,
    rank() over (order by sum(il.quantity) desc) as units_rank
from invoice_line as il
join invoice as i on il.invoice_id = i.invoice_id
join customer as c on i.customer_id = c.customer_id
join track as t on il.track_id   = t.track_id
join genre as g on t.genre_id    = g.genre_id
where c.country = 'usa'
group by g.genre_id, g.name
order by revenue_rank;

-- -- 12.	Identify customers who have not made a purchase in the last 3 months
select c.customer_id,c.first_name,c.last_name,c.email,c.country
from customer as c
where c.customer_id not in(select distinct customer_id from invoice
		where invoice_date >= date_sub((select max(invoice_date) from invoice),interval 3 month)
);


-- --    Subjective Questions -- --
-- -- 1.Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.
with recommendedalbums as (
    select al.title as album_name,a.name as artist_name,g.name as genre_name,
	sum(i.total) as total_sales,sum(il.quantity) as total_quantity,
	row_number() over(order by sum(i.total) desc) as sales_rank
    from customer as c 
    join invoice as i on c.customer_id = i.customer_id
    join invoice_line as il on i.invoice_id = il.invoice_id
    join track as t on il.track_id = t.track_id
    join album as al on t.album_id = al.album_id
    join artist as a on al.artist_id = a.artist_id
    join genre as g on t.genre_id = g.genre_id
    where c.country = 'usa'
    group by al.title, a.name, g.name
)
select *
from recommendedalbums
order by total_sales desc
limit 3;

-- -- 2.	Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.
 -- in usa
select i.billing_country,g.name as genre,sum(il.unit_price * il.quantity) as revenue
from invoice as i
join invoice_line as il on i.invoice_id = il.invoice_id
join track as t on il.track_id = t.track_id
join genre as g on t.genre_id = g.genre_id
where i.billing_country = 'usa'
group by i.billing_country, g.name
order by revenue desc
limit 10;

-- other than usa
select i.billing_country,g.name as genre,sum(il.unit_price * il.quantity) as revenue
from invoice as i
join invoice_line as il on i.invoice_id = il.invoice_id
join track as t on il.track_id = t.track_id
join genre as g on t.genre_id = g.genre_id
where i.billing_country <> 'usa'
group by i.billing_country, g.name
order by revenue desc
limit 10;

-- -- 3.Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?
WITH cte as
(
SELECT i.customer_id, MAX(invoice_date), MIN(invoice_date), abs(TIMESTAMPDIFF(MONTH, MAX(invoice_date), MIN(invoice_date))) time_for_each_customer, SUM(total) sales, SUM(quantity) items, COUNT(invoice_date) frequency FROM invoice i
LEFT JOIN customer c on c.customer_id = i.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
GROUP BY 1
ORDER BY time_for_each_customer DESC
),
average_time as
(
SELECT AVG(time_for_each_customer) average FROM cte
),-- 1244.3220 Days OR 40.36 Months
categorization as
(
SELECT *,
CASE
WHEN time_for_each_customer > (SELECT average from average_time) THEN "Long-term Customer" ELSE "Short-term Customer" 
END category
FROM cte
)
SELECT category, SUM(sales) total_spending, SUM(items) basket_size, COUNT(frequency) frequency FROM categorization
GROUP BY 1;  


-- -- 4.	Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives?
select g1.name as genre_1,g2.name as genre_2,count(distinct i.customer_id) as shared_customers
from invoice_line as il1
join invoice as i on il1.invoice_id = i.invoice_id
join track as t1 on il1.track_id = t1.track_id
join genre g1 on t1.genre_id = g1.genre_id
join invoice_line as il2 on il2.invoice_id = i.invoice_id and il2.track_id <> il1.track_id
join track as t2 on il2.track_id = t2.track_id
join genre as g2 on t2.genre_id = g2.genre_id and g2.genre_id > g1.genre_id
group by g1.name, g2.name
order by shared_customers desc
limit 15;

-- -- 5.	Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?
select c.country,count(distinct c.customer_id) as total_customers,
count(distinct case when i.invoice_date >= date_sub((select max(invoice_date) from invoice), interval 3 month) then i.customer_id
    end) as active_customers,
count(distinct c.customer_id) -count(distinct case when i.invoice_date >= date_sub((select max(invoice_date) from invoice), interval 3 month)
        then i.customer_id
    end) as churned_customers,
count(i.invoice_id) as total_orders,sum(i.total) as total_revenue,round(avg(i.total), 2) as avg_order_value
from customer as c
left join invoice as i
on c.customer_id = i.customer_id
group by c.country
order by total_revenue desc;


-- -- 6.	Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?
with customer_metrics as(
    select c.customer_id,c.first_name,c.last_name,c.country,count(i.invoice_id) as purchase_frequency,
	sum(i.total) as total_spent,max(i.invoice_date) as last_purchase_date
    from customer as c
    left join invoice as i
    on c.customer_id = i.customer_id
    group by c.customer_id, c.first_name, c.last_name, c.country
)
select customer_id,first_name,last_name,country,purchase_frequency,total_spent,last_purchase_date,
case when purchase_frequency <= 2 and last_purchase_date <= date_sub((select max(invoice_date) from invoice), interval 3 month)
        then 'high risk'
when purchase_frequency <= 5 then 'medium risk'
else 'low risk'
end as risk_segment
from customer_metrics
order by risk_segment;


-- -- 7.	Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?
with customer_profile as (
select c.customer_id,concat(c.first_name, ' ', c.last_name) as customers,c.country,coalesce(c.state,'n.a') as state,
c.city,min(i.invoice_date) as first_purchase_date,max(i.invoice_date) as last_purchase_date,
datediff(max(i.invoice_date), min(i.invoice_date)) as customer_tenure_days,count(i.invoice_id) as total_purchases,
sum(i.total) as total_spending,round(avg(i.total),2) as avg_order_value
from customer c left join invoice i on c.customer_id = i.customer_id
group by c.customer_id
),
customer_lifetime_value as (
    select cp.customer_id,cp.customers,cp.country,cp.state,cp.city,cp.customer_tenure_days,cp.total_purchases,cp.total_spending,cp.avg_order_value,
	case when cp.customer_tenure_days >= 365 then 'long-term'else 'short-term'
        end as customer_segment,
	case when cp.last_purchase_date < date_sub(curdate(), interval 1 year) then 'churned'else 'active'
	end as customer_status,
	round((cp.total_spending / greatest(cp.customer_tenure_days, 1)) * 365,2) as predicted_annual_value,cp.total_spending as lifetime_value
    from customer_profile cp
),
segment_analysis as (
    select customer_segment,customer_status,count(customer_id) as num_customers,avg(customer_tenure_days) as avg_tenure_days,avg(total_spending) as avg_lifetime_value,
    avg(predicted_annual_value) as avg_predicted_annual_value
    from customer_lifetime_value
    group by customer_segment, customer_status
),
churn_analysis as (
    select country,state,city,customer_segment,count(customer_id) as churned_customers,avg(total_spending) as avg_lifetime_value
    from customer_lifetime_value
    where customer_status = 'churned'
    group by country, state, city, customer_segment
)
select *
from customer_lifetime_value
order by lifetime_value desc;

-- -- 8 and 9 questions are explained in document
-- --10.	How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?
ALTER table album
ADD COLUMN  ReleaseYear int(4);


-- -- 11.	Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.
select c.country,count(distinct c.customer_id) as total_customers,round(avg(customer_spending.total_spent),2) as avg_amount_spent_per_customer,
round(avg(customer_spending.total_tracks),2) as avg_tracks_per_customer
from customer as c join
(
    select i.customer_id,sum(i.total) as total_spent,count(il.track_id) as total_tracks
    from invoice as i
    join invoice_line as il on i.invoice_id = il.invoice_id
    group by i.customer_id
) customer_spending
on c.customer_id = customer_spending.customer_id
group by c.country
order by avg_amount_spent_per_customer desc;