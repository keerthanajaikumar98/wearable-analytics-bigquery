-- =============================================================================
-- HEART RATE VARIABILITY (HRV) METRICS
-- Purpose: Calculate time-domain HRV features for stress/recovery detection
-- =============================================================================

-- Create HRV metrics table
CREATE OR REPLACE TABLE `wearable_analytics.derived_hrv_metrics` AS
WITH ibi_data AS (
  -- Get inter-beat intervals with previous value for calculations
  SELECT 
    subject_id,
    session_id,
    session_type,
    measurement_timestamp,
    value as ibi_ms,
    LAG(value) OVER (
      PARTITION BY subject_id, session_id 
      ORDER BY measurement_timestamp
    ) as prev_ibi
  FROM `wearable_analytics.fact_physiological_measurements`
  WHERE signal_type = 'IBI'
    AND value BETWEEN 300 AND 2000  -- Filter physiologically plausible values (30-200 bpm)
    AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 365 DAY)  -- Partition filter
),
hrv_windows AS (
  -- Calculate HRV metrics in 1-minute windows
  SELECT 
    subject_id,
    session_id,
    session_type,
    TIMESTAMP_TRUNC(measurement_timestamp, MINUTE) as window_start,
    
    -- Number of beats in window
    COUNT(*) as beat_count,
    
    -- SDNN: Standard deviation of NN intervals (overall HRV)
    STDDEV(ibi_ms) as sdnn,
    
    -- RMSSD: Root mean square of successive differences (parasympathetic activity)
    SQRT(AVG(POWER(ibi_ms - prev_ibi, 2))) as rmssd,
    
    -- pNN50: Percentage of successive intervals differing by >50ms
    100.0 * COUNTIF(ABS(ibi_ms - prev_ibi) > 50) / NULLIF(COUNT(*), 0) as pnn50,
    
    -- Mean IBI and derived HR
    AVG(ibi_ms) as mean_ibi_ms,
    60000.0 / AVG(ibi_ms) as avg_hr_bpm,
    
    -- Additional metrics
    MIN(ibi_ms) as min_ibi_ms,
    MAX(ibi_ms) as max_ibi_ms
    
  FROM ibi_data
  WHERE prev_ibi IS NOT NULL  -- Skip first beat (no previous interval)
  GROUP BY subject_id, session_id, session_type, window_start
  HAVING COUNT(*) >= 5  -- Require at least 5 beats for reliable HRV
)
SELECT 
  *,
  -- HRV stress indicator (lower HRV = higher stress)
  CASE 
    WHEN sdnn < 20 THEN 'VERY_LOW_HRV'
    WHEN sdnn < 50 THEN 'LOW_HRV'
    WHEN sdnn < 100 THEN 'NORMAL_HRV'
    ELSE 'HIGH_HRV'
  END as hrv_category,
  
  -- Recovery indicator (higher RMSSD = better recovery)
  CASE 
    WHEN rmssd < 15 THEN 'POOR_RECOVERY'
    WHEN rmssd < 30 THEN 'MODERATE_RECOVERY'
    ELSE 'GOOD_RECOVERY'
  END as recovery_status
  
FROM hrv_windows
ORDER BY subject_id, window_start;