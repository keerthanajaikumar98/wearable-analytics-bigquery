#!/usr/bin/env python3
"""
BigQuery Cost Monitor
Alerts when monthly costs approach limits
"""

from google.cloud import bigquery
from datetime import datetime
import sys

def check_monthly_usage():
    """Check current month's BigQuery usage"""
    
    client = bigquery.Client()
    
    query = """
    SELECT 
      SUM(total_bytes_billed) / POWER(1024, 4) as tb_billed,
      SUM(total_bytes_billed) / POWER(1024, 4) * 6.25 as estimated_cost,
      COUNT(*) as query_count
    FROM `region-us`.INFORMATION_SCHEMA.JOBS
    WHERE creation_time >= TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), MONTH)
      AND statement_type = 'SELECT'
      AND job_type = 'QUERY'
    """
    
    try:
        result = client.query(query).to_dataframe().iloc[0]
        
        tb_billed = result['tb_billed']
        cost = result['estimated_cost']
        queries = result['query_count']
        
        print(f"📊 BigQuery Usage This Month")
        print(f"="*50)
        print(f"Data Processed: {tb_billed:.2f} TB")
        print(f"Estimated Cost: ${cost:.2f}")
        print(f"Query Count: {queries:,}")
        print()
        
        # Alert thresholds
        FREE_TIER_TB = 1.0
        WARNING_THRESHOLD = 0.8  # 80% of free tier
        
        if tb_billed >= FREE_TIER_TB:
            print("🔴 ALERT: Exceeded free tier! You will be charged.")
            return 1
        elif tb_billed >= FREE_TIER_TB * WARNING_THRESHOLD:
            print(f"🟡 WARNING: Used {tb_billed/FREE_TIER_TB*100:.0f}% of free tier")
            print(f"   Remaining: {FREE_TIER_TB - tb_billed:.2f} TB")
            return 0
        else:
            print(f"🟢 HEALTHY: Used {tb_billed/FREE_TIER_TB*100:.0f}% of free tier")
            print(f"   Remaining: {FREE_TIER_TB - tb_billed:.2f} TB")
            return 0
            
    except Exception as e:
        print(f"❌ Error checking usage: {e}")
        return 1

if __name__ == '__main__':
    exit_code = check_monthly_usage()
    sys.exit(exit_code)