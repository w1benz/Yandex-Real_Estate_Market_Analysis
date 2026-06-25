-- Outlier filtering example.
-- Defines anomalous values (outliers) using percentile thresholds on
-- total_area, rooms, balcony and ceiling_height, then returns only the
-- listing IDs that fall within normal bounds. This filtering step is
-- reused as a CTE in all three analytical queries below.
-- Roughly 19% of records are filtered out as outliers.
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
        AND rooms < (SELECT rooms_limit FROM limits)
        AND balcony < (SELECT balcony_limit FROM limits)
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
)
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);
