#!/usr/bin/env python3
"""
BigQuery Optimization Analyzer
Identifies cost-saving opportunities and performance improvements
"""

from google.cloud import bigquery
import pandas as pd
from datetime import datetime, timedelta

class BigQueryOptimizer:
    def __init__(self):
        self.client = bigquery.Client()
        self.dataset_id = 'wearable_analytics'
        
    def analyze_table_structure(self):
        """Analyze table structures for optimization opportunities using INFORMATION_SCHEMA.TABLES"""
        
        query = f"""
        SELECT 
            table_name,
            row_count,
            size_bytes,
            partitioning_type,
            require_partition_filter,
            ARRAY_LENGTH(clustering_ordinal_positions) AS num_clustering_fields
        FROM `{self.dataset_id}.INFORMATION_SCHEMA.TABLES`
        WHERE row_count > 0
        """
        
        df = self.client.query(query).to_dataframe()
        
        recommendations = []
        
        for _, row in df.iterrows():
            table_name = row['table_name']
            
            # Check partitioning
            if row['row_count'] > 100000 and not row['partitioning_type']:
                recommendations.append({
                    'table': table_name,
                    'priority': 'HIGH',
                    'type': 'PARTITIONING',
                    'issue': 'Large table without partitioning',
                    'recommendation': 'Add date-based partitioning',
                    'potential_savings': 'Up to 95% query cost reduction'
                })
            
            # Check clustering
            if row['row_count'] > 10000 and (row['num_clustering_fields'] is None or row['num_clustering_fields'] == 0):
                recommendations.append({
                    'table': table_name,
                    'priority': 'MEDIUM',
                    'type': 'CLUSTERING',
                    'issue': 'No clustering configured',
                    'recommendation': 'Add clustering on frequently filtered columns',
                    'potential_savings': '10-50% query cost reduction'
                })
            
            # Check partition filter requirement
            if row['partitioning_type'] and not row['require_partition_filter']:
                recommendations.append({
                    'table': table_name,
                    'priority': 'LOW',
                    'type': 'PARTITION_FILTER',
                    'issue': 'Partition filter not required',
                    'recommendation': 'Enable require_partition_filter to prevent expensive full scans',
                    'potential_savings': 'Prevents accidental expensive queries'
                })
        
        return pd.DataFrame(recommendations)
    
    def analyze_query_patterns(self):
        """Analyze query patterns from INFORMATION_SCHEMA.JOBS"""
        
        query = """
        SELECT 
            DATE(creation_time) as query_date,
            COUNT(*) as query_count,
            SUM(total_bytes_billed) / POWER(1024, 4) as total_tb_billed,
            SUM(total_bytes_billed) / POWER(1024, 4) * 6.25 as estimated_cost_usd,
            AVG(total_bytes_billed / POWER(1024, 3)) as avg_gb_per_query,
            COUNTIF(cache_hit) / COUNT(*) as cache_hit_rate
        FROM `region-us`.INFORMATION_SCHEMA.JOBS
        WHERE 
            creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
            AND statement_type = 'SELECT'
            AND job_type = 'QUERY'
        GROUP BY query_date
        ORDER BY query_date DESC
        """
        
        try:
            df = self.client.query(query).to_dataframe()
            return df
        except Exception as e:
            print(f"⚠️  Could not analyze query patterns: {e}")
            return None
    
    def calculate_projected_costs(self):
        """Calculate projected monthly storage costs"""
        
        query = f"""
        SELECT 
            SUM(size_bytes) / POWER(1024, 3) as total_storage_gb,
            SUM(size_bytes) / POWER(1024, 3) * 0.02 as monthly_storage_cost,
            SUM(size_bytes) / POWER(1024, 3) * 0.01 as monthly_long_term_storage_cost
        FROM `{self.dataset_id}.INFORMATION_SCHEMA.TABLES`
        """
        
        result = self.client.query(query).to_dataframe()
        return result.iloc[0]
    
    def generate_report(self):
        """Generate comprehensive optimization report"""
        
        print("="*70)
        print("BIGQUERY OPTIMIZATION REPORT")
        print("="*70)
        print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Dataset: {self.dataset_id}")
        print()
        
        # Cost projection
        print("💰 COST PROJECTION")
        print("-"*70)
        costs = self.calculate_projected_costs()
        print(f"Total Storage: {costs['total_storage_gb']:.2f} GB")
        print(f"Monthly Storage Cost: ${costs['monthly_storage_cost']:.2f}")
        print(f"(After 90 days inactive: ${costs['monthly_long_term_storage_cost']:.2f})")
        print()
        
        # Table structure recommendations
        print("🔧 TABLE OPTIMIZATION RECOMMENDATIONS")
        print("-"*70)
        recommendations = self.analyze_table_structure()
        
        if len(recommendations) == 0:
            print("✅ All tables are well-optimized!")
        else:
            print(recommendations.to_string(index=False))
        print()
        
        # Query patterns
        print("📊 QUERY PATTERN ANALYSIS (Last 30 Days)")
        print("-"*70)
        query_patterns = self.analyze_query_patterns()
        
        if query_patterns is not None and len(query_patterns) > 0:
            print(f"Total Queries: {query_patterns['query_count'].sum():,.0f}")
            print(f"Total Data Processed: {query_patterns['total_tb_billed'].sum():.2f} TB")
            print(f"Estimated Query Costs: ${query_patterns['estimated_cost_usd'].sum():.2f}")
            print(f"Avg Cache Hit Rate: {query_patterns['cache_hit_rate'].mean()*100:.1f}%")
            print()
            print("Daily breakdown:")
            print(query_patterns.head(10).to_string(index=False))
        else:
            print("ℹ️  Query history not available (requires recent query activity)")
        print()
        
        # Optimization tips
        print("💡 OPTIMIZATION TIPS")
        print("-"*70)
        print("1. Use SELECT specific columns instead of SELECT *")
        print("2. Filter on partitioned columns (measurement_timestamp)")
        print("3. Use clustered columns in WHERE clauses")
        print("4. Leverage query result caching (same query within 24h)")
        print("5. Use LIMIT for exploratory queries")
        print("6. Schedule large jobs during off-peak hours")
        print("7. Consider materializing frequently-used aggregations")
        print()
        
        print("="*70)

if __name__ == '__main__':
    optimizer = BigQueryOptimizer()
    optimizer.generate_report()
