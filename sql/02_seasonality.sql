-- Task 2: Seasonality of Listings
-- Answers:
-- 1. In which months is listing publication/removal activity highest?
-- 2. Do periods of high publication coincide with periods of high
--    removal (i.e. sales)?
-- 3. How do seasonal fluctuations affect average price per sqm and
--    average apartment area?

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
flats_anomaly_free AS (
    SELECT *
    FROM real_estate.flats
    WHERE id IN (SELECT * FROM filtered_id)
),
date_month AS (
    SELECT
        a.id, total_area, last_price,
        TO_CHAR(DATE_TRUNC('month', first_day_exposition), 'Month') AS month_name,
        EXTRACT(MONTH FROM DATE_TRUNC('month', first_day_exposition)) AS month_number,
        (DATE_TRUNC('month', first_day_exposition) + INTERVAL '1 day' * days_exposition)::date AS end_date
    FROM real_estate.advertisement AS a
    INNER JOIN flats_anomaly_free AS f ON a.id = f.id
    WHERE type_id = 'F8EM' AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
),
open_month AS (
    SELECT month_number,
        ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS open_avg_price,
        ROUND(AVG(total_area::NUMERIC), 2) AS open_avg_floor_area
    FROM date_month
    GROUP BY month_number
),
close_month AS (
    SELECT
        EXTRACT(MONTH FROM end_date) AS month_number,
        ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS close_avg_price,
        ROUND(AVG(total_area::numeric), 2) AS close_avg_floor_area
    FROM date_month
    WHERE end_date IS NOT NULL
    GROUP BY EXTRACT(MONTH FROM end_date)
),
count_first AS (
    SELECT
        month_number, month_name,
        COUNT(id) AS count_id_start
    FROM date_month
    GROUP BY month_number, month_name
    ORDER BY month_number
),
count_end AS (
    SELECT
        month_number, month_name,
        COUNT(id) AS count_id_end
    FROM date_month
    WHERE end_date IS NOT NULL
    GROUP BY month_number, month_name
    ORDER BY month_number
)
SELECT
    f.month_name AS month,
    f.count_id_start,
    e.count_id_end,
    o.open_avg_price,
    c.close_avg_price,
    o.open_avg_floor_area,
    c.close_avg_floor_area
FROM count_first AS f
FULL JOIN count_end AS e ON f.month_number = e.month_number
FULL JOIN open_month AS o ON f.month_number = o.month_number
FULL JOIN close_month AS c ON f.month_number = c.month_number
ORDER BY f.month_number;
