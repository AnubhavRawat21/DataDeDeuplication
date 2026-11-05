

import pandas as pd
import numpy as np
from rapidfuzz import fuzz
from sklearn.ensemble import IsolationForest
import math
import warnings
warnings.filterwarnings("ignore")



def read_csv_safe(file_path: str) -> pd.DataFrame:
    encodings = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1', 'utf-16']
    for enc in encodings:
        try:
            df = pd.read_csv(file_path, encoding=enc)
            print(f"[CloudSieve] Read CSV with encoding: {enc}")
            return df
        except (UnicodeDecodeError, Exception):
            continue
    raise ValueError("Could not read CSV with any known encoding. File may be corrupted.")



def clean_value(val):
    if isinstance(val, float):
        if math.isnan(val) or math.isinf(val):
            return None
    if isinstance(val, (np.integer,)):
        return int(val)
    if isinstance(val, (np.floating,)):
        if math.isnan(val) or math.isinf(val):
            return None
        return float(val)
    return val



def profile_dataset(df: pd.DataFrame) -> dict:
    total = len(df)
    total_cells = total * len(df.columns)
    null_total = int(df.isnull().sum().sum())
    col_profiles = []
    for col in df.columns:
        null_count = int(df[col].isnull().sum())
        col_profiles.append({
            "column":      col,
            "dtype":       str(df[col].dtype),
            "null_count":  null_count,
            "null_rate":   round(null_count / max(total, 1) * 100, 2),
            "unique_count": int(df[col].nunique()),
        })
    return {
        "total_records": total,
        "total_columns": len(df.columns),
        "total_nulls":   null_total,
        "null_rate":     round(null_total / max(total_cells, 1) * 100, 2),
        "columns":       col_profiles
    }



def exact_dedup(df: pd.DataFrame):
    before = len(df)
    df = df.drop_duplicates().reset_index(drop=True)
    removed = before - len(df)
    return df, removed



def fuzzy_dedup(df: pd.DataFrame, col: str, threshold: int = 85):
    if col not in df.columns:
        return df, 0, []

    # Get unique non-null values to avoid O(N^2) on full dataset
    # If there are too many unique values, limit to top 2000 to prevent server hangs
    value_counts = df[col].dropna().value_counts()
    unique_values = value_counts.nlargest(2000).index.tolist()
    
    drop_values = set()
    matches_found = []

    for i in range(len(unique_values)):
        val_i = str(unique_values[i])
        # Skip if already marked for dropping
        if unique_values[i] in drop_values:
            continue
            
        for j in range(i + 1, len(unique_values)):
            if unique_values[j] in drop_values:
                continue
                
            val_j = str(unique_values[j])
            score = fuzz.ratio(val_i, val_j)
            
            if score >= threshold:
                drop_values.add(unique_values[j])
                if len(matches_found) < 50:
                    matches_found.append({
                        "original":   val_i,
                        "duplicate":  val_j,
                        "similarity": score
                    })

    if drop_values:
        drop_indices = df[df[col].isin(drop_values)].index
        df = df.drop(index=drop_indices).reset_index(drop=True)
        return df, len(drop_indices), matches_found

    return df, 0, matches_found



def repair_data(df: pd.DataFrame):
    repairs = []

    for col in df.select_dtypes(include=[np.number]).columns:
        null_count = int(df[col].isnull().sum())
        if null_count > 0:
            median_val = df[col].median()
            if math.isnan(median_val):
                median_val = 0
            df[col] = df[col].fillna(median_val)
            repairs.append({"column": col, "type": "null_filled_numeric", "count": null_count})

        # Fix impossible ages
        if "age" in col.lower():
            invalid = int(((df[col] < 0) | (df[col] > 120)).sum())
            if invalid > 0:
                median_age = df[col].median()
                if math.isnan(median_age):
                    median_age = 30
                df.loc[(df[col] < 0) | (df[col] > 120), col] = median_age
                repairs.append({"column": col, "type": "invalid_age_fixed", "count": invalid})

    for col in df.select_dtypes(include=["object"]).columns:
        null_count = int(df[col].isnull().sum())
        if null_count > 0:
            df[col] = df[col].fillna("Unknown")
            repairs.append({"column": col, "type": "null_filled_text", "count": null_count})

        # Flag invalid emails
        if "email" in col.lower():
            invalid = int((~df[col].str.contains("@", na=False)).sum())
            if invalid > 0:
                df.loc[~df[col].str.contains("@", na=False), col] = None
                repairs.append({"column": col, "type": "invalid_email_flagged", "count": invalid})

    # Replace any remaining inf/-inf values
    df = df.replace([np.inf, -np.inf], np.nan)

    total_repairs = sum(r["count"] for r in repairs)
    return df, total_repairs, repairs



def detect_anomalies(df: pd.DataFrame):
    numeric = df.select_dtypes(include=[np.number])
    if numeric.empty or len(df) < 5:
        df["anomaly_flag"] = "Normal"
        return df, 0

    model = IsolationForest(contamination=0.1, random_state=42)
    features = numeric.fillna(0).replace([np.inf, -np.inf], 0)
    preds = model.fit_predict(features)
    df["anomaly_flag"] = ["Anomaly" if p == -1 else "Normal" for p in preds]
    anomaly_count = int((preds == -1).sum())
    return df, anomaly_count



def calculate_cqi(df_original: pd.DataFrame, df_clean: pd.DataFrame, anomaly_count: int) -> dict:
    total_orig  = len(df_original)
    total_clean = max(len(df_clean), 1)
    total_cells = total_clean * len(df_clean.columns)

    null_sum     = df_clean.isnull().sum().sum()
    completeness = round(1 - null_sum / max(total_cells, 1), 4)
    uniqueness   = round(total_clean / max(total_orig, 1), 4)
    validity     = round(1 - anomaly_count / max(total_clean, 1), 4)
    consistency  = round(df_clean.apply(lambda c: c.nunique() / total_clean).mean(), 4)
    accuracy     = round(min(completeness, validity), 4)
    cqi          = round((completeness + uniqueness + validity + consistency + accuracy) / 5 * 100, 2)

    # Safety clamp all values 0-100
    def clamp(v):
        v = round(v * 100, 1)
        return max(0.0, min(100.0, v))

    return {
        "completeness": clamp(completeness),
        "uniqueness":   clamp(uniqueness),
        "validity":     clamp(validity),
        "consistency":  clamp(consistency),
        "accuracy":     clamp(accuracy),
        "cqi_score":    max(0.0, min(100.0, cqi))
    }



def run_full_pipeline(file_path: str, fuzzy_col: str = "name", threshold: int = 85) -> dict:

    # Stage 1: Load with encoding detection
    df_raw = read_csv_safe(file_path)
    df = df_raw.copy()

    # Stage 2: Profile
    profile = profile_dataset(df_raw)

    # Stage 3: Exact dedup
    df, exact_removed = exact_dedup(df)

    # Stage 4: Fuzzy dedup
    df, fuzzy_removed, fuzzy_matches = fuzzy_dedup(df, fuzzy_col, threshold)

    # Stage 5: Repair
    df, total_repairs, repair_log = repair_data(df)

    # Stage 6: Anomaly detection
    df, anomaly_count = detect_anomalies(df)

    # Stage 7: CQI
    cqi = calculate_cqi(df_raw, df, anomaly_count)

    # Clean data for JSON — replace NaN/None/inf
    df = df.replace([np.inf, -np.inf], np.nan)
    df = df.where(pd.notnull(df), None)

    # Convert clean data rows safely
    clean_records = []
    for row in df.head(50).to_dict(orient="records"):
        clean_row = {k: clean_value(v) for k, v in row.items()}
        clean_records.append(clean_row)

    return {
        "profile":       profile,
        "exact_removed": exact_removed,
        "fuzzy_removed": fuzzy_removed,
        "fuzzy_matches": fuzzy_matches[:20],
        "total_repairs": total_repairs,
        "repair_log":    repair_log,
        "anomaly_count": anomaly_count,
        "cqi":           cqi,
        "raw_count":     len(df_raw),
        "clean_count":   len(df),
        "clean_data":    clean_records,
        "full_df":       df,
        "columns":       list(df.columns)
    }