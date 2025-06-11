/* 
 * Author: Vladislav Wiesner
 * Date: 09.12.2024
*/

-- Example of filtering data from anomalous values
-- Define anomalous values (outliers) based on percentile thresholds:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Find listing IDs that do not contain outliers:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
-- Return listings without outliers:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);




-- Task 1: Listing Activity Duration
-- The query should answer the following questions:
-- 1. Which real estate market segments in Saint Petersburg and cities of Leningrad Oblast 
--    have the shortest or longest listing activity durations?
-- 2. Which property characteristics, including area, average price per square meter,
--    number of rooms and balconies, and other parameters affect listing activity duration?
--    How do these dependencies vary across regions?
-- 3. Are there differences between real estate in Saint Petersburg and Leningrad Oblast based on the results?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Find listing IDs that do not contain outliers:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
), flats_anomaly_free AS (
    SELECT *
    FROM real_estate.flats
    WHERE id IN (SELECT * FROM filtered_id)
)
SELECT 
    -- Grouping by region
    CASE 
        WHEN city_id = '6X8I' THEN 'Saint Petersburg'
            ELSE 'Leningrad Oblast'
    END AS region,
    -- Grouping by days of listing activity
    CASE 
        WHEN days_exposition BETWEEN 1 AND 30 THEN 'Up to a month'
        WHEN days_exposition BETWEEN 31 AND 90 THEN 'Up to three months'
        WHEN days_exposition BETWEEN 91 AND 180 THEN 'ㅤUp to six months'
        WHEN days_exposition IS NULL THEN 'Active Listings'
            ELSE 'ㅤㅤMore than six months'
    END AS activity,
    COUNT(*) AS sales_amount,
    -- Calculating statistics by region
    ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS avg_price_one_meter,
    ROUND(AVG(total_area::numeric), 2) AS avg_floor_area,
    Percentile_Disc (0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
    Percentile_Disc (0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
    Percentile_Disc (0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors
FROM flats_anomaly_free AS F INNER JOIN real_estate.advertisement AS a
ON f.id = a.id
-- Adding filter by city and excluding open listings
WHERE type_id = 'F8EM'
GROUP BY region, activity
ORDER BY region DESC;


-- Task 2: Seasonality of Listings
-- The query should answer the following questions:
-- 1. In which months is there the highest activity in publishing real estate listings?
--    And in which months is there the most removal of listings? This shows buyer activity dynamics.
-- 2. Do periods of high listing publication coincide with periods of increased property sales 
--    (by month of listing removal)?
-- 3. How do seasonal fluctuations affect the average price per square meter and average apartment area?
--    What can be said about the dependency of these parameters on the month?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Find listing IDs that do not contain outliers:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
), flats_anomaly_free AS (
    SELECT *
    FROM real_estate.flats
    WHERE id IN (SELECT * FROM filtered_id)
), date_month AS (
    SELECT 
        a.id, total_area, last_price,
        -- Assign month name instead of date
        TO_CHAR(DATE_TRUNC('month', first_day_exposition), 'Month') AS month_name,
        -- Group by month regardless of year
        EXTRACT(MONTH FROM DATE_TRUNC('month', first_day_exposition)) AS month_number,
        (DATE_TRUNC('month', first_day_exposition) + INTERVAL '1 day' * days_exposition)::date AS end_date
    FROM real_estate.advertisement AS a INNER JOIN flats_anomaly_free AS f
    ON a.id = f.id
    WHERE type_id = 'F8EM' AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
), open_month AS (
    SELECT month_number,
        ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS open_avg_price,
        ROUND(AVG(total_area::NUMERIC), 2) AS open_avg_floor_area
    FROM date_month
    GROUP BY month_number
), close_month AS (
    SELECT 
        EXTRACT(MONTH FROM end_date) AS month_number,
        ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS close_avg_price,
        ROUND(AVG(total_area::numeric), 2) AS close_avg_floor_area
    FROM date_month
    WHERE end_date IS NOT NULL
    GROUP BY EXTRACT(MONTH FROM end_date)
), count_first AS (
    SELECT 
        month_number, month_name,
        -- Count number of new property listings
        COUNT(id) AS count_id_start
    FROM date_month 
    GROUP BY month_number, month_name
    ORDER BY month_number
), count_end AS (
    SELECT 
        month_number, month_name,
        COUNT(id) AS count_id_end
    FROM date_month
    -- Exclude null values for dates still being sold
    WHERE end_date IS NOT NULL
    GROUP BY month_number, month_name
    ORDER BY month_number
)
SELECT 
    f.month_name AS Month, 
    f.count_id_start,
    e.count_id_end, 
    o.open_avg_price,
    c.close_avg_price,
    o.open_avg_floor_area,
    c.close_avg_floor_area
FROM count_first AS f FULL JOIN count_end AS e
ON f.month_number = e.month_number
FULL JOIN open_month AS o ON f.month_number = o.month_number
FULL JOIN close_month AS c ON f.month_number = c.month_number
ORDER BY f.month_number



-- Task 3: Analysis of the Real Estate Market in Leningrad Oblast
-- The query should answer the following questions:
-- 1. In which settlements of Leningrad Oblast are real estate listings published most actively?
-- 2. In which settlements of Leningrad Oblast is the share of removed listings the highest? 
--    This may indicate a high rate of property sales.
-- 3. What is the average price per square meter and average area of sold apartments in different settlements?
--    Is there variation in these metrics across locations?
-- 4. Among the selected settlements, which ones stand out in terms of listing duration?
--    That is, where is property sold faster, and where is it sold slower?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Find listing IDs that do not contain outliers:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ), flats_anomaly_free AS (
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id)
)
-- Calculate average statistics by settlement in Leningrad Oblast
SELECT city,
    ROUND(AVG(days_exposition::numeric), 2) AS publication_duration,
    COUNT(*) AS count_sale,
    -- Share of removed listings in percentage (just wondering if this approach is valid — for me it's more convenient to present results in percentages, and it's also easier for the client to understand)
    ROUND(COUNT(CASE WHEN days_exposition IS NOT NULL THEN 1 END)::NUMERIC / COUNT(*) * 100, 2) AS advertisement_share,
    -- Average price per square meter
    ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS avg_price_one_meter,
    ROUND(AVG(total_area::numeric), 2) AS avg_selling_area
FROM flats_anomaly_free AS f LEFT JOIN real_estate.city AS c
ON f.city_id = c.city_id
LEFT JOIN real_estate.advertisement AS a 
ON f.id = a.id
-- Exclude city with ID '6X8I' - 'Saint Petersburg'
WHERE f.city_id != '6X8I'
GROUP BY city
-- Select only cities with more than 50 listings.
-- The threshold of '50' helps focus on settlements with sufficient data to identify trends.
-- A threshold of 50 provides a balance between coverage and stability across settlements, making the analysis more useful.
HAVING COUNT(a.id) > 50
ORDER BY publication_duration


