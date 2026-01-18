-- =============================================================================
-- DIMENSION TABLES
-- Purpose: Store reference data and metadata
-- =============================================================================

-- dim_subjects: Subject demographics
CREATE TABLE IF NOT EXISTS `wearable_analytics.dim_subjects` (
  subject_id STRING NOT NULL,
  cohort STRING,  -- 'V1' or 'V2' (protocol version)
  age INT64,
  weight_kg FLOAT64,
  height_cm FLOAT64,
  bmi FLOAT64,
  gender STRING,
  enrollment_date DATE
)
PARTITION BY DATE_TRUNC(enrollment_date, MONTH)
OPTIONS(
  description="Subject demographics and metadata",
  labels=[("env", "prod"), ("table_type", "dimension")]
);

-- dim_sessions: Session metadata
CREATE TABLE IF NOT EXISTS `wearable_analytics.dim_sessions` (
  session_id STRING NOT NULL,
  subject_id STRING NOT NULL,
  session_type STRING NOT NULL,  -- STRESS, AEROBIC, ANAEROBIC
  protocol_version STRING,  -- V1 or V2
  session_date DATE,
  session_start_time TIMESTAMP,
  session_end_time TIMESTAMP,
  duration_minutes FLOAT64,
  data_quality_notes STRING
)
PARTITION BY session_date
CLUSTER BY subject_id, session_type
OPTIONS(
  description="Metadata for each recording session",
  require_partition_filter=false
);

-- dim_protocol_stages: Define protocol stages
CREATE TABLE IF NOT EXISTS `wearable_analytics.dim_protocol_stages` (
  stage_id STRING NOT NULL,
  session_type STRING NOT NULL,
  protocol_version STRING,
  stage_name STRING NOT NULL,
  stage_order INT64,
  expected_duration_seconds INT64,
  stage_description STRING
)
OPTIONS(
  description="Definitions of protocol stages (baseline, test, rest, etc.)"
);

-- dim_signal_types: Signal metadata
CREATE TABLE IF NOT EXISTS `wearable_analytics.dim_signal_types` (
  signal_type STRING NOT NULL,
  signal_name STRING,
  unit STRING,
  sample_rate_hz FLOAT64,
  normal_range_min FLOAT64,
  normal_range_max FLOAT64,
  description STRING
)
OPTIONS(
  description="Metadata about each physiological signal type"
);

-- Verify tables were created
SELECT 
  table_id AS table_name,
  type AS table_type,
  ROUND(size_bytes / 1024 / 1024, 2) AS size_mb
FROM `wearable_analytics.__TABLES__`
ORDER BY table_name;
