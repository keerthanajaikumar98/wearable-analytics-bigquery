-- =============================================================================
-- STRESS RESPONSE PATTERNS
-- Purpose: Analyze which stressors trigger strongest physiological responses
-- Business Value: Optimize stress test protocols, personalize interventions
-- =============================================================================

CREATE OR REPLACE TABLE `wearable_analytics.analytics_stress_patterns` AS
WITH stress_by_time AS (
  -- Analyze stress progression over time
  SELECT 
    subject_id,
    session_id,
    time_window,
    stress_index,
    stress_state,
    eda_change_pct,
    hr_change_pct,
    temp_delta_celsius,
    
    -- Time from session start (proxy for different stress tasks)
    TIMESTAMP_DIFF(time_window, 
                   (SELECT MIN(time_window) 
                    FROM `wearable_analytics.derived_stress_indicators` si2 
                    WHERE si2.session_id = si.session_id), 
                   MINUTE) as minutes_into_session,
    
    -- Categorize into early/mid/late session
    CASE 
      WHEN TIMESTAMP_DIFF(time_window, 
                          (SELECT MIN(time_window) 
                           FROM `wearable_analytics.derived_stress_indicators` si2 
                           WHERE si2.session_id = si.session_id), 
                          MINUTE) < 10 THEN 'EARLY'
      WHEN TIMESTAMP_DIFF(time_window, 
                          (SELECT MIN(time_window) 
                           FROM `wearable_analytics.derived_stress_indicators` si2 
                           WHERE si2.session_id = si.session_id), 
                          MINUTE) < 20 THEN 'MIDDLE'
      ELSE 'LATE'
    END as session_phase
    
  FROM `wearable_analytics.derived_stress_indicators` si
  WHERE session_type = 'STRESS'
),
peak_stress_per_subject AS (
  -- Calculate peak stress index per subject (separate CTE)
  SELECT 
    subject_id,
    MAX(stress_index) as peak_stress_index
  FROM stress_by_time
  GROUP BY subject_id
),
subject_stress_profile AS (
  -- Create stress profile per subject
  SELECT 
    sbt.subject_id,
    
    -- Overall stress metrics
    AVG(sbt.stress_index) as avg_stress_index,
    MAX(sbt.stress_index) as max_stress_index,
    STDDEV(sbt.stress_index) as stress_variability,
    
    -- Peak responses
    MAX(sbt.eda_change_pct) as max_eda_spike,
    MAX(sbt.hr_change_pct) as max_hr_spike,
    MAX(sbt.temp_delta_celsius) as max_temp_rise,
    
    -- Time to peak stress (using the separate CTE)
    MIN(CASE 
      WHEN sbt.stress_index = psp.peak_stress_index 
      THEN sbt.minutes_into_session 
    END) as time_to_peak_stress_min,
    
    -- Stress reactivity (how quickly they respond)
    MAX(CASE WHEN sbt.minutes_into_session <= 5 THEN sbt.stress_index END) as early_stress_response,
    
    -- Recovery ability (stress decline in late session)
    AVG(CASE WHEN sbt.session_phase = 'LATE' THEN sbt.stress_index END) as late_session_stress,
    
    -- Percentage of time stressed
    100.0 * COUNTIF(sbt.stress_state = 'STRESSED') / COUNT(*) as pct_time_stressed
    
  FROM stress_by_time sbt
  JOIN peak_stress_per_subject psp ON sbt.subject_id = psp.subject_id
  GROUP BY sbt.subject_id
)
-- THIS IS THE IMPORTANT PART - explicitly list all columns
SELECT 
  ssp.subject_id,
  ssp.avg_stress_index,
  ssp.max_stress_index,
  ssp.stress_variability,
  ssp.max_eda_spike,
  ssp.max_hr_spike,
  ssp.max_temp_rise,
  ssp.time_to_peak_stress_min,
  ssp.early_stress_response,
  ssp.late_session_stress,
  ssp.pct_time_stressed,
  s.age,
  s.gender,
  s.cohort,
  
  -- Classify stress response type
  CASE 
    WHEN ssp.early_stress_response > 0.5 THEN 'FAST_REACTOR'
    WHEN ssp.max_stress_index > 0.7 THEN 'HIGH_REACTOR'
    WHEN ssp.stress_variability > 0.3 THEN 'VARIABLE_REACTOR'
    WHEN ssp.late_session_stress < ssp.avg_stress_index * 0.7 THEN 'GOOD_RECOVERER'
    ELSE 'MODERATE_REACTOR'
  END as stress_profile_type
  
FROM subject_stress_profile ssp
JOIN `wearable_analytics.dim_subjects` s 
  ON ssp.subject_id = s.subject_id
ORDER BY ssp.max_stress_index DESC;

-- Summary by stress profile type
SELECT 
  stress_profile_type,
  COUNT(*) as subject_count,
  ROUND(AVG(avg_stress_index), 3) as avg_stress,
  ROUND(AVG(max_eda_spike) * 100, 1) as avg_max_eda_increase_pct,
  ROUND(AVG(pct_time_stressed), 1) as avg_pct_time_stressed,
  ROUND(AVG(time_to_peak_stress_min), 1) as avg_time_to_peak_min
FROM `wearable_analytics.analytics_stress_patterns`
GROUP BY stress_profile_type
ORDER BY avg_stress DESC;