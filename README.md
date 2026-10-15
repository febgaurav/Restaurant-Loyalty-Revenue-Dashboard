Restaurant Sales & Loyalty Dashboard (SQL + Power BI)

A practice project where I look at sales and customer loyalty data for a restaurant chain with 10 locations. I stored the data in MySQL, wrote queries to answer business questions, and built a Power BI dashboard to show the results.

The data is made up (synthetic). I created it for practice, so the numbers are not from a real business.

What I wanted to find out:-
Which location earns the most revenue?
How does revenue change from month to month?
Which loyalty tiers (Bronze, Silver, Gold, Platinum) use their points the most?
Which ordering channel gets the most complaints?
Who are the top customers by spend?
Data

The original data was one flat table with 100 rows and 25 columns (customer details, restaurant, visit date, order amount, payment method, loyalty tier, points earned and redeemed, rating, complaint flag, and feedback).

I split it into a star schema with 4 tables:

Table	What it holds
fact_transactions	One row per order (amount, channel, points, rating, complaint)
dim_customer	Customer name, contact details, loyalty tier
dim_restaurant	Restaurant name and location
dim_date	Date, month, quarter, year, weekday/weekend

fact_transactions connects to the other three tables through customer_id, restaurant_id and date_id.


The queries use JOINs, GROUP BY, HAVING, CASE, subqueries, CTEs and window functions (RANK, LAG, ROW_NUMBER, running totals). Examples: revenue by location, top 5 customers, days between a customer's visits, and complaint rate by channel.

Power BI dashboard:

I connected the tables in Power BI, set up the relationships, marked the date table, and wrote a few DAX measures:

Total Revenue
Total Orders
Avg Order Value
Redemption Rate (points redeemed / points earned)
Complaint Rate
