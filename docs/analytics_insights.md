cat > docs/analytics_insights.md << 'EOF'
# Analytics Insights Summary

## Overview
Product analytics queries answering key business questions for wearable fitness companies.

## Analytics Tables Created

### 1. analytics_recovery_time
**Question**: How long does recovery take after intense exercise?  
**Business Use**: 
- Recommend rest days
- Optimize training plans
- Alert users to overtraining

**Key Metrics**:
- Time to 50% recovery
- Time to 75% recovery
- Recovery rate (% per minute)

**Sample Insight**: 
```sql
-- Users with slow recovery (>10 min to 50%)
SELECT subject_id, avg_time_to_50pct_min
FROM analytics_recovery_time
WHERE avg_time_to_50pct_min > 10;
```

### 2. analytics_stress_patterns
**Question**: Who is most reactive to stress?  
**Business Use**:
- Personalize stress management features
- Identify users who need intervention
- Validate stress test effectiveness

**User Profiles**:
- **FAST_REACTOR**: Immediate stress response → Mindfulness features
- **HIGH_REACTOR**: Intense stress peaks → Breathing exercises
- **GOOD_RECOVERER**: Quick stress recovery → Stress resilience training
- **VARIABLE_REACTOR**: Inconsistent responses → Pattern tracking

**Sample Insight**:
```sql
-- High-stress users needing intervention
SELECT subject_id, max_stress_index, pct_time_stressed
FROM analytics_stress_patterns
WHERE stress_profile_type = 'HIGH_REACTOR';
```

### 3. analytics_user_segments
**Question**: What features should we recommend to each user?  
**Business Use**:
- Personalized onboarding
- Feature upsell targeting
- Retention strategies

**Segments**:
- **ATHLETE**: Performance analytics, advanced metrics
- **RECOVERY_FOCUSED**: Sleep tracking, HRV training
- **STRESS_MANAGEMENT**: Meditation, breathing exercises
- **BEGINNER**: Guided workouts, education content
- **ACTIVE**: Social features, challenges
- **CASUAL**: Simple tracking, motivation

**Sample Insight**:
```sql
-- Feature adoption opportunity
SELECT user_segment, COUNT(*) as users, recommended_features
FROM analytics_user_segments
GROUP BY user_segment, recommended_features;
```

### 4. analytics_cohort_comparison
**Question**: Did protocol V2 improve data quality?  
**Business Use**:
- Validate study design decisions
- Inform future protocol changes
- Academic publication material

**Metrics Compared**:
- Data completeness
- Signal quality
- Stress response strength
- Recovery metrics

### 5. analytics_session_performance
**Question**: How did each workout perform?  
**Business Use**:
- Progress tracking
- Goal achievement
- User engagement

**Metrics**:
- Total MEPs earned
- Max HR achieved
- Performance score (0-100)
- Active minutes

## Product Recommendations

### For Myzone-like Companies:

**1. MEPs Leaderboard**
```sql
SELECT subject_id, SUM(total_meps) as lifetime_meps
FROM analytics_session_performance
GROUP BY subject_id
ORDER BY lifetime_meps DESC;
```

**2. Recovery Alerts**
```sql
-- Users needing rest
SELECT subject_id
FROM analytics_recovery_time
WHERE avg_recovery_rate_pct_per_min < 5  -- Slow recovery
   OR time_to_75pct_recovery_min > 15;    -- Takes >15 min
```

**3. Stress Management Upsell**
```sql
-- High-stress users without stress features
SELECT subject_id
FROM analytics_stress_patterns
WHERE max_stress_index > 0.7
  AND subject_id NOT IN (
    SELECT subject_id FROM stress_feature_users  -- hypothetical
  );
```

## Key Findings (Update After Running Queries)

1. **Average Recovery Time**: [TBD] minutes to 50% recovery
2. **Most Common Segment**: [TBD] users
3. **Stress Reactivity**: [TBD]% are high reactors
4. **Protocol V2 Impact**: [TBD]% improvement in data quality

## Next Steps

1. Build ML models using these analytics features
2. Create real-time dashboards
3. Implement recommendation engine
4. A/B test feature recommendations
