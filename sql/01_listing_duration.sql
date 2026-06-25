-- Task 1: Listing Activity Duration
-- Answers:
-- 1. Which real estate market segments in Saint Petersburg and the
--    Leningrad Oblast have the shortest or longest listing activity
--    durations?
-- 2. Which property characteristics (area, price per sqm, rooms,
--    balconies, etc.) affect listing duration, and how does this differ
--    by region?
-- 3. Are there differences between Saint Petersburg and Leningrad Oblast
--    real estate based on these results?

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
)
SELECT
    -- Group by region
    CASE
        WHEN city_id = '6X8I' THEN 'Saint Petersburg'
        ELSE 'Leningrad Oblast'
    END AS region,
    -- Group by listing activity duration
    CASE
        WHEN days_exposition BETWEEN 1 AND 30 THEN 'Up to a month'
        WHEN days_exposition BETWEEN 31 AND 90 THEN 'Up to three months'
        WHEN days_exposition BETWEEN 91 AND 180 THEN 'Up to six months'
        WHEN days_exposition IS NULL THEN 'Active listings'
        ELSE 'More than six months'
    END AS activity,
    COUNT(*) AS sales_amount,
    ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS avg_price_one_meter,
    ROUND(AVG(total_area::numeric), 2) AS avg_floor_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors
FROM flats_anomaly_free AS f
INNER JOIN real_estate.advertisement AS a ON f.id = a.id
-- Filter to apartment-sale listings and exclude still-active ones from segmentation logic
WHERE type_id = 'F8EM'
GROUP BY region, activity
ORDER BY region DESC;
