-- =============================================================================
-- BIGQUERY COST ANALYSIS
-- Purpose: Understand current costs and identify optimization opportunities
-- =============================================================================

SELECT 
  table_id AS table_name,
  row_count,
  ROUND(size_bytes / POWER(1024, 3), 2) AS size_gb,

  -- Storage cost ($0.02 per GB per month for active storage)
  ROUND((size_bytes / POWER(1024, 3)) * 0.02, 4) AS monthly_storage_cost_usd,

  -- Estimated query cost for full table scan ($6.25 per TB)
  ROUND((size_bytes / POWER(1024, 4)) * 6.25, 4) AS full_scan_cost_usd,

  -- Table type
  CASE 
    WHEN table_id LIKE 'dim_%' THEN 'Dimension'
    WHEN table_id LIKE 'fact_%' THEN 'Fact'
    WHEN table_id LIKE 'derived_%' THEN 'Derived'
    WHEN table_id LIKE 'analytics_%' THEN 'Analytics'
    ELSE 'Other'
  END AS table_category

FROM `wearable_analytics.__TABLES__`
WHERE row_count > 0
ORDER BY size_bytes DESC;
