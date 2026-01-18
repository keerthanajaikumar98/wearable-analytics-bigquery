# Complete Setup Guide

This guide walks through setting up the entire project from scratch.

## Prerequisites

- Google Cloud account (free tier)
- Python 3.8+
- Git
- Terminal access

## Step 1: Clone Repository
```bash
git clone https://github.com/YOUR_USERNAME/wearable-analytics-bigquery.git
cd wearable-analytics-bigquery
```

## Step 2: Download Dataset
```bash
# Download from PhysioNet
wget https://physionet.org/files/wearable-exam-stress/1.0.1/wearable-exam-stress-1.0.1.zip

# Extract
unzip wearable-exam-stress-1.0.1.zip -d data/raw/

# Verify
ls data/raw/
# Should see: STRESS/, AEROBIC/, ANAEROBIC/, subject-info.csv
```

## Step 3: Google Cloud Setup
```bash
# Install Google Cloud SDK
# Mac: brew install --cask google-cloud-sdk
# Linux: curl https://sdk.cloud.google.com | bash
# Windows: Download from https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login
gcloud auth application-default login

# Create project
gcloud projects create wearable-analytics-project --name="Wearable Analytics"

# Set project
gcloud config set project wearable-analytics-project

# Enable BigQuery API
gcloud services enable bigquery.googleapis.com
```

## Step 4: Python Environment
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Step 5: BigQuery Setup
```bash
# Create dataset
bq mk --dataset --location=US wearable_analytics

# Create tables
bq query --use_legacy_sql=false < sql/01_setup/create_dimensions.sql
bq query --use_legacy_sql=false < sql/01_setup/create_facts.sql

# Load dimension data
python scripts/prepare_subjects.py
bq load --source_format=CSV --skip_leading_rows=1 --replace \
  wearable_analytics.dim_subjects \
  data/processed/subjects_prepared.csv \
  subject_id:STRING,cohort:STRING,age:INTEGER,weight_kg:FLOAT,height_cm:FLOAT,bmi:FLOAT,gender:STRING,enrollment_date:DATE

bq query --use_legacy_sql=false < sql/02_ingestion/insert_signal_types.sql
```

## Step 6: Load Physiological Data
```bash
# Load one subject (test)
python scripts/load_physiological_data.py --session-type STRESS --subject S01

# Load all STRESS sessions
python scripts/load_physiological_data.py --session-type STRESS --load-all

# Optional: Load exercise sessions
python scripts/load_physiological_data.py --session-type AEROBIC --load-all
python scripts/load_physiological_data.py --session-type ANAEROBIC --load-all
```

## Step 7: Run Feature Engineering
```bash
# Data quality monitoring
bq query --use_legacy_sql=false < sql/03_feature_engineering/data_quality_checks.sql

# HRV metrics
bq query --use_legacy_sql=false < sql/03_feature_engineering/hrv_metrics.sql

# Stress detection
bq query --use_legacy_sql=false < sql/03_feature_engineering/stress_indicators.sql

# Exercise zones (if you loaded AEROBIC/ANAEROBIC)
bq query --use_legacy_sql=false < sql/03_feature_engineering/exercise_zones.sql
```

## Step 8: Run Analytics
```bash
# Recovery analysis
bq query --use_legacy_sql=false < sql/04_analytics/recovery_analysis.sql

# Stress patterns
bq query --use_legacy_sql=false < sql/04_analytics/stress_response_patterns.sql

# User segmentation
bq query --use_legacy_sql=false < sql/04_analytics/user_segmentation.sql

# Cohort comparison
bq query --use_legacy_sql=false < sql/04_analytics/cohort_comparison.sql

# Session performance
bq query --use_legacy_sql=false < sql/04_analytics/session_performance.sql
```

## Step 9: Run Optimization Reports
```bash
# Cost analysis
bq query --use_legacy_sql=false < sql/05_optimization/cost_analysis.sql

# Optimization report
python scripts/optimize_bigquery.py

# Cost monitoring
python scripts/cost_monitor.py
```

## Step 10: Verify Everything
```bash
# Check all tables exist
bq ls wearable_analytics

# Check row counts
bq query --use_legacy_sql=false '
SELECT table_name, row_count 
FROM wearable_analytics.__TABLES__ 
ORDER BY table_name
'

# Run a test query
bq query --use_legacy_sql=false '
SELECT 
  session_type,
  COUNT(DISTINCT subject_id) as subjects,
  COUNT(*) as measurements
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY session_type
'
```

## Troubleshooting

### "Permission denied"
```bash
# Make sure you have BigQuery Admin role
gcloud projects add-iam-policy-binding wearable-analytics-project \
  --member="user:YOUR_EMAIL@gmail.com" \
  --role="roles/bigquery.admin"
```

### "Partition filter required"
All queries on `fact_physiological_measurements` must include:
```sql
WHERE measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 365 DAY)
```

### "Out of memory" when loading data
Reduce batch size in `load_physiological_data.py`:
```python
self.upload_to_bigquery(combined_df, batch_size=10000)  # Reduce from 50000
```

## Success Criteria

You should see:
- ✅ 15 tables in `wearable_analytics` dataset
- ✅ `fact_physiological_measurements` with 100K+ rows
- ✅ All derived tables populated
- ✅ Queries running in < 5 seconds
- ✅ Monthly cost: $0

## Next Steps

1. Explore the Jupyter notebooks
2. Run custom analytics queries
3. Create visualizations
4. Build ML models
5. Present to stakeholders!