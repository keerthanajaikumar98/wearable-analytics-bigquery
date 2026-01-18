# BigQuery Schema Design

## Design Philosophy
- **Star Schema**: Fact tables (measurements) + Dimension tables (subjects, sessions)
- **Partitioning**: By date to reduce query costs (95% reduction for date-filtered queries)
- **Clustering**: By subject_id and session_type for fast filtering
- **Normalization**: Separate dimensions to avoid data duplication

## Data Volume Estimates
- **fact_physiological_measurements**: ~50 million rows (~5 GB)
- **fact_session_metrics**: ~500 rows (< 1 MB)
- **dim_subjects**: 36 rows (< 1 KB)
- **dim_sessions**: ~97 rows (< 1 KB)

## Why This Design?

### Partitioning Strategy
```sql
PARTITION BY DATE(measurement_timestamp)
```
- Reduces data scanned by 95% for time-range queries
- BigQuery only reads relevant date partitions
- Example: Query for Jan 15 only scans that day's data

### Clustering Strategy  
```sql
CLUSTER BY subject_id, session_type, signal_type
```
- Groups related data together physically
- Improves query performance by 10-100x
- Reduces costs further when filtering on these columns

### Star Schema Benefits
- **Fast Aggregations**: Pre-joined dimensions
- **Easy Analysis**: Clear relationships
- **Scalable**: Can add dimensions without changing facts

## Table Descriptions

### dim_subjects
**Purpose**: Participant demographics and metadata
**Key**: subject_id
**Rows**: 36
**Partitioning**: By enrollment_date (monthly) - not critical for small table

### dim_sessions  
**Purpose**: Metadata about each recording session
**Key**: session_id
**Rows**: ~97 (36 stress + 30 aerobic + 31 anaerobic)
**Partitioning**: By session_date
**Clustering**: By subject_id, session_type

### dim_protocol_stages
**Purpose**: Define protocol stages (baseline, test, rest, etc.)
**Key**: stage_id
**Rows**: ~20
**Note**: Small lookup table, no partitioning needed

### dim_signal_types
**Purpose**: Metadata about physiological signals
**Key**: signal_type
**Rows**: 8 (BVP, EDA, TEMP, ACC_X, ACC_Y, ACC_Z, HR, IBI)
**Note**: Small lookup table

### fact_physiological_measurements (TIME-SERIES)
**Purpose**: All raw sensor readings
**Key**: measurement_id
**Rows**: ~50 million
**Size**: ~5 GB
**Partitioning**: By DATE(measurement_timestamp) - **CRITICAL**
**Clustering**: By subject_id, session_type, signal_type

**Challenge**: Different sensors have different sampling rates:
- BVP: 64 Hz (64 samples/second)
- EDA: 4 Hz
- TEMP: 4 Hz
- ACC: 32 Hz (3 axes)
- HR: 1 Hz
- IBI: Variable (depends on heart rate)

### fact_session_metrics (AGGREGATED)
**Purpose**: Pre-computed metrics per session/stage
**Key**: metric_id
**Rows**: ~500
**Size**: < 1 MB
**Partitioning**: By DATE(stage_start_time)
**Clustering**: By subject_id, session_type

**Why Pre-Aggregate?**
- Avoids expensive repeated calculations
- Dashboard queries run instantly
- Enables ML feature extraction

## Query Patterns This Design Supports

1. **Subject Analysis**: "Show me all data for subject S01"
   - Clustering on subject_id makes this fast
   
2. **Time Range**: "Analyze Jan 10-15 data"
   - Partitioning by date makes this cheap
   
3. **Signal Comparison**: "Compare HR vs EDA during stress"
   - Clustering on signal_type groups related data
   
4. **Session Metrics**: "Average HR per session"
   - Pre-aggregated table avoids scanning 50M rows

## Cost Optimization

### Without Partitioning/Clustering
- Query scanning full table: 5 GB × $5/TB = $0.025 per query
- 100 queries/day = $2.50/day = $75/month

### With Partitioning/Clustering
- Query scanning 1 day: 50 MB × $5/TB = $0.00025 per query
- 100 queries/day = $0.025/day = $0.75/month

**Savings: 99% cost reduction!**
EOF