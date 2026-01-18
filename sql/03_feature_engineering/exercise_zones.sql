-- =============================================================================
-- EXERCISE ZONE CLASSIFICATION
-- Purpose: Classify exercise intensity zones (similar to Myzone's MEPs system)
-- =============================================================================

CREATE OR REPLACE TABLE `wearable_analytics.derived_exercise_zones` AS
WITH max_hr_estimates AS (
  -- Estimate maximum heart rate for each subject
  SELECT 
    s.subject_id,
    220 - s.age as estimated_max_hr,  -- Simple age-based formula
    s.age
  FROM `wearable_analytics.dim_subjects` s
),
hr_with_zones AS (
  SELECT 
    pm.subject_id,
    pm.session_id,
    pm.session_type,
    pm.measurement_timestamp,
    pm.value as current_hr,
    
    mh.estimated_max_hr,
    mh.age,
    
    -- HR as percentage of max
    100.0 * pm.value / mh.estimated_max_hr as hr_percentage,
    
    -- Training zone classification (based on % of max HR)
    CASE 
      WHEN pm.value / mh.estimated_max_hr < 0.50 THEN 'ZONE_0_RECOVERY'
      WHEN pm.value / mh.estimated_max_hr < 0.60 THEN 'ZONE_1_EASY'
      WHEN pm.value / mh.estimated_max_hr < 0.70 THEN 'ZONE_2_MODERATE'
      WHEN pm.value / mh.estimated_max_hr < 0.80 THEN 'ZONE_3_HARD'
      WHEN pm.value / mh.estimated_max_hr < 0.90 THEN 'ZONE_4_VERY_HARD'
      ELSE 'ZONE_5_MAXIMUM'
    END as training_zone,
    
    -- Effort points per minute (Myzone-style MEPs)
    CASE 
      WHEN pm.value / mh.estimated_max_hr < 0.50 THEN 1
      WHEN pm.value / mh.estimated_max_hr < 0.60 THEN 2
      WHEN pm.value / mh.estimated_max_hr < 0.70 THEN 3
      WHEN pm.value / mh.estimated_max_hr < 0.80 THEN 4
      WHEN pm.value / mh.estimated_max_hr < 0.90 THEN 5
      ELSE 6
    END as effort_points_per_minute
    
  FROM `wearable_analytics.fact_physiological_measurements` pm
  JOIN max_hr_estimates mh 
    ON pm.subject_id = mh.subject_id
  WHERE pm.signal_type = 'HR'
    AND pm.session_type IN ('AEROBIC', 'ANAEROBIC')  -- Only exercise sessions
    AND pm.value BETWEEN 40 AND 220  -- Physiologically plausible
    AND pm.measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 365 DAY)  -- Partition filter
)
SELECT 
  *,
  
  -- Aerobic vs Anaerobic classification
  CASE 
    WHEN hr_percentage < 70 THEN 'AEROBIC_LOW'
    WHEN hr_percentage < 85 THEN 'AEROBIC_MODERATE'
    WHEN hr_percentage < 90 THEN 'AEROBIC_HIGH'
    ELSE 'ANAEROBIC'
  END as metabolic_zone
  
FROM hr_with_zones
ORDER BY subject_id, measurement_timestamp;

-- Session summary: Time in each zone
CREATE OR REPLACE TABLE `wearable_analytics.session_zone_summary` AS
SELECT 
  subject_id,
  session_id,
  session_type,
  training_zone,
  
  COUNT(*) as seconds_in_zone,
  ROUND(COUNT(*) / 60.0, 2) as minutes_in_zone,
  SUM(effort_points_per_minute / 60.0) as total_effort_points,
  
  AVG(current_hr) as avg_hr_in_zone,
  AVG(hr_percentage) as avg_hr_pct_in_zone
  
FROM `wearable_analytics.derived_exercise_zones`
GROUP BY subject_id, session_id, session_type, training_zone
ORDER BY subject_id, session_id, training_zone;