# backend/mlflow_tracker.py
# CloudSieve — MLflow Experiment Tracker
# Run after the main pipeline to log everything to MLflow UI
# Usage: python mlflow_tracker.py --file sample_data.csv --fuzzy_col name --threshold 85

import mlflow
import mlflow.sklearn
import argparse
import pandas as pd
import joblib
import json
import os
from engine import (
    profile_dataset, exact_dedup, fuzzy_dedup,
    repair_data, detect_anomalies, calculate_cqi
)

# ─────────────────────────────────────────────
# ARGUMENT PARSER
# ─────────────────────────────────────────────
parser = argparse.ArgumentParser(description='CloudSieve MLflow Tracker')
parser.add_argument('--file',      default='sample_data.csv', help='Path to input CSV')
parser.add_argument('--fuzzy_col', default='name',            help='Column for fuzzy matching')
parser.add_argument('--threshold', default=85, type=int,      help='Fuzzy match threshold')
args = parser.parse_args()


# ─────────────────────────────────────────────
# MLFLOW PIPELINE RUN
# ─────────────────────────────────────────────
mlflow.set_experiment("CloudSieve_Experiments")

with mlflow.start_run(run_name=f"CloudSieve_Run_{os.path.basename(args.file)}"):

    print("=" * 55)
    print("☁️  CloudSieve — MLflow Tracked Pipeline Run")
    print("=" * 55)

    # Log run parameters
    mlflow.log_param("input_file",   args.file)
    mlflow.log_param("fuzzy_col",    args.fuzzy_col)
    mlflow.log_param("threshold",    args.threshold)

    # ── STAGE 1: LOAD & PROFILE ──
    print(f"\n📥 Loading: {args.file}")
    df_raw = pd.read_csv(args.file)
    profile = profile_dataset(df_raw)
    mlflow.log_param("total_raw_records",  profile["total_records"])
    mlflow.log_param("total_columns",      profile["total_columns"])
    mlflow.log_metric("raw_null_rate",     profile["null_rate"])

    # Save profile as artifact
    with open("profile_report.json", "w") as f:
        json.dump(profile, f, indent=2)
    mlflow.log_artifact("profile_report.json")
    print(f"✅ Profile: {profile['total_records']} records, null rate={profile['null_rate']}%")

    # ── STAGE 2: EXACT DEDUP ──
    df, exact_removed = exact_dedup(df_raw.copy())
    mlflow.log_metric("exact_duplicates_removed", exact_removed)
    print(f"✅ Exact dedup: removed {exact_removed}")

    # ── STAGE 3: FUZZY DEDUP ──
    df, fuzzy_removed, fuzzy_matches = fuzzy_dedup(df, args.fuzzy_col, args.threshold)
    mlflow.log_metric("fuzzy_duplicates_removed", fuzzy_removed)
    mlflow.log_metric("fuzzy_matches_found",      len(fuzzy_matches))
    if fuzzy_matches:
        with open("fuzzy_matches.json", "w") as f:
            json.dump(fuzzy_matches, f, indent=2)
        mlflow.log_artifact("fuzzy_matches.json")
    print(f"✅ Fuzzy dedup: removed {fuzzy_removed}")

    # ── STAGE 4: REPAIR ──
    df, total_repairs, repair_log = repair_data(df)
    mlflow.log_metric("total_repairs",     total_repairs)
    mlflow.log_metric("repair_operations", len(repair_log))
    if repair_log:
        with open("repair_log.json", "w") as f:
            json.dump(repair_log, f, indent=2)
        mlflow.log_artifact("repair_log.json")
    print(f"✅ Repairs: {total_repairs} records fixed")

    # ── STAGE 5: ANOMALY DETECTION ──
    df, anomaly_count = detect_anomalies(df)
    mlflow.log_metric("anomalies_flagged", anomaly_count)
    print(f"✅ Anomalies: {anomaly_count} flagged")

    # ── STAGE 6: CQI SCORING ──
    cqi = calculate_cqi(df_raw, df, anomaly_count)
    for key, value in cqi.items():
        mlflow.log_metric(key, value)
    with open("cqi_report.json", "w") as f:
        json.dump(cqi, f, indent=2)
    mlflow.log_artifact("cqi_report.json")
    print(f"✅ CQI Score: {cqi['cqi_score']}/100")

    # ── SAVE CLEAN CSV ──
    clean_path = f"clean_{os.path.basename(args.file)}"
    df.to_csv(clean_path, index=False)
    mlflow.log_artifact(clean_path)

    # ── TRAIN + LOG ISOLATION FOREST MODEL ──
    from sklearn.ensemble import IsolationForest
    import numpy as np
    numeric = df.select_dtypes(include=[np.number]).fillna(0)
    if not numeric.empty:
        model = IsolationForest(contamination=0.1, random_state=42)
        model.fit(numeric)
        joblib.dump(model, "anomaly_model.pkl")
        mlflow.sklearn.log_model(model, "anomaly_detector",
            registered_model_name="CloudSieve_AnomalyDetector")
        mlflow.log_artifact("anomaly_model.pkl")
        print("✅ Isolation Forest model logged to MLflow")

    # ── SUMMARY ──
    mlflow.log_metric("clean_count",   len(df))
    mlflow.log_metric("records_saved", raw_count := len(df_raw))

    print("\n" + "=" * 55)
    print(f"📊 SUMMARY")
    print(f"   Raw records:      {raw_count}")
    print(f"   Clean records:    {len(df)}")
    print(f"   Exact removed:    {exact_removed}")
    print(f"   Fuzzy removed:    {fuzzy_removed}")
    print(f"   Repairs made:     {total_repairs}")
    print(f"   Anomalies:        {anomaly_count}")
    print(f"   CQI Score:        {cqi['cqi_score']}/100")
    print("=" * 55)
    print("\n🎯 All metrics logged. Run: mlflow ui → http://127.0.0.1:5000")
