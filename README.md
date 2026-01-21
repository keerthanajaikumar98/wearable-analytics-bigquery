# Wearable Analytics: Stress & Exercise Intelligence System

[![BigQuery](https://img.shields.io/badge/BigQuery-Analytics-blue?logo=google-cloud)](https://cloud.google.com/bigquery)
[![Python](https://img.shields.io/badge/Python-3.8+-green?logo=python)](https://www.python.org/)
[![SQL](https://img.shields.io/badge/SQL-Advanced-orange)](https://www.sql.org/)
[![Cost](https://img.shields.io/badge/Monthly_Cost-$0-success)](docs/optimization_results.md)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

**Business Context:** Wearable fitness companies need to classify user states (stress, recovery, exercise intensity) to deliver personalized coaching. This project demonstrates end-to-end data analytics pipeline design, from raw sensor data to actionable product insights.

---

##Project Highlights

| Metric | Achievement |
|--------|-------------|
| **Data Volume** | ~50M measurements across 97 sessions |
| **Data Model** | Star schema with partitioning & clustering |
| **Feature Engineering** | HRV, stress detection, exercise zones |
| **User Segmentation** | 6 personas with feature recommendations |
| **Query Performance** | 1-5 seconds (100x faster than unoptimized) |
| **Cost Optimization** | 99% reduction ($50/mo → $0/mo) |

---

## Architecture

### System Overview
```
PhysioNet Dataset (50M measurements)
         ↓
Python Data Loader (handles data quality)
         ↓
BigQuery Fact Tables (partitioned by date, clustered by subject/session/signal)
         ↓
Feature Engineering (SQL)
   ├─ HRV Metrics (SDNN, RMSSD, pNN50)
   ├─ Stress Detection (multi-signal fusion)
   └─ Exercise Zones (Myzone-style MEPs)
         ↓
Product Analytics
   ├─ Recovery Time Analysis
   ├─ Stress Response Patterns
   ├─ User Segmentation
   └─ Session Performance Tracking
         ↓
Business Insights & Dashboards
```

**[View detailed architecture diagrams →](diagrams/architecture.md)**

---

## Key Features

### Production-Grade Data Model
- **Star schema** optimized for analytical queries
- **Partitioned by date** for 95%+ cost savings
- **Clustered** by access patterns (subject, session, signal)
- **50M+ measurements** with sub-second query times

### Feature Engineering
- **Heart Rate Variability (HRV)**: SDNN, RMSSD, pNN50 for stress/recovery
- **Multi-Signal Stress Detection**: EDA + HR + Temperature fusion
- **Exercise Zone Classification**: 6 zones like Myzone's MEPs system
- **Real-time aggregations** in 1-minute windows

### Product Analytics
- **Recovery Time Analysis**: How long to recover from intense exercise?
- **Stress Profiling**: Who's a fast reactor vs. good recoverer?
- **User Segmentation**: 6 personas (Athlete, Beginner, Stress-Focused, etc.)
- **Cohort Analysis**: V1 vs V2 protocol comparison

### Cost Optimization
- **$0/month** operating cost (free tier utilization)
- **100x query performance** improvement
- **Automated cost monitoring** and alerts
- **Scalable to 10,000+ users** with linear cost growth

---

## Repository Structure
```
wearable-analytics-bigquery/
├── README.md                          # This file
├── data/
│   ├── raw/                           # PhysioNet dataset (not in git - the dataset can be found in this [link](https://physionet.org/content/wearable-device-dataset/1.0.1/))
│   ├── processed/                     # Cleaned CSVs
│   └── schemas/                       # BigQuery table schemas
├── sql/
│   ├── 01_setup/                      # Table creation DDL
│   ├── 02_ingestion/                  # Data loading queries
│   ├── 03_feature_engineering/        # HRV, stress, zones
│   ├── 04_analytics/                  # Product analytics
│   └── 05_optimization/               # Cost analysis
├── scripts/
│   ├── load_physiological_data.py     # Main data loader
│   ├── prepare_subjects.py            # Demographics prep
│   ├── optimize_bigquery.py           # Cost optimizer
│   └── cost_monitor.py                # Usage alerts
├── notebooks/
│   └── 01_data_exploration.ipynb      # Exploratory analysis
├── diagrams/
│   ├── architecture.md                # System diagrams
│   └── performance_comparison.md      # Optimization results
└── docs/
    ├── schema_design.md               # Data model rationale
    ├── feature_engineering_summary.md # ML features
    ├── analytics_insights.md          # Business insights
    ├── query_optimization_guide.md    # SQL best practices
    └── optimization_results.md        # Cost savings proof
```

---

## Tech Stack

- **Database**: Google BigQuery (partitioned & clustered tables)
- **Languages**: SQL, Python 3.8+
- **Data Processing**: pandas, numpy
- **Infrastructure**: Google Cloud SDK, Application Default Credentials
- **Version Control**: Git, GitHub
- **Documentation**: Markdown, Mermaid diagrams

---

## Sample Insights

### Recovery Time Analysis
```sql
-- Users with fastest recovery
SELECT subject_id, AVG(time_to_50pct_recovery_min) as avg_recovery
FROM analytics_recovery_time
GROUP BY subject_id
ORDER BY avg_recovery ASC
LIMIT 5;
```
**Insight**: Elite athletes recover to 50% baseline in 3-5 minutes, while beginners take 8-12 minutes.

### Stress Response Profiling
```sql
-- High-stress users needing intervention
SELECT subject_id, max_stress_index, pct_time_stressed
FROM analytics_stress_patterns
WHERE stress_profile_type = 'HIGH_REACTOR'
ORDER BY max_stress_index DESC;
```
**Insight**: 23% of users are "high reactors" → Target for stress management features.

### User Segmentation
```sql
-- Feature recommendations by segment
SELECT user_segment, COUNT(*) as users, recommended_features
FROM analytics_user_segments
GROUP BY user_segment, recommended_features;
```
**Insight**: 
- **Athletes** (15%) → Performance analytics, advanced metrics
- **Recovery-Focused** (28%) → Sleep tracking, HRV training
- **Beginners** (35%) → Guided workouts, education

---

## Business Value

### For Connected Fitness Companies:
1. **Gamification**: Already implemented 6-zone effort points system
2. **Recovery Coach**: Time-to-recovery metrics for rest day recommendations
3. **Stress Alerts**: Real-time stress detection from multi-signal data
4. **Personalization**: 6 user segments with tailored feature recommendations

---

## Future Enhancements - Currently working on 

### Phase 2: Machine Learning
- [ ] Build stress classification models (Random Forest, XGBoost)
- [ ] Predict recovery time based on workout intensity
- [ ] Anomaly detection for unusual physiological responses
- [ ] Real-time inference using BigQuery ML
---

## Documentation

- **[Schema Design Rationale](docs/schema_design.md)** - Why star schema? Partitioning decisions
- **[Feature Engineering](docs/feature_engineering_summary.md)** - HRV, stress, zones explained
- **[Analytics Insights](docs/analytics_insights.md)** - Business questions answered
- **[Query Optimization](docs/query_optimization_guide.md)** - SQL best practices
- **[Cost Optimization Results](docs/optimization_results.md)** - 99% savings breakdown
- **[Architecture Diagrams](diagrams/architecture.md)** - Visual system overview

---

## Contact

**Keerthana Jaikumar**  
Product Manager | Data Analytics | Wearable Tech  
[LinkedIn](https://linkedin.com/in/your-profile) | [Portfolio](https://your-portfolio.com)

---

## License

MIT License - feel free to use this as a learning resource!

---

## Acknowledgments

- **Dataset**: [PhysioNet Wearable Exam Stress Dataset](https://physionet.org/content/wearable-exam-stress/1.0.1/)
- **Authors**: Hongn, A., Bosch, F., Prado, L., & Bonomini, P. (2025)
- **Citation**: Hongn et al., *Scientific Data*, 12(1), 2025

---

**⭐ If this project helped you, please star it on GitHub!**
