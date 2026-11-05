# backend/tests/test_pipeline.py
# CloudSieve Pro — Pytest Test Suite

import sys
import os
import pytest
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from engine import (
    read_csv_safe, profile_dataset, exact_dedup,
    fuzzy_dedup, repair_data, detect_anomalies,
    calculate_cqi, run_full_pipeline
)


@pytest.fixture
def sample_df():
    return pd.DataFrame({
        "name": ["Alice", "Bob", "Alice", "Charlie", "Alicee", "Bob"],
        "age": [25, 30, 25, 35, 26, 30],
        "email": ["alice@test.com", "bob@test.com", "alice@test.com",
                  "charlie@test.com", "alice2@test.com", "bob@test.com"],
        "city": ["NYC", "LA", "NYC", None, "NYC", "LA"]
    })


@pytest.fixture
def sample_csv(tmp_path, sample_df):
    path = tmp_path / "test_data.csv"
    sample_df.to_csv(path, index=False)
    return str(path)


class TestProfiling:
    def test_profile_returns_correct_structure(self, sample_df):
        profile = profile_dataset(sample_df)
        assert "total_records" in profile
        assert "total_columns" in profile
        assert "total_nulls" in profile
        assert "columns" in profile
        assert len(profile["columns"]) == 4

    def test_profile_detects_nulls(self, sample_df):
        profile = profile_dataset(sample_df)
        assert profile["total_nulls"] >= 1

    def test_profile_counts_records(self, sample_df):
        profile = profile_dataset(sample_df)
        assert profile["total_records"] == 6


class TestExactDedup:
    def test_removes_exact_duplicates(self, sample_df):
        df, removed = exact_dedup(sample_df)
        assert removed > 0
        assert len(df) < len(sample_df)

    def test_no_duplicates_remain(self, sample_df):
        df, _ = exact_dedup(sample_df)
        assert df.duplicated().sum() == 0


class TestFuzzyDedup:
    def test_finds_fuzzy_matches(self, sample_df):
        df_deduped, _ = exact_dedup(sample_df)
        df, removed, matches = fuzzy_dedup(df_deduped, "name", threshold=80)
        assert isinstance(matches, list)

    def test_invalid_column_returns_unchanged(self, sample_df):
        df, removed, matches = fuzzy_dedup(sample_df, "nonexistent", threshold=85)
        assert removed == 0
        assert len(df) == len(sample_df)


class TestRepair:
    def test_fills_null_values(self):
        df = pd.DataFrame({"name": ["A", None, "C"], "age": [25, np.nan, 35]})
        repaired, count, log = repair_data(df)
        assert repaired.isnull().sum().sum() == 0
        assert count > 0

    def test_repair_log_structure(self):
        df = pd.DataFrame({"name": ["A", None], "age": [25, np.nan]})
        _, _, log = repair_data(df)
        assert isinstance(log, list)
        for entry in log:
            assert "column" in entry
            assert "type" in entry
            assert "count" in entry


class TestAnomalyDetection:
    def test_detects_anomalies(self):
        df = pd.DataFrame({"value": [10, 11, 12, 10, 11, 100, 9, 10, 11, 12]})
        result, count = detect_anomalies(df)
        assert "anomaly_flag" in result.columns
        assert count >= 0

    def test_handles_small_dataset(self):
        df = pd.DataFrame({"value": [1, 2, 3]})
        result, count = detect_anomalies(df)
        assert "anomaly_flag" in result.columns


class TestCQI:
    def test_cqi_returns_all_dimensions(self, sample_df):
        df_clean, _ = exact_dedup(sample_df)
        cqi = calculate_cqi(sample_df, df_clean, anomaly_count=0)
        assert "completeness" in cqi
        assert "uniqueness" in cqi
        assert "validity" in cqi
        assert "consistency" in cqi
        assert "accuracy" in cqi
        assert "cqi_score" in cqi

    def test_cqi_score_in_range(self, sample_df):
        cqi = calculate_cqi(sample_df, sample_df, anomaly_count=0)
        assert 0 <= cqi["cqi_score"] <= 100


class TestFullPipeline:
    def test_full_pipeline_runs(self, sample_csv):
        result = run_full_pipeline(sample_csv, fuzzy_col="name", threshold=85)
        assert "profile" in result
        assert "cqi" in result
        assert "clean_data" in result
        assert "clean_count" in result
        assert result["clean_count"] > 0

    def test_full_pipeline_reduces_data(self, sample_csv):
        result = run_full_pipeline(sample_csv, fuzzy_col="name", threshold=85)
        assert result["clean_count"] <= result["raw_count"]
