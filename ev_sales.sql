CREATE DATABASE ev_insights;

USE ev_insights;

-- creates 'sales_by_makers' table
CREATE TABLE sales_by_makers (
`date` DATE,
vehicle_category ENUM('2-Wheelers','4-Wheelers'),
maker VARCHAR(19),
electric_vehicles_sold SMALLINT UNSIGNED,
FOREIGN KEY(`date`) REFERENCES calendar(`date`)
);

-- creates 'sales_by_state' table
CREATE TABLE sales_by_state (
`date` DATE,
state VARCHAR(24), 
vehicle_category ENUM('2-Wheelers','4-Wheelers'),
electric_vehicles_sold SMALLINT UNSIGNED,
total_vehicles_sold MEDIUMINT UNSIGNED,
FOREIGN KEY(`date`) REFERENCES calendar(`date`)
);

-- creates 'calendar' table
CREATE TABLE calendar (
`date` DATE,
fiscal_year YEAR,
`quarter` ENUM('Q1','Q2','Q3','Q4'),
PRIMARY KEY (`date`)
);

-- loads data into 'calendar' table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/EV Insights/dates.csv'
INTO TABLE calendar
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- loads data into 'sales_by_makers' table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/EV Insights/sales by makers.csv'
INTO TABLE sales_by_makers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- loads data into 'sales_by_state' table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/EV Insights/sales by state.csv'
INTO TABLE sales_by_state
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- ============================================= DATA ANALYSIS ==================================================

DESCRIBE sales_by_makers;
DESCRIBE sales_by_state;
DESCRIBE calendar;

/* Q1) List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in terms of the number of 
2-wheelers sold. */

SELECT fiscal_year, maker, SUM(electric_vehicles_sold) AS total_ev_sold
FROM sales_by_makers
JOIN calendar 
ON sales_by_makers.`date` = calendar.`date`
WHERE vehicle_category = '2-Wheelers' AND fiscal_year IN (2023, 2024)
GROUP BY fiscal_year, maker
ORDER BY total_ev_sold DESC
LIMIT 3;

-- Q2) Identify the top 5 states with the highest penetration rate in 2-wheeler and 4-wheeler EV sales in FY 2024.

SELECT state, vehicle_category, SUM(electric_vehicles_sold) / SUM(total_vehicles_sold) AS penetration_rate
FROM sales_by_state
JOIN calendar 
ON sales_by_state.`date` = calendar.`date`
WHERE fiscal_year = 2024
GROUP BY state, vehicle_category
ORDER BY penetration_rate DESC
LIMIT 5;

-- Q3) List the states with negative penetration (decline) in EV sales from 2022 to 2024 ?

SELECT state, (SUM(CASE WHEN fiscal_year = 2024 THEN electric_vehicles_sold ELSE 0 END) - 
SUM(CASE WHEN fiscal_year = 2022 THEN electric_vehicles_sold ELSE 0 END)) AS sales_change
FROM sales_by_state
JOIN calendar ON sales_by_state.`date` = calendar.`date`
WHERE fiscal_year IN (2022, 2024)
GROUP BY state
HAVING sales_change < 0;

/* Q4) What are the quarterly trends based on sales volume for the top 5 EV makers (4-wheelers) from 2022 
to 2024? */

SELECT `quarter`, maker, SUM(electric_vehicles_sold) AS total_ev_sold
FROM sales_by_makers
JOIN calendar 
ON sales_by_makers.`date` = calendar.`date`
WHERE vehicle_category = '4-Wheelers' AND fiscal_year BETWEEN 2022 AND 2024
GROUP BY `quarter`, maker
ORDER BY total_ev_sold DESC
LIMIT 5;

-- Q5) How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024?

SELECT state, SUM(electric_vehicles_sold) AS total_ev_sold, 
SUM(electric_vehicles_sold) / SUM(total_vehicles_sold) AS penetration_rate
FROM sales_by_state
JOIN calendar 
ON sales_by_state.`date` = calendar.`date`
WHERE fiscal_year = 2024 AND state IN ('Delhi', 'Karnataka')
GROUP BY state;

/* Q6) List down the compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 
to 2024. */

WITH cagr AS (SELECT maker, 
(POWER(SUM(CASE WHEN fiscal_year = 2024 THEN electric_vehicles_sold ELSE 0 END) / 
SUM(CASE WHEN fiscal_year = 2022 THEN electric_vehicles_sold ELSE 0 END), 1.0/2) - 1) * 100 AS cagr_rate
FROM sales_by_makers
JOIN calendar 
ON sales_by_makers.`date` = calendar.`date`
WHERE vehicle_category = '4-Wheelers' AND fiscal_year IN (2022, 2024)
GROUP BY maker)
SELECT * FROM cagr
ORDER BY cagr_rate DESC
LIMIT 5;

/* Q7) List down the top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 
in total vehicles sold. */

WITH state_cagr AS (
SELECT state, 
(POWER(SUM(CASE WHEN fiscal_year = 2024 THEN total_vehicles_sold ELSE 0 END) / 
SUM(CASE WHEN fiscal_year = 2022 THEN total_vehicles_sold ELSE 0 END), 1.0/2) - 1) * 100 AS cagr_rate
FROM sales_by_state
JOIN calendar 
ON sales_by_state.`date` = calendar.`date`
WHERE fiscal_year IN (2022, 2024)
GROUP BY state)
SELECT * FROM state_cagr
ORDER BY cagr_rate DESC
LIMIT 10;

-- Q8) What are the peak and low season months for EV sales based on the data from 2022 to 2024?

SELECT MONTH(sales_by_state.`date`) AS `month`, SUM(electric_vehicles_sold) AS total_ev_sold
FROM sales_by_state
WHERE year(sales_by_state.`date`) BETWEEN 2022 AND 2024
GROUP BY `month`
ORDER BY total_ev_sold DESC;

/* Q9) What is the projected number of EV sales (including 2-wheelers and 4-wheelers) for the top 10 states
by penetration rate in 2030, based on the compounded annual growth rate (CAGR) from previous years? */

WITH state_cagr AS (
SELECT state, 
(POWER(SUM(CASE WHEN fiscal_year = 2024 THEN electric_vehicles_sold ELSE 0 END) / 
SUM(CASE WHEN fiscal_year = 2022 THEN electric_vehicles_sold ELSE 0 END), 1.0/2) - 1) AS cagr_rate
FROM sales_by_state
JOIN calendar 
ON sales_by_state.`date` = calendar.`date`
WHERE fiscal_year IN (2022, 2024)
GROUP BY state)
SELECT state, SUM(CASE WHEN fiscal_year = 2024 THEN electric_vehicles_sold ELSE 0 END) * 
POWER(1 + cagr_rate, 6) AS projected_sales_2030
FROM state_cagr
ORDER BY projected_sales_2030 DESC
LIMIT 10;

/* Q10) Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and
 2023 vs 2024, assuming an average unit price. */

SELECT vehicle_category, 
((SUM(CASE WHEN c.fiscal_year = 2024 THEN sm.electric_vehicles_sold ELSE 0 END) - 
SUM(CASE WHEN c.fiscal_year = 2022 THEN sm.electric_vehicles_sold ELSE 0 END)) * 
CASE WHEN sm.vehicle_category = '2-Wheelers' THEN 85000 ELSE 1500000 END) / 
NULLIF(SUM(CASE WHEN c.fiscal_year = 2022 THEN sm.electric_vehicles_sold ELSE 0 END) * 
CASE WHEN sm.vehicle_category = '2-Wheelers' THEN 85000 ELSE 1500000 END, 0) * 100 
AS revenue_growth_22_24,
((SUM(CASE WHEN c.fiscal_year = 2024 THEN sm.electric_vehicles_sold ELSE 0 END) - 
SUM(CASE WHEN c.fiscal_year = 2023 THEN sm.electric_vehicles_sold ELSE 0 END)) * 
CASE WHEN sm.vehicle_category = '2-Wheelers' THEN 85000 ELSE 1500000 END) / 
NULLIF(SUM(CASE WHEN c.fiscal_year = 2023 THEN sm.electric_vehicles_sold ELSE 0 END) * 
CASE WHEN sm.vehicle_category = '2-Wheelers' THEN 85000 ELSE 1500000 END, 0) * 100 
AS revenue_growth_23_24
FROM sales_by_makers AS sm
JOIN calendar AS c 
ON sm.`date` = c.`date`
WHERE c.fiscal_year IN (2022, 2023, 2024)
GROUP BY vehicle_category;

-- Q11) Identify which states are leading in EV adoption compared to total vehicle sales.

SELECT state, SUM(electric_vehicles_sold) AS ev_sales, SUM(total_vehicles_sold) AS total_sales,
(SUM(electric_vehicles_sold) / SUM(total_vehicles_sold)) * 100 AS ev_penetration_rate
FROM sales_by_state
GROUP BY state
ORDER BY ev_penetration_rate DESC
LIMIT 10;

-- Q12) Analyze the yearly growth rate in EV sales across India.

SELECT c.fiscal_year, SUM(s.electric_vehicles_sold) AS total_ev_sales,
LAG(SUM(s.electric_vehicles_sold)) OVER (ORDER BY c.fiscal_year) AS previous_year_sales,
((SUM(s.electric_vehicles_sold) - LAG(SUM(s.electric_vehicles_sold)) OVER (ORDER BY c.fiscal_year)) / 
NULLIF(LAG(SUM(s.electric_vehicles_sold)) OVER (ORDER BY c.fiscal_year), 0)) * 100 AS yoy_growth
FROM sales_by_state s
JOIN calendar c ON s.`date` = c.`date` 
GROUP BY c.fiscal_year;

-- Q13) How many customers switched from petrol or diesel vehicles to EVs.

SELECT c.fiscal_year,
SUM(GREATEST(CAST(s.total_vehicles_sold AS SIGNED) - CAST(s.electric_vehicles_sold AS SIGNED), 0)) AS total_ice_sales,
SUM(s.electric_vehicles_sold) AS total_ev_sales,
(SUM(s.electric_vehicles_sold) / NULLIF(SUM(s.total_vehicles_sold), 0)) * 100 AS switch_percentage
FROM sales_by_state s
JOIN calendar c ON s.`date` = c.`date`
GROUP BY c.fiscal_year
ORDER BY c.fiscal_year;

-- Q14) Analyze 2 Wheeelers VS 4 Wheeelers' EV sales growth and their revenue impact.

SELECT vehicle_category, SUM(electric_vehicles_sold) AS total_ev_sold,
CASE WHEN vehicle_category = '2-Wheelers' THEN SUM(electric_vehicles_sold) * 85000
WHEN vehicle_category = '4-Wheelers' THEN SUM(electric_vehicles_sold) * 1500000
END AS total_revenue
FROM sales_by_makers
GROUP BY vehicle_category;


