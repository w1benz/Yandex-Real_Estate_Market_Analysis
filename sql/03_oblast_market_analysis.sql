-- Task 3: Leningrad Oblast Real Estate Market Analysis
-- Answers:
-- 1. Which Leningrad Oblast settlements have the most active listing
--    publication?
-- 2. Which settlements have the highest share of removed listings
--    (a proxy for sales activity)?
-- 3. What is the average price per sqm and average area in different
--    settlements?
-- 4. Which settlements stand out in terms of listing duration (faster
--    vs. slower-selling markets)?

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
    city,
    ROUND(AVG(days_exposition::numeric), 2) AS publication_duration,
    COUNT(*) AS count_sale,
    -- Share of removed (likely sold) listings, as a percentage
    ROUND(COUNT(CASE WHEN days_exposition IS NOT NULL THEN 1 END)::NUMERIC / COUNT(*) * 100, 2) AS advertisement_share,
    ROUND(AVG(last_price::NUMERIC / total_area::NUMERIC), 2) AS avg_price_one_meter,
    ROUND(AVG(total_area::numeric), 2) AS avg_selling_area
FROM flats_anomaly_free AS f
LEFT JOIN real_estate.city AS c ON f.city_id = c.city_id
LEFT JOIN real_estate.advertisement AS a ON f.id = a.id
-- Exclude Saint Petersburg (city_id = '6X8I') — Oblast settlements only
WHERE f.city_id != '6X8I'
GROUP BY city
-- Only settlements with enough listings for a stable estimate
HAVING COUNT(a.id) > 50
ORDER BY publication_duration;
