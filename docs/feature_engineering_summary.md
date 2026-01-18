# Feature Engineering Summary

## Overview
Derived features from raw physiological signals for stress detection, recovery monitoring, and exercise classification.

## Tables Created

### 1. derived_hrv_metrics
**Purpose**: Heart rate variability analysis  
**Source**: IBI signal  
**Window**: 1-minute intervals  
**Key Metrics**:
- SDNN: Overall HRV (stress indicator)
- RMSSD: Parasympathetic activity (recovery)
- pNN50: Vagal tone

### 2. derived_stress_indicators
**Purpose**: Multi-signal stress detection  
**Sources**: EDA + HR + TEMP  
**Window**: 1-minute intervals  
**Key Metrics**:
- Composite stress index (0-1 scale)
- Binary stress classification (CALM/STRESSED)
- Individual signal changes from baseline

### 3. derived_exercise_zones
**Purpose**: Exercise intensity classification  
**Source**: HR signal  
**Based on**: % of age-predicted max HR  
**Key Metrics**:
- 6 training zones (Recovery → Maximum)
- MEPs (Myzone Effort Points)
- Metabolic zone classification

### 4. session_zone_summary
**Purpose**: Session-level exercise summaries  
**Key Metrics**:
- Time in each zone
- Total effort points
- Average HR per zone

## Data Quality Monitoring

### vw_data_quality_report
Tracks:
- Data completeness (% of expected samples)
- Outlier detection (>3 SD from mean)
- Missing values
- Signal duration

## Usage Examples

### Find high-stress moments:
```sql
SELECT 
  subject_id,
  time_window,
  stress_index,
  eda_change_pct,
  hr_change_pct
FROM wearable_analytics.derived_stress_indicators
WHERE stress_state = 'STRESSED'
ORDER BY stress_index DESC
LIMIT 10;
```

### Analyze recovery after exercise:
```sql
SELECT 
  subject_id,
  hrv_category,
  recovery_status,
  AVG(rmssd) as avg_rmssd
FROM wearable_analytics.derived_hrv_metrics
WHERE session_type IN ('AEROBIC', 'ANAEROBIC')
GROUP BY subject_id, hrv_category, recovery_status
ORDER BY avg_rmssd DESC;
```

### Calculate total MEPs per session:
```sql
SELECT 
  session_id,
  SUM(total_effort_points) as total_meps,
  SUM(minutes_in_zone) as total_minutes
FROM wearable_analytics.session_zone_summary
GROUP BY session_id
ORDER BY total_meps DESC;
```

## Important Notes

- All queries include 365-day partition filter for cost efficiency
- Baseline calculated from first 3 minutes of each session
- Exercise zones only apply to AEROBIC/ANAEROBIC sessions
- HRV requires IBI signal (may not be available for all subjects)

## Next Steps

1. Load more subjects (currently have limited data)
2. Validate stress index against self-reported stress
3. Build ML models for classification
4. Create real-time scoring API
