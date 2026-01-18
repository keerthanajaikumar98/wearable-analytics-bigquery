-- =============================================================================
-- USER SEGMENTATION
-- Purpose: Segment users by fitness level and needs
-- Business Value: Personalized feature recommendations, targeted marketing
-- =============================================================================

CREATE OR REPLACE TABLE `wearable_analytics.analytics_user_segments` AS
WITH exercise_profile AS (
  -- Aggregate exercise characteristics
  SELECT 
    subject_id,
    
    -- Aerobic capacity indicators
    AVG(CASE WHEN session_type = 'AEROBIC' THEN avg_hr_in_zone END) as avg_aerobic_hr,
    MAX(CASE WHEN session_type = 'AEROBIC' THEN avg_hr_pct_in_zone END) as max_aerobic_intensity,
    SUM(CASE WHEN session_type = 'AEROBIC' THEN minutes_in_zone END) as total_aerobic_minutes,
    
    -- Anaerobic/power indicators
    AVG(CASE WHEN session_type = 'ANAEROBIC' THEN avg_hr_in_zone END) as avg_anaerobic_hr,
    MAX(CASE WHEN session_type = 'ANAEROBIC' THEN avg_hr_pct_in_zone END) as max_anaerobic_intensity,
    SUM(CASE WHEN session_type = 'ANAEROBIC' THEN minutes_in_zone END) as total_anaerobic_minutes,
    
    -- Training load
    SUM(total_effort_points) as total_meps
    
  FROM `wearable_analytics.session_zone_summary`
  GROUP BY subject_id
),
recovery_profile AS (
  -- HRV and recovery metrics
  SELECT 
    subject_id,
    AVG(rmssd) as avg_rmssd,
    AVG(sdnn) as avg_sdnn,
    
    -- Recovery classification distribution
    COUNTIF(recovery_status = 'GOOD_RECOVERY') / COUNT(*) as pct_good_recovery,
    COUNTIF(hrv_category IN ('VERY_LOW_HRV', 'LOW_HRV')) / COUNT(*) as pct_low_hrv
    
  FROM `wearable_analytics.derived_hrv_metrics`
  GROUP BY subject_id
),
stress_profile AS (
  -- Stress management needs
  SELECT 
    subject_id,
    AVG(stress_index) as avg_stress_level,
    COUNTIF(stress_state = 'STRESSED') / COUNT(*) as pct_time_stressed
    
  FROM `wearable_analytics.derived_stress_indicators`
  WHERE session_type = 'STRESS'
  GROUP BY subject_id
)
SELECT 
  s.subject_id,
  s.age,
  s.gender,
  s.bmi,
  s.cohort,
  
  -- Exercise metrics
  COALESCE(ep.avg_aerobic_hr, 0) as avg_aerobic_hr,
  COALESCE(ep.total_aerobic_minutes, 0) as total_aerobic_minutes,
  COALESCE(ep.total_meps, 0) as total_meps,
  
  -- Recovery metrics
  COALESCE(rp.avg_rmssd, 0) as avg_rmssd,
  COALESCE(rp.pct_good_recovery, 0) as pct_good_recovery,
  
  -- Stress metrics
  COALESCE(sp.avg_stress_level, 0) as avg_stress_level,
  COALESCE(sp.pct_time_stressed, 0) as pct_time_stressed,
  
  -- Segment classification
  CASE 
    -- High performers
    WHEN ep.max_aerobic_intensity > 85 AND rp.avg_rmssd > 30 THEN 'ATHLETE'
    
    -- Needs recovery focus
    WHEN rp.pct_low_hrv > 0.5 OR rp.avg_rmssd < 20 THEN 'RECOVERY_FOCUSED'
    
    -- Needs stress management
    WHEN sp.avg_stress_level > 0.5 OR sp.pct_time_stressed > 0.6 THEN 'STRESS_MANAGEMENT'
    
    -- Building fitness
    WHEN ep.avg_aerobic_hr < 140 AND ep.total_meps < 100 THEN 'BEGINNER'
    
    -- Active but could optimize
    WHEN ep.total_aerobic_minutes > 20 THEN 'ACTIVE'
    
    ELSE 'CASUAL'
  END as user_segment,
  
  -- Feature recommendations
  ARRAY_TO_STRING([
    IF(sp.avg_stress_level > 0.4, 'Stress Tracking', NULL),
    IF(rp.avg_rmssd < 25, 'Recovery Coach', NULL),
    IF(ep.total_meps > 200, 'Performance Analytics', NULL),
    IF(ep.avg_aerobic_hr < 120, 'Beginner Programs', NULL),
    IF(rp.pct_low_hrv > 0.3, 'HRV Training', NULL)
  ], ', ') as recommended_features
  
FROM `wearable_analytics.dim_subjects` s
LEFT JOIN exercise_profile ep ON s.subject_id = ep.subject_id
LEFT JOIN recovery_profile rp ON s.subject_id = rp.subject_id
LEFT JOIN stress_profile sp ON s.subject_id = sp.subject_id
ORDER BY user_segment, subject_id;

-- Segment distribution
SELECT 
  user_segment,
  COUNT(*) as users,
  ROUND(AVG(age), 1) as avg_age,
  ROUND(AVG(total_meps), 1) as avg_meps,
  ROUND(AVG(avg_stress_level), 2) as avg_stress,
  ROUND(AVG(pct_good_recovery) * 100, 1) as pct_good_recovery
FROM `wearable_analytics.analytics_user_segments`
GROUP BY user_segment
ORDER BY users DESC;