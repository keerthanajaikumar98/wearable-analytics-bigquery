# System Architecture Diagrams

## Overall Data Pipeline
```mermaid
graph LR
    A[PhysioNet Dataset<br/>~50M measurements] --> B[Python Loader<br/>load_physiological_data.py]
    B --> C[BigQuery<br/>fact_physiological_measurements]
    C --> D[Feature Engineering<br/>SQL Queries]
    D --> E1[derived_hrv_metrics]
    D --> E2[derived_stress_indicators]
    D --> E3[derived_exercise_zones]
    E1 --> F[Analytics Queries]
    E2 --> F
    E3 --> F
    F --> G1[analytics_recovery_time]
    F --> G2[analytics_stress_patterns]
    F --> G3[analytics_user_segments]
    G1 --> H[Product Insights<br/>& Dashboards]
    G2 --> H
    G3 --> H
    
    style C fill:#4285f4,color:#fff
    style D fill:#34a853,color:#fff
    style F fill:#fbbc04,color:#000
    style H fill:#ea4335,color:#fff
```

## Star Schema Data Model
```mermaid
erDiagram
    fact_physiological_measurements ||--o{ dim_subjects : "measured_from"
    fact_physiological_measurements ||--o{ dim_sessions : "belongs_to"
    fact_physiological_measurements ||--o{ dim_signal_types : "has_type"
    
    fact_session_metrics ||--o{ dim_subjects : "measured_from"
    fact_session_metrics ||--o{ dim_sessions : "belongs_to"
    
    dim_subjects {
        string subject_id PK
        string cohort
        int age
        float bmi
        string gender
    }
    
    dim_sessions {
        string session_id PK
        string subject_id FK
        string session_type
        timestamp session_start_time
        float duration_minutes
    }
    
    fact_physiological_measurements {
        string measurement_id PK
        string subject_id FK
        string session_id FK
        timestamp measurement_timestamp
        string signal_type FK
        float value
        string data_quality_flag
    }
    
    fact_session_metrics {
        string metric_id PK
        string subject_id FK
        string session_id FK
        timestamp stage_start_time
        float avg_hr
        float hrv_sdnn
        float stress_index
    }
    
    dim_signal_types {
        string signal_type PK
        string signal_name
        string unit
        float sample_rate_hz
    }
```

## Cost Optimization Strategy
```mermaid
graph TD
    A[Query Request] --> B{Has Partition Filter?}
    B -->|No| C[❌ Scan Entire Table<br/>Cost: $0.031<br/>Time: 20s]
    B -->|Yes| D{Uses Clustering Columns?}
    D -->|No| E[⚠️ Scan All Partitions<br/>Cost: $0.010<br/>Time: 10s]
    D -->|Yes| F{SELECT Specific Columns?}
    F -->|No| G[⚠️ Scan All Columns<br/>Cost: $0.003<br/>Time: 5s]
    F -->|Yes| H[✅ Optimized Query<br/>Cost: $0.0003<br/>Time: 2s]
    
    style C fill:#ea4335,color:#fff
    style E fill:#fbbc04,color:#000
    style G fill:#fbbc04,color:#000
    style H fill:#34a853,color:#fff
```

## Feature Engineering Flow
```mermaid
flowchart TB
    A[Raw Signals:<br/>BVP, EDA, HR, TEMP, ACC] --> B[Time Window<br/>Aggregation<br/>1-minute windows]
    
    B --> C1[IBI Signal]
    B --> C2[EDA + HR + TEMP]
    B --> C3[HR Signal]
    
    C1 --> D1[HRV Metrics<br/>SDNN, RMSSD, pNN50]
    C2 --> D2[Stress Index<br/>Multi-signal fusion]
    C3 --> D3[Exercise Zones<br/>% of Max HR]
    
    D1 --> E[Recovery<br/>Classification]
    D2 --> F[Stress<br/>Classification]
    D3 --> G[Training Zone<br/>Classification]
    
    E --> H[User Insights]
    F --> H
    G --> H
    
    H --> I1[Recovery Coach]
    H --> I2[Stress Management]
    H --> I3[Performance Analytics]
    
    style A fill:#e8f0fe
    style H fill:#fce8e6
    style I1 fill:#34a853,color:#fff
    style I2 fill:#4285f4,color:#fff
    style I3 fill:#fbbc04,color:#000
```

## User Segmentation Logic
```mermaid
graph TD
    A[User Data] --> B{Exercise Performance}
    
    B -->|High Intensity<br/>Good Recovery| C[ATHLETE<br/>→ Performance Analytics]
    B -->|Low HRV<br/>Poor Recovery| D[RECOVERY_FOCUSED<br/>→ Recovery Coach]
    B -->|High Stress| E[STRESS_MANAGEMENT<br/>→ Stress Tracking]
    B -->|Low Activity| F[BEGINNER<br/>→ Guided Programs]
    B -->|Moderate Activity| G[ACTIVE<br/>→ Social Features]
    B -->|Minimal Data| H[CASUAL<br/>→ Simple Tracking]
    
    style C fill:#34a853,color:#fff
    style D fill:#4285f4,color:#fff
    style E fill:#ea4335,color:#fff
    style F fill:#fbbc04,color:#000
    style G fill:#34a853,color:#fff
    style H fill:#e8eaed
