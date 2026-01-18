-- =============================================================================
-- FACT TABLES
-- Purpose: Store measurement data (time-series and aggregated metrics)
-- =============================================================================

-- fact_physiological_measurements: Raw time-series data (LARGE TABLE)
CREATE TABLE IF NOT EXISTS `wearable_analytics.fact_physiological_measurements` (
  measurement_id STRING NOT NULL,
  subject_id STRING NOT NULL,
  session_id STRING NOT NULL,
  measurement_timestamp TIMESTAMP NOT NULL,
  signal_type STRING NOT NULL,  -- BVP, EDA, TEMP, ACC_X, ACC_Y, ACC_Z, HR, IBI
  value FLOAT64,
  session_type STRING,  -- Denormalized for faster queries
  data_quality_flag STRING  -- VALID, ARTIFACT, MISSING
)
PARTITION BY DATE(measurement_timestamp)
CLUSTER BY subject_id, session_type, signal_type
OPTIONS(
  description="All raw physiological measurements from wearable devices",
  partition_expiration_days=NULL,
  require_partition_filter=true
);

-- fact_session_metrics: Aggregated metrics per session stage
CREATE TABLE IF NOT EXISTS `wearable_analytics.fact_session_metrics` (
  metric_id STRING NOT NULL,
  subject_id STRING NOT NULL,
  session_id STRING NOT NULL,
  session_type STRING,
  stage_name STRING,
  stage_start_time TIMESTAMP,
  stage_end_time TIMESTAMP,
  duration_seconds INT64,
  
  -- Heart Rate Metrics
  avg_hr FLOAT64,
  max_hr FLOAT64,
  min_hr FLOAT64,
  hr_std FLOAT64,
  
  -- HRV Metrics (Heart Rate Variability)
  hrv_sdnn FLOAT64,
  hrv_rmssd FLOAT64,
  hrv_pnn50 FLOAT64,
  
  -- EDA Metrics (Electrodermal Activity)
  avg_eda FLOAT64,
  max_eda FLOAT64,
  eda_peaks_count INT64,
  eda_auc FLOAT64,
  
  -- Temperature
  avg_temp FLOAT64,
  temp_change_from_baseline FLOAT64,
  
  -- Activity Level
  total_movement_magnitude FLOAT64,
  avg_acceleration FLOAT64,
  
  -- Derived Scores
  stress_index FLOAT64,
  exertion_level STRING,
  
  -- Self-reported (stress sessions only)
  self_reported_stress INT64
)
PARTITION BY DATE(stage_start_time)
CLUSTER BY subject_id, session_type
OPTIONS(
  description="Aggregated metrics per session stage for analysis and ML",
  require_partition_filter=false
);