#!/usr/bin/env python3
"""
Explore the actual dataset structure and identify data quality issues
"""
import pandas as pd
from pathlib import Path
import json

def explore_dataset():
    """Explore what files actually exist and their quality"""
    
    # Find the dataset root
    base_path = Path('data/raw')
    
    # Look for the actual directory structure
    possible_paths = [
        base_path / 'wearable-exam-stress-1.0.1',
        base_path / 'physionet.org/files/wearable-exam-stress/1.0.1',
        base_path,
    ]
    
    dataset_root = None
    for path in possible_paths:
        if path.exists() and (path / 'STRESS').exists():
            dataset_root = path
            break
    
    if not dataset_root:
        print("❌ Could not find dataset. Please check:")
        print("   - Did you extract the ZIP file?")
        print("   - Is it in data/raw/?")
        print("\nTry running: ls -la data/raw/")
        return
    
    print(f"✅ Found dataset at: {dataset_root}")
    print(f"\n{'='*70}")
    
    # Read data constraints with encoding handling
    constraints_file = dataset_root / 'data_constraints.txt'
    if constraints_file.exists():
        print("\n📋 DATA CONSTRAINTS:")
        print("="*70)
        try:
            # Try UTF-8 first
            with open(constraints_file, 'r', encoding='utf-8') as f:
                constraints_content = f.read()
        except UnicodeDecodeError:
            # Fall back to latin-1 or cp1252 (Windows encoding)
            try:
                with open(constraints_file, 'r', encoding='latin-1') as f:
                    constraints_content = f.read()
            except:
                with open(constraints_file, 'r', encoding='cp1252') as f:
                    constraints_content = f.read()
        
        print(constraints_content)
        print("="*70)
    
    # Parse constraints into structured format
    known_issues = {
        'STRESS': {
            'S02': 'duplicated data',
            'f07': 'did not remove wristband protection cover - signals invalid',
            'f14': 'data split into two parts'
        },
        'AEROBIC': {
            'S03': 'could not complete procedure',
            'S07': 'could not complete procedure',
            'S11': 'data split into two parts',
            'S12': 'did not perform this test'
        },
        'ANAEROBIC': {
            'S06': 'could not complete procedure',
            'S16': 'data split into two parts'
        }
    }
    
    # Explore each session type
    results = {}
    
    for session_type in ['STRESS', 'AEROBIC', 'ANAEROBIC']:
        session_path = dataset_root / session_type
        
        if not session_path.exists():
            print(f"\n⚠️  Directory not found: {session_type}")
            continue
        
        print(f"\n\n{'='*70}")
        print(f"📊 {session_type} SESSION ANALYSIS")
        print(f"{'='*70}")
        
        subjects = sorted([d.name for d in session_path.iterdir() if d.is_dir()])
        print(f"\nTotal subject folders: {len(subjects)}")
        print(f"Subjects: {', '.join(subjects)}")
        
        session_results = []
        
        for subject_id in subjects:
            subject_path = session_path / subject_id
            
            # Check which files exist
            expected_files = ['BVP.csv', 'EDA.csv', 'TEMP.csv', 'ACC.csv', 'HR.csv', 'IBI.csv', 'tags.csv']
            
            files_found = []
            file_sizes = {}
            
            for filename in expected_files:
                file_path = subject_path / filename
                if file_path.exists():
                    files_found.append(filename)
                    file_sizes[filename] = file_path.stat().st_size
            
            # Check for known issues
            issue = known_issues.get(session_type, {}).get(subject_id, None)
            
            # Determine data quality
            missing_files = set(expected_files) - set(files_found)
            
            quality = 'GOOD'
            if issue:
                quality = 'PROBLEMATIC'
            elif missing_files:
                quality = 'INCOMPLETE'
            
            session_results.append({
                'subject_id': subject_id,
                'files_found': len(files_found),
                'files_expected': len(expected_files),
                'missing_files': list(missing_files),
                'known_issue': issue,
                'quality': quality,
                'total_size_mb': sum(file_sizes.values()) / (1024*1024)
            })
            
            # Print details for problematic subjects
            if quality != 'GOOD':
                print(f"\n  ⚠️  {subject_id}:")
                print(f"      Quality: {quality}")
                print(f"      Files: {len(files_found)}/{len(expected_files)}")
                if missing_files:
                    print(f"      Missing: {', '.join(missing_files)}")
                if issue:
                    print(f"      Issue: {issue}")
        
        results[session_type] = session_results
        
        # Summary statistics
        df_results = pd.DataFrame(session_results)
        print(f"\n  📈 Summary:")
        print(f"      Good quality: {(df_results['quality'] == 'GOOD').sum()} subjects")
        print(f"      Problematic: {(df_results['quality'] == 'PROBLEMATIC').sum()} subjects")
        print(f"      Incomplete: {(df_results['quality'] == 'INCOMPLETE').sum()} subjects")
        print(f"      Total data size: {df_results['total_size_mb'].sum():.2f} MB")
    
    # Save exploration results
    output_file = 'data/processed/dataset_inventory.json'
    Path('data/processed').mkdir(exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n\n✅ Exploration complete!")
    print(f"📁 Detailed inventory saved to: {output_file}")
    
    return results

def check_subject_info(dataset_root):
    """Check the subject-info.csv file"""
    
    subject_file = dataset_root / 'subject-info.csv'
    
    if not subject_file.exists():
        print("⚠️  subject-info.csv not found!")
        return
    
    df = pd.read_csv(subject_file)
    
    print(f"\n\n{'='*70}")
    print("📊 SUBJECT DEMOGRAPHICS")
    print(f"{'='*70}")
    print(f"\nColumns: {df.columns.tolist()}")
    print(f"Total subjects: {len(df)}")
    print(f"\nFirst few rows:")
    print(df.head(10))
    
    print(f"\nAge distribution:")
    # Handle case-insensitive column names
    age_col = 'Age' if 'Age' in df.columns else 'age'
    print(df[age_col].describe())
    
    return df

if __name__ == '__main__':
    results = explore_dataset()
    
    # Also check subject info
    base_path = Path('data/raw')
    for path in [base_path / 'wearable-exam-stress-1.0.1', 
                 base_path / 'physionet.org/files/wearable-exam-stress/1.0.1',
                 base_path]:
        if path.exists() and (path / 'subject-info.csv').exists():
            check_subject_info(path)
            break