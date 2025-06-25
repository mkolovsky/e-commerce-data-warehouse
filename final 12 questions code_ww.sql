select * from order_item_refunds;

#setting primary and foreign keys
DESCRIBE users;
CREATE TABLE website_sessions (
    website_session_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    user_id BIGINT,
    is_repeat_session SMALLINT,
    utm_source VARCHAR(12),
    utm_campaign VARCHAR(20),
    utm_content VARCHAR(15),
    device_type VARCHAR(20),
    http_referer VARCHAR(30)
);
ALTER TABLE website_pageviews
ADD PRIMARY KEY (website_pageview_id);

ALTER TABLE website_sessions
ADD PRIMARY KEY (website_session_id);

ALTER TABLE users
ADD PRIMARY KEY (user_id);

ALTER TABLE orders
ADD PRIMARY KEY (order_id);

ALTER TABLE products
ADD PRIMARY KEY (product_id);

ALTER TABLE order_items
ADD PRIMARY KEY (order_item_id);

ALTER TABLE order_item_refunds
ADD PRIMARY KEY (order_item_refund_id);

ALTER TABLE dim_date
ADD PRIMARY KEY (date);

ALTER TABLE order_item_refunds
ADD COLUMN order_item_refund_id INT AUTO_INCREMENT PRIMARY KEY;


SHOW CREATE TABLE website_pageviews;
SHOW CREATE TABLE website_sessions;

ALTER TABLE website_pageviews
MODIFY COLUMN website_session_id INT;
ALTER TABLE website_pageviews
ADD CONSTRAINT fk_pageviews_session
FOREIGN KEY (website_session_id) REFERENCES website_sessions(website_session_id);


-- Step 1: See the broken session IDs
SELECT DISTINCT website_session_id
FROM website_pageviews
WHERE website_session_id NOT IN (
    SELECT website_session_id
    FROM website_sessions
);

-- Step 2: Clean the broken rows
DELETE FROM website_pageviews
WHERE website_session_id NOT IN (
    SELECT website_session_id
    FROM website_sessions
);

-- Step 3: Now add the foreign key
ALTER TABLE website_pageviews
ADD CONSTRAINT fk_pageviews_session
FOREIGN KEY (website_session_id) REFERENCES website_sessions(website_session_id);


#joins 
SELECT
    -- Orders (fact)
    o.order_id,
    o.created_at AS order_date,
    o.user_id,
    o.website_session_id,
    o.primary_product_id,
    o.price_usd,
    o.items_purchased,
    o.cogs_usd,
    
    -- Users (dimension)
    u.first_name,
    u.last_name,
    u.email,
    u.billing_city,
    u.billing_state,
    u.billing_country,
    
    -- Website Sessions (dimension)
    ws.is_repeat_session,
    ws.utm_source,
    ws.utm_campaign,
    ws.utm_content,
    ws.device_type,
    ws.http_referer,
    
    -- Website Pageviews (optional dimension)
    wp.pageview_url,
    
    -- Products (dimension)
    p.product_name,
    p.created_at AS product_created_date,
    
    -- Order Items (details)
    oi.product_id AS item_product_id,
    oi.price_usd AS item_price_usd,
    
    -- Dim Date (calendar)
    dd.month,
    dd.quarter,
    dd.year

FROM orders o

-- Join users
INNER JOIN users u ON o.user_id = u.user_id

-- Join website_sessions
INNER JOIN website_sessions ws ON o.website_session_id = ws.website_session_id

-- Join website_pageviews
LEFT JOIN website_pageviews wp ON o.website_session_id = wp.website_session_id

-- Join products
INNER JOIN products p ON o.primary_product_id = p.product_id

-- Join dim_date
INNER JOIN dim_date dd ON DATE(o.created_at) = dd.date

-- Join order_items
LEFT JOIN order_items oi ON o.order_id = oi.order_id
;

-- Step 1: Check how many orders are missing matching sessions
SELECT COUNT(*) 
FROM orders o
LEFT JOIN website_sessions ws ON o.user_id = ws.user_id
WHERE ws.user_id IS NULL;

-- Step 2: Update the orders table by assigning random valid website_session_id based on matching user_id
UPDATE orders o
JOIN (
    SELECT user_id, MIN(website_session_id) AS session_id
    FROM website_sessions
    GROUP BY user_id
) ws ON o.user_id = ws.user_id
SET o.website_session_id = ws.session_id
WHERE o.website_session_id IS NULL;

ALTER TABLE orders
ADD COLUMN website_session_id VARCHAR(254);

-- Step 1: Check how many orders have no matching session
SELECT COUNT(*) 
FROM orders o
LEFT JOIN website_sessions ws ON o.user_id = ws.user_id
WHERE o.website_session_id IS NULL;

-- Step 2: Update orders by assigning a valid session_id based on user_id
UPDATE orders o
JOIN (
    SELECT user_id, MIN(website_session_id) AS session_id
    FROM website_sessions
    GROUP BY user_id
) ws ON o.user_id = ws.user_id
SET o.website_session_id = ws.session_id
WHERE o.website_session_id IS NULL;

-- Check again if you have matching user IDs
SELECT DISTINCT o.user_id
FROM orders o
LEFT JOIN website_sessions ws ON o.user_id = ws.user_id
WHERE ws.user_id IS NULL;


#question 1
SELECT
    dd.year,
    dd.month,
    SUM(o.price_usd) AS total_revenue
FROM orders o
INNER JOIN dim_date dd ON DATE(o.created_at) = dd.date
GROUP BY dd.year, dd.month
ORDER BY dd.year, dd.month;

#question 2
WITH yearly_revenue AS (
    SELECT
        dd.year,
        SUM(o.price_usd) AS total_revenue
    FROM orders o
    INNER JOIN dim_date dd ON DATE(o.created_at) = dd.date
    GROUP BY dd.year
)
SELECT
    year,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY year) AS previous_year_revenue,
    (total_revenue - LAG(total_revenue) OVER (ORDER BY year)) AS yoy_change,
    ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY year)) / LAG(total_revenue) OVER (ORDER BY year) * 100, 2) AS yoy_percentage_change
FROM yearly_revenue;


#question 3
SELECT
    u.billing_state,
    u.billing_country,
    SUM(o.price_usd) AS total_sales,
    SUM(o.price_usd - o.cogs_usd) AS total_profit
FROM orders o
INNER JOIN users u ON o.user_id = u.user_id
GROUP BY u.billing_state, u.billing_country
ORDER BY total_sales DESC;

#question 4
DESCRIBE order_item_refunds;
SELECT 
    DATE(created_at) AS return_date,
    COUNT(order_item_refund_id) AS number_of_returns
FROM 
    order_item_refunds
GROUP BY 
    return_date
ORDER BY 
    number_of_returns DESC
LIMIT 2;

#question 5
SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month_year,
    SUM(price_usd) AS total_sales
FROM 
    orders
GROUP BY 
    month_year
ORDER BY 
    month_year;

#question 6
SELECT 
    u.user_id,
    u.first_name,
    u.last_name,
    YEAR(o.created_at) AS year,
    SUM(o.price_usd * o.items_purchased) AS total_spent
FROM 
    orders o
JOIN 
    users u ON o.user_id = u.user_id
GROUP BY 
    u.user_id, u.first_name, u.last_name, year
ORDER BY 
    total_spent DESC
LIMIT 5;

#question 7
SELECT DISTINCT created_at
FROM order_item_refunds
ORDER BY created_at;

SELECT 
    DAYNAME(LEFT(created_at, 10)) AS day_of_week,
    COUNT(order_item_refund_id) AS number_of_returns
FROM 
    order_item_refunds
WHERE 
    LEFT(created_at, 10) BETWEEN '2021-03-01' AND '2021-03-31'
GROUP BY 
    day_of_week
ORDER BY 
    FIELD(day_of_week, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

#question 8
SELECT 
    DATE_FORMAT(o.created_at, '%Y-%m') AS month_year,
    QUARTER(o.created_at) AS quarter,
    p.product_name,
    SUM(o.price_usd * o.items_purchased) / COUNT(*) AS avg_revenue,
    SUM(o.cogs_usd) / COUNT(*) AS avg_cogs
FROM 
    orders o
JOIN 
    products p ON o.primary_product_id = p.product_id
GROUP BY 
    month_year, quarter, p.product_name
ORDER BY 
    month_year, quarter, p.product_name;
    
#question 9
SELECT 
    DATE_FORMAT(o.created_at, '%Y-%m') AS month_year,
    SUM(o.price_usd * o.items_purchased) / COUNT(*) AS avg_revenue
FROM 
    orders o
GROUP BY 
    month_year
ORDER BY 
    month_year;


#question 10
SELECT 
    DATE(o.created_at) AS purchase_date,
    COUNT(o.order_id) AS purchase_count
FROM 
    orders o
JOIN 
    users u ON o.user_id = u.user_id
WHERE 
    DATE_FORMAT(o.created_at, '%Y-%m') = '2021-03'
GROUP BY 
    purchase_date
ORDER BY 
    purchase_date;

SELECT 
    DATE(o.created_at) AS purchase_date,
    u.billing_city,
    COUNT(o.order_id) AS purchase_count
FROM 
    orders o
JOIN 
    users u ON o.user_id = u.user_id
WHERE 
    DATE_FORMAT(o.created_at, '%Y-%m') = '2021-03'
    AND u.billing_city IS NOT NULL
GROUP BY 
    purchase_date, u.billing_city
ORDER BY 
    purchase_date;


#bruh
SELECT * FROM website_pageviews LIMIT 10;
SELECT * FROM orders LIMIT 10;

SELECT wp.website_session_id, o.website_session_id
FROM website_pageviews wp
LEFT JOIN orders o ON wp.website_session_id = o.website_session_id
LIMIT 10;


#question 11
SELECT
    wp.pageview_url,  -- landing page URL from website_pageviews
    COUNT(DISTINCT o.order_id) AS number_of_orders  -- count of distinct orders from orders
FROM website_pageviews wp
JOIN orders o
    ON wp.website_session_id = o.website_session_id  -- join orders based on website_session_id
GROUP BY wp.pageview_url  -- group by landing page URL
ORDER BY number_of_orders DESC;


#question 12
SELECT 
    ws.device_type,
    COUNT(DISTINCT o.order_id) AS number_of_orders
FROM website_sessions ws
JOIN orders o ON ws.user_id = o.user_id
GROUP BY ws.device_type
ORDER BY number_of_orders DESC;



#dim and fact tables i guess
CREATE TABLE fact_purchased_items (
    order_id INT, -- Make sure this matches the data type in the orders table
    product_id INT, -- Make sure this matches the data type in the products table
    price_usd DECIMAL(10, 2),
    items_purchased INT,
    cogs_usd DECIMAL(10, 2),
    order_date DATE, -- Optional, if needed for the grain level of your analysis
    PRIMARY KEY (order_id, product_id) -- Depending on your grain, this could be adjusted
);

DESCRIBE orders;
DESCRIBE fact_purchased_items;
DESCRIBE orders;
DESCRIBE fact_purchased_items;

ALTER TABLE fact_purchased_items
MODIFY order_id BIGINT;

ALTER TABLE fact_purchased_items
ADD CONSTRAINT fk_fact_purchased_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id);


CREATE TABLE dim_product (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255),
    product_category VARCHAR(100),
    product_description TEXT
);

CREATE TABLE dim_user (
    user_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    billing_city VARCHAR(100),
    billing_state VARCHAR(100),
    billing_country VARCHAR(100)
);

-- Check the structure (columns and data types) of the 'orders' table
DESCRIBE orders;

-- Check the structure (columns and data types) of the 'products' table
DESCRIBE products;

-- Check the structure (columns and data types) of the 'fact_returned_items' table
DESCRIBE fact_returned_items;

-- Check the structure (columns and data types) of the 'website_pageviews' table
DESCRIBE website_pageviews;

-- Check the structure (columns and data types) of the 'website_sessions' table
DESCRIBE website_sessions;

CREATE TABLE fact_returned_items (
    order_id BIGINT,  -- Change to BIGINT to match the type in 'orders' table
    product_id INT,   -- Keep as INT, since it matches with the 'products' table
    price_usd DECIMAL(10, 2),
    items_returned INT,
    cogs_usd DECIMAL(10, 2),
    return_date DATE,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE dim_landing_page (
    landing_page_id INT AUTO_INCREMENT,  -- Unique ID for each landing page
    pageview_url VARCHAR(255),  -- URL of the landing page
    utm_campaign VARCHAR(255),  -- UTM campaign for tracking
    utm_source VARCHAR(255),  -- UTM source for tracking
    created_at DATETIME,  -- Timestamp of when the pageview occurred
    website_session_id INT,  -- Associated session
    PRIMARY KEY (landing_page_id),  -- Primary key for the table
    FOREIGN KEY (website_session_id) REFERENCES website_sessions(website_session_id)  -- Link to sessions table
);

#add data into dim and fact

DESCRIBE website_pageviews;
-- Create dim_landing_page table
CREATE TABLE dim_landing_page (
    landing_page_id INT AUTO_INCREMENT PRIMARY KEY, -- Unique ID for each landing page
    pageview_url VARCHAR(255), -- URL of the landing page
    created_at DATETIME, -- Timestamp of when the pageview occurred
    website_session_id INT, -- Associated session
    FOREIGN KEY (website_session_id) REFERENCES website_sessions(website_session_id) -- Link to sessions table
);

DROP TABLE IF EXISTS dim_landing_page;

CREATE TABLE dim_landing_page (
    landing_page_id INT AUTO_INCREMENT PRIMARY KEY, -- Unique ID for each landing page
    pageview_url VARCHAR(255), -- URL of the landing page
    created_at DATETIME, -- Timestamp of when the pageview occurred
    website_session_id INT, -- Associated session
    FOREIGN KEY (website_session_id) REFERENCES website_sessions(website_session_id) -- Link to sessions table
);
INSERT INTO dim_landing_page (pageview_url, created_at, website_session_id)
SELECT wp.pageview_url, wp.created_at, wp.website_session_id
FROM website_pageviews wp;

SELECT * FROM dim_landing_page;
#bugs
SELECT * FROM website_pageviews LIMIT 10;
SELECT pageview_url, created_at, website_session_id FROM website_pageviews LIMIT 10;
-- Insert data into the dim_landing_page table (only using available columns)
INSERT INTO dim_landing_page (pageview_url, created_at, website_session_id)
SELECT wp.pageview_url, wp.created_at, wp.website_session_id
FROM website_pageviews wp;
SELECT * FROM dim_landing_page LIMIT 10;

SELECT * FROM website_pageviews LIMIT 10;

CREATE TABLE dim_landing_page (
    landing_page_id INT AUTO_INCREMENT PRIMARY KEY,
    pageview_url VARCHAR(500),
    created_at DATETIME,
    website_session_id INT
);

INSERT IGNORE INTO dim_date (date, day, month, month_name, year, quarter, week, weekday_name, is_weekend)
SELECT DISTINCT
    DATE(o.created_at) AS date,
    DAY(o.created_at) AS day,
    MONTH(o.created_at) AS month,
    MONTHNAME(o.created_at) AS month_name,
    YEAR(o.created_at) AS year,
    QUARTER(o.created_at) AS quarter,
    WEEK(o.created_at, 1) AS week,
    DAYNAME(o.created_at) AS weekday_name,
    CASE
        WHEN DAYOFWEEK(o.created_at) IN (1,7) THEN 1 ELSE 0
    END AS is_weekend
FROM orders o
WHERE o.created_at IS NOT NULL;

INSERT INTO dim_date (date, day, month, month_name, year, quarter, week, weekday_name, is_weekend)
SELECT DISTINCT
    DATE(o.created_at) AS date,
    DAY(o.created_at) AS day,
    MONTH(o.created_at) AS month,
    MONTHNAME(o.created_at) AS month_name,
    YEAR(o.created_at) AS year,
    QUARTER(o.created_at) AS quarter,
    WEEK(o.created_at, 1) AS week, -- mode 1 = ISO week starts on Monday
    DAYNAME(o.created_at) AS weekday_name,
    CASE
        WHEN DAYOFWEEK(o.created_at) IN (1,7) THEN 1 ELSE 0
    END AS is_weekend
FROM orders o
WHERE o.created_at IS NOT NULL;

SELECT COUNT(*)
FROM dim_date;
INSERT INTO dim_product (product_id, product_name)
SELECT DISTINCT
    p.product_id,
    p.product_name
FROM products p;

INSERT INTO dim_user (user_id, first_name, last_name, email)
SELECT DISTINCT
    u.user_id,
    u.first_name,
    u.last_name,
    u.email
FROM users u;
DROP TABLE IF EXISTS website_sessions;

DESCRIBE orders;
SELECT * FROM order_items LIMIT 10;
SELECT COUNT(*)
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id;


TRUNCATE TABLE fact_purchased_items;
ALTER TABLE fact_purchased_items DROP PRIMARY KEY;
SELECT CONSTRAINT_NAME, TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_NAME = 'fact_purchased_items';

CREATE TABLE fact_purchased_items_copy AS
SELECT * FROM fact_purchased_items;
DROP TABLE fact_purchased_items;
CREATE TABLE fact_purchased_items (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    price_usd DECIMAL(10,2),
    items_purchased INT,
    cogs_usd DECIMAL(10,2),
    order_date DATETIME,
    PRIMARY KEY (order_id, product_id)
);
INSERT INTO fact_purchased_items (order_id, product_id, price_usd, items_purchased, cogs_usd, order_date)
SELECT order_id, product_id, price_usd, items_purchased, cogs_usd, order_date
FROM fact_purchased_items_copy;
DROP TABLE fact_purchased_items_copy;


CREATE TABLE fact_returned_items (
    return_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    items_returned INT,
    return_date DATETIME,
    return_reason VARCHAR(255),
    FOREIGN KEY (order_id, product_id) REFERENCES fact_purchased_items(order_id, product_id)
);

TRUNCATE TABLE fact_returned_items;

INSERT INTO fact_returned_items (order_id, product_id, price_usd, items_returned, cogs_usd, return_date)
SELECT 
    oi.order_id,
    oi.product_id,
    oi.price_usd,
    1 AS items_returned,  -- assuming 1 item returned for each record
    oi.cogs_usd,
    oi.created_at AS return_date
FROM order_items oi;

TRUNCATE TABLE fact_returned_items;

INSERT INTO fact_returned_items (order_id, product_id, price_usd, items_returned, cogs_usd, return_date)
SELECT
    oi.order_id,
    oi.product_id,
    oi.price_usd,
    1 AS items_returned,
    oi.cogs_usd,
    oi.created_at AS return_date
FROM order_items oi
LIMIT 10000;

INSERT INTO dim_landing_page (pageview_url, created_at, website_session_id)
SELECT 
    pageview_url,
    created_at,
    website_session_id
FROM website_pageviews
WHERE pageview_url IS NOT NULL;

#all fact and dim tables are poroperly created and structured
#answering the 12 questions using the fact and dim tables now
#q 1
SELECT 
    YEAR(created_at) AS order_year,
    MONTH(created_at) AS order_month,
    SUM(price_usd) AS total_revenue
FROM orders
GROUP BY order_year, order_month
ORDER BY order_year, order_month;

#q2
WITH yearly_revenue AS (
    SELECT 
        YEAR(created_at) AS year,
        SUM(price_usd) AS total_revenue
    FROM orders
    GROUP BY YEAR(created_at)
)
SELECT 
    year,
    total_revenue,
    total_revenue - LAG(total_revenue) OVER (ORDER BY year) AS revenue_change
FROM yearly_revenue;

#q3
SELECT 
    u.billing_state AS state,
    u.billing_country AS country,
    SUM(o.price_usd) AS total_sales,
    SUM(o.price_usd - o.cogs_usd) AS total_profit
FROM orders o
JOIN users u ON o.user_id = u.user_id
GROUP BY u.billing_state, u.billing_country
ORDER BY total_sales DESC;

#q4
SELECT 
    p.product_name,
    SUM(fri.items_returned) AS total_items_returned,
    SUM(fri.price_usd) AS lost_revenue
FROM fact_returned_items fri
JOIN products p ON fri.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_items_returned DESC
LIMIT 2;

#q5 

SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS year_month,
    SUM(price_usd) AS total_sales
FROM orders
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY DATE_FORMAT(created_at, '%Y-%m');

#question 6
SELECT 
    o.user_id,
    YEAR(o.created_at) AS order_year,
    SUM(o.price_usd) AS total_spent
FROM orders o
GROUP BY o.user_id, order_year
ORDER BY total_spent DESC
LIMIT 5;

#question 7 for june 2022
SELECT 
    MIN(return_date) AS earliest_return,
    MAX(return_date) AS latest_return
FROM fact_returned_items;

SELECT 
    DAYNAME(return_date) AS day_of_week,
    SUM(items_returned) AS total_returns
FROM fact_returned_items
WHERE return_date BETWEEN '2022-06-01' AND '2022-06-30'
GROUP BY day_of_week
ORDER BY FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');

#question 8
SELECT 
    p.product_name AS product_line,
    YEAR(o.created_at) AS order_year,
    MONTH(o.created_at) AS order_month,
    QUARTER(o.created_at) AS order_quarter,
    SUM(o.price_usd) / COUNT(*) AS avg_revenue,
    SUM(o.cogs_usd) / COUNT(*) AS avg_cogs
FROM orders o
JOIN products p ON o.primary_product_id = p.product_id
GROUP BY p.product_name, order_year, order_month, order_quarter
ORDER BY order_year, order_month, p.product_name;

#question 9
SELECT 
    YEAR(created_at) AS order_year,
    MONTH(created_at) AS order_month,
    SUM(price_usd) / COUNT(*) AS avg_revenue,
    SUM(cogs_usd) / COUNT(*) AS avg_cogs
FROM orders
GROUP BY order_year, order_month
ORDER BY order_year, order_month;


#question 10 targeting march 2024
SELECT 
    MIN(created_at) AS earliest_order,
    MAX(created_at) AS latest_order
FROM orders;
SELECT DISTINCT u.billing_city
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE o.created_at BETWEEN '2024-03-01' AND '2024-03-31';

#question 11
SELECT 
    dlp.pageview_url AS landing_page,
    ws.utm_campaign,
    ws.utm_source,
    COUNT(DISTINCT o.order_id) AS order_count
FROM orders o
JOIN dim_landing_page dlp ON o.website_session_id = dlp.website_session_id
JOIN website_sessions_xls ws ON o.website_session_id = ws.website_session_id
GROUP BY dlp.pageview_url, ws.utm_campaign, ws.utm_source
ORDER BY order_count DESC;

#question 12
SELECT 
    ws.device_type,
    p.product_name,
    COUNT(oi.order_item_id) AS product_sales
FROM orders o
JOIN website_sessions_xls ws ON o.website_session_id = ws.website_session_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY ws.device_type, p.product_name
ORDER BY ws.device_type, product_sales DESC;







































INSERT INTO fact_returned_items (order_id, product_id, items_returned, return_date, return_reason) SELECT      oi.order_id,     oi.product_id,     oi.items_returned,     o.return_date,     o.return_reason FROM      order_items_refunds oi JOIN      orders o ON oi.order_id = o.order_id
