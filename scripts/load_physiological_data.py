#!/usr/bin/env python3
"""
Load physiological measurement data to BigQuery with data quality handling

Usage:
  python scripts/load_physiological_data.py --session-type STRESS --subject S01
  python scripts/load_physiological_data.py --session-type STRESS --load-all
"""

import pandas as pd
import numpy as np
from google.cloud import bigquery
from pathlib import Path
import argparse
from datetime import datetime, timedelta
import sys

class DataQualityError(Exception):
    """Raised when data quality issues are detected"""
    pass

class EmpaticaDataLoader:
    
    # Known issues from data_constraints.txt
    KNOWN_ISSUES = {
        'STRESS': {
            'S02': 'duplicated_data',
            'f07': 'invalid_signals_no_cover_removed',
            'f14': 'split_data'
        },
        'AEROBIC': {
            'S03': 'incomplete_procedure',
            'S07': 'incomplete_procedure',
            'S11': 'split_data',
            'S12': 'test_not_performed'
        },
        'ANAEROBIC': {
            'S06': 'incomplete_procedure',
            'S16': 'split_data'
        }
    }
    
    def __init__(self, dataset_root='data/raw'):
        # Client automatically uses Application Default Credentials
        self.client = bigquery.Client()
        self.dataset_id = 'wearable_analytics'
        
        # Find the actual dataset location
        self.dataset_root = self._find_dataset_root(dataset_root)
        print(f"📁 Dataset root: {self.dataset_root}")
        print(f"🔑 Using project: {self.client.project}")
    
    def _find_dataset_root(self, base_path):
        """Find where the dataset actually lives"""
        base = Path(base_path)
        
        # Check common locations
        possible_paths = [
            base / 'wearable-exam-stress-1.0.1',
            base / 'physionet.org/files/wearable-exam-stress/1.0.1',
            base,
        ]
        
        for path in possible_paths:
            if path.exists() and (path / 'STRESS').exists():
                return path
        
        raise FileNotFoundError(
            f"Could not find dataset in {base}. "
            f"Expected to find STRESS/, AEROBIC/, ANAEROBIC/ directories."
        )
    
    def should_skip_subject(self, subject_id, session_type, include_problematic=False):
        """
        Determine if a subject should be skipped based on known issues
        
        Returns: (should_skip: bool, reason: str)
        """
        issues = self.KNOWN_ISSUES.get(session_type, {})
        
        if subject_id not in issues:
            return False, None
        
        issue = issues[subject_id]
        
        # Always skip these
        if issue in ['test_not_performed', 'invalid_signals_no_cover_removed']:
            return True, f"Excluded: {issue}"
        
        # Skip unless explicitly including problematic data
        if not include_problematic:
            if issue in ['incomplete_procedure', 'duplicated_data', 'split_data']:
                return True, f"Skipped (use --include-problematic to load): {issue}"
        
        return False, issue  # Load but note the issue
    
    def parse_empatica_csv(self, file_path):
        """
        Parse Empatica CSV format with flexible timestamp handling
        
        Handles both:
        - Unix timestamp: 1361377519.0
        - Datetime string: '2013-02-20 17:55:19'
        """
        df = pd.read_csv(file_path, header=None)
        
        # Extract metadata from first row
        first_value = df.iloc[0, 0]
        
        # Try to parse as Unix timestamp first
        try:
            start_time_unix = float(first_value)
            start_time = pd.to_datetime(start_time_unix, unit='s', utc=True)
        except (ValueError, TypeError):
            # If that fails, try parsing as datetime string
            try:
                start_time = pd.to_datetime(first_value)
                # Ensure it has timezone info
                if start_time.tzinfo is None:
                    start_time = start_time.tz_localize('UTC')
            except:
                raise DataQualityError(f"Cannot parse start time: {first_value}")
        
        # Get sample rate
        sample_rate = float(df.iloc[1, 0])
        
        # Get actual data (skip first 2 rows)
        data = df.iloc[2:].reset_index(drop=True)
        
        return start_time, sample_rate, data
    
    def process_single_signal(self, file_path, subject_id, session_id, 
                             signal_type, session_type):
        """Process a single sensor file into DataFrame"""
        
        start_time, sample_rate, data = self.parse_empatica_csv(file_path)
        
        records = []
        
        if signal_type == 'ACC':
            # Accelerometer has 3 columns (X, Y, Z)
            num_samples = len(data)
            for i in range(num_samples):
                timestamp = start_time + timedelta(seconds=i/sample_rate)
                
                for axis, col_idx in [('ACC_X', 0), ('ACC_Y', 1), ('ACC_Z', 2)]:
                    value = float(data.iloc[i, col_idx]) / 64.0  # Convert to g
                    
                    records.append({
                        'measurement_id': f"{session_id}_{axis}_{i}",
                        'subject_id': subject_id,
                        'session_id': session_id,
                        'measurement_timestamp': timestamp,
                        'signal_type': axis,
                        'value': value,
                        'session_type': session_type,
                        'data_quality_flag': 'VALID'
                    })
        
        elif signal_type == 'IBI':
            # IBI has special format: col1=time_offset, col2=interval_duration
            for i in range(len(data)):
                time_offset = float(data.iloc[i, 0])
                interval_duration = float(data.iloc[i, 1])
                timestamp = start_time + timedelta(seconds=time_offset)
                
                records.append({
                    'measurement_id': f"{session_id}_IBI_{i}",
                    'subject_id': subject_id,
                    'session_id': session_id,
                    'measurement_timestamp': timestamp,
                    'signal_type': 'IBI',
                    'value': interval_duration,
                    'session_type': session_type,
                    'data_quality_flag': 'VALID'
                })
        
        else:
            # Single-column signals (BVP, EDA, TEMP, HR)
            num_samples = len(data)
            for i in range(num_samples):
                timestamp = start_time + timedelta(seconds=i/sample_rate)
                value = float(data.iloc[i, 0])
                
                records.append({
                    'measurement_id': f"{session_id}_{signal_type}_{i}",
                    'subject_id': subject_id,
                    'session_id': session_id,
                    'measurement_timestamp': timestamp,
                    'signal_type': signal_type,
                    'value': value,
                    'session_type': session_type,
                    'data_quality_flag': 'VALID'
                })
        
        return pd.DataFrame(records)
    
    def load_subject_session(self, subject_id, session_type, include_problematic=False):
        """Load all sensor data for one subject's session"""
        
        # Check if should skip
        should_skip, reason = self.should_skip_subject(
            subject_id, session_type, include_problematic
        )
        
        if should_skip:
            print(f"\n⏭️  Skipping {subject_id} ({session_type}): {reason}")
            return None
        
        # Define file paths
        base_path = self.dataset_root / session_type / subject_id
        
        if not base_path.exists():
            print(f"\n⚠️  Path not found: {base_path}")
            return None
        
        # Create session ID
        session_id = f"{subject_id}_{session_type}"
        
        print(f"\n{'='*60}")
        print(f"📊 Processing: {subject_id} - {session_type}")
        if reason:
            print(f"⚠️  Note: {reason}")
        print(f"{'='*60}")
        
        # Process each signal type
        signal_files = {
            'BVP': 'BVP.csv',
            'EDA': 'EDA.csv',
            'TEMP': 'TEMP.csv',
            'ACC': 'ACC.csv',
            'HR': 'HR.csv',
            'IBI': 'IBI.csv'
        }
        
        all_data = []
        
        for signal_type, filename in signal_files.items():
            file_path = base_path / filename
            
            if not file_path.exists():
                print(f"  ⚠️  Missing: {filename}")
                continue
            
            try:
                df = self.process_single_signal(
                    file_path, subject_id, session_id, signal_type, session_type
                )
                all_data.append(df)
                print(f"  ✓ {signal_type}: {len(df):,} measurements")
                
            except Exception as e:
                print(f"  ✗ Error processing {signal_type}: {e}")
        
        if not all_data:
            print("  ✗ No data successfully processed")
            return None
        
        # Combine all signals
        combined_df = pd.concat(all_data, ignore_index=True)
        print(f"\n  📦 Total measurements: {len(combined_df):,}")
        
        # Upload to BigQuery
        self.upload_to_bigquery(combined_df, batch_size=50000)
        
        # Create session metadata
        self.create_session_metadata(
            session_id, subject_id, session_type, combined_df, reason
        )
        
        return combined_df
    
    def upload_to_bigquery(self, df, batch_size=50000):
        """Upload data in batches to avoid memory issues"""
        
        table_id = f"{self.dataset_id}.fact_physiological_measurements"
        
        num_batches = int(np.ceil(len(df) / batch_size))
        
        for i in range(num_batches):
            start_idx = i * batch_size
            end_idx = min((i + 1) * batch_size, len(df))
            batch = df.iloc[start_idx:end_idx]
            
            job_config = bigquery.LoadJobConfig(
                write_disposition="WRITE_APPEND",
            )
            
            job = self.client.load_table_from_dataframe(
                batch, table_id, job_config=job_config
            )
            job.result()  # Wait for completion
            
            print(f"  ✓ Uploaded batch {i+1}/{num_batches} ({len(batch):,} rows)")
    
    def create_session_metadata(self, session_id, subject_id, session_type, df, quality_note):
        """Create entry in dim_sessions table"""
        
        min_time = df['measurement_timestamp'].min()
        max_time = df['measurement_timestamp'].max()
        duration_minutes = (max_time - min_time).total_seconds() / 60
        
        session_data = [{
            'session_id': session_id,
            'subject_id': subject_id,
            'session_type': session_type,
            'protocol_version': 'V1' if subject_id.startswith('S') else 'V2',
            'session_date': min_time.date(),
            'session_start_time': min_time,
            'session_end_time': max_time,
            'duration_minutes': duration_minutes,
            'data_quality_notes': quality_note
        }]
        
        session_df = pd.DataFrame(session_data)
        
        table_id = f"{self.dataset_id}.dim_sessions"
        job_config = bigquery.LoadJobConfig(
            write_disposition="WRITE_APPEND"
        )
        
        job = self.client.load_table_from_dataframe(
            session_df, table_id, job_config=job_config
        )
        job.result()
        
        print(f"  ✓ Session metadata created")

def main():
    parser = argparse.ArgumentParser(
        description='Load Empatica data to BigQuery with quality checks'
    )
    parser.add_argument('--session-type', required=True, 
                       choices=['STRESS', 'AEROBIC', 'ANAEROBIC'])
    parser.add_argument('--subject', help='Specific subject ID (e.g., S01)')
    parser.add_argument('--load-all', action='store_true', 
                       help='Load all good-quality subjects')
    parser.add_argument('--include-problematic', action='store_true',
                       help='Also load subjects with known issues')
    
    args = parser.parse_args()
    
    loader = EmpaticaDataLoader()
    
    if args.load_all:
        # Find all subjects in this directory
        session_path = loader.dataset_root / args.session_type
        subjects = sorted([d.name for d in session_path.iterdir() if d.is_dir()])
        
        print(f"\n{'='*60}")
        print(f"📊 Found {len(subjects)} subjects for {args.session_type}")
        print(f"{'='*60}")
        
        loaded_count = 0
        skipped_count = 0
        
        for subject_id in subjects:
            result = loader.load_subject_session(
                subject_id, args.session_type, args.include_problematic
            )
            
            if result is not None:
                loaded_count += 1
            else:
                skipped_count += 1
        
        print(f"\n{'='*60}")
        print(f"✅ Loading complete!")
        print(f"   Loaded: {loaded_count} subjects")
        print(f"   Skipped: {skipped_count} subjects")
        print(f"{'='*60}")
    
    elif args.subject:
        loader.load_subject_session(
            args.subject, args.session_type, args.include_problematic
        )
    
    else:
        print("❌ Error: Provide either --subject or --load-all")
        sys.exit(1)

if __name__ == '__main__':
    main()