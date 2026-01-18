#!/usr/bin/env python3
"""
Prepare subject demographics for BigQuery upload
"""
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
import random

def find_subject_file():
    """Find the subject-info.csv file"""
    base_path = Path('data/raw')
    
    possible_paths = [
        base_path / 'wearable-exam-stress-1.0.1' / 'subject-info.csv',
        base_path / 'physionet.org/files/wearable-exam-stress/1.0.1/subject-info.csv',
        base_path / 'subject-info.csv'
    ]
    
    for path in possible_paths:
        if path.exists():
            return path
    
    raise FileNotFoundError("Could not find subject-info.csv")

def clean_numeric_column(series, integer=False):
    """Clean numeric columns by removing asterisks and converting to float/int"""
    def clean_value(val):
        if pd.isna(val):
            return None
        val_str = str(val).replace('*', '').strip()
        try:
            return int(val_str) if integer else float(val_str)
        except ValueError:
            return None
    return series.apply(clean_value)

def prepare_subjects():
    """Prepare and clean subject data"""
    
    # Read raw subject info
    subject_file = find_subject_file()
    print(f"Reading from: {subject_file}")
    
    df = pd.read_csv(subject_file)
    
    # Clean column names
    df.columns = df.columns.str.strip()
    
    print(f"\nOriginal columns: {df.columns.tolist()}")
    print(f"Total subjects: {len(df)}")
    
    # Rename columns to match BigQuery schema
    column_mapping = {
        'Info': 'subject_id',
        'Gender': 'gender',
        'Age': 'age',
        'Height (cm)': 'height_cm',
        'Weight (kg)': 'weight_kg'
    }
    df = df.rename(columns=column_mapping)
    print(f"\nRenamed columns: {df.columns.tolist()}")
    
    # Clean numeric columns
    print(f"\n🧹 Cleaning numeric columns...")
    df['age'] = clean_numeric_column(df['age'], integer=True)
    df['height_cm'] = clean_numeric_column(df['height_cm'])
    df['weight_kg'] = clean_numeric_column(df['weight_kg'])
    
    # Add cohort information
    df['cohort'] = df['subject_id'].apply(lambda x: 'V1' if str(x).startswith('S') else 'V2')
    
    # Calculate BMI
    df['bmi'] = df.apply(
        lambda row: row['weight_kg'] / ((row['height_cm'] / 100) ** 2)
        if pd.notna(row['weight_kg']) and pd.notna(row['height_cm'])
        else None,
        axis=1
    )
    
    # Clean gender
    df['gender'] = df['gender'].str.upper().str.strip()
    
    # Generate enrollment dates
    base_date = datetime(2023, 4, 27)
    random.seed(42)
    df['enrollment_date'] = [
        (base_date + timedelta(days=random.randint(0, 180))).date()
        for _ in range(len(df))
    ]
    
    # Select final columns
    df = df[[
        'subject_id', 'cohort', 'age', 'weight_kg', 'height_cm', 
        'bmi', 'gender', 'enrollment_date'
    ]]
    
    # Drop rows with missing critical data
    df = df.dropna(subset=['subject_id', 'age', 'weight_kg', 'height_cm'])
    
    # Convert dtypes to match BigQuery
    # Age: INT64 (as string so CSV writes integer literals without .0)
    # weight, height, bmi: FLOAT64
    df['age'] = df['age'].astype('Int64').astype(str)  # BigQuery INT64 safe
    df['weight_kg'] = df['weight_kg'].astype(float)
    df['height_cm'] = df['height_cm'].astype(float)
    df['bmi'] = df['bmi'].astype(float)
    
    # Save processed file
    output_dir = Path('data/processed')
    output_dir.mkdir(exist_ok=True)
    output_file = output_dir / 'subjects_prepared.csv'

    # Write CSV with proper integer formatting for age
    df.to_csv(output_file, index=False, float_format='%.10g')
    
    print(f"\n Processed {len(df)} subjects")
    print(f" Saved to: {output_file}")
    print(df.head(10).to_string(index=False))
    
    print(f"\n Summary:")
    print(f"  V1 cohort: {(df['cohort'] == 'V1').sum()} subjects")
    print(f"  V2 cohort: {(df['cohort'] == 'V2').sum()} subjects")
    # Convert age back to int for display summary
    df['age'] = pd.to_numeric(df['age'])
    print(f"  Age range: {df['age'].min():.0f}-{df['age'].max():.0f} years (avg: {df['age'].mean():.1f})")
    print(f"  BMI range: {df['bmi'].min():.1f}-{df['bmi'].max():.1f} (avg: {df['bmi'].mean():.1f})")
    print(f"  Gender distribution: {df['gender'].value_counts().to_dict()}")
    
    return output_file

if __name__ == '__main__':
    prepare_subjects()
