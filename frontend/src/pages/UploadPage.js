// frontend/src/pages/UploadPage.js
import React, { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { useNavigate } from 'react-router-dom';
import { uploadFile, sampleDownloadUrl } from '../api';
import './UploadPage.css';

const PIPELINE_STEPS = [
  { icon: '◎', title: 'Ingest', desc: 'Parse & validate CSV' },
  { icon: '⊘', title: 'Profile', desc: 'Detect nulls & types' },
  { icon: '⊜', title: 'Exact Dedup', desc: 'Remove identical rows' },
  { icon: '⊛', title: 'Fuzzy Dedup', desc: 'Levenshtein matching' },
  { icon: '⊕', title: 'Repair', desc: 'Fix malformed values' },
  { icon: '⊗', title: 'Anomaly ML', desc: 'Isolation Forest' },
  { icon: '◈', title: 'CQI Score', desc: 'Quality index 0–100' },
];

export default function UploadPage({ setJobData }) {
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');
  const [dragHover, setDragHover] = useState(false);
  const navigate = useNavigate();

  const onDrop = useCallback(async (acceptedFiles) => {
    const file = acceptedFiles[0];
    if (!file) return;
    if (!file.name.endsWith('.csv')) {
      setError('Only .csv files are supported.');
      return;
    }
    setUploading(true);
    setError('');
    try {
      const res = await uploadFile(file);
      setJobData(res.data);
      navigate('/pipeline');
    } catch (err) {
      setError(err.response?.data?.detail || 'Upload failed. Is the backend running?');
    } finally {
      setUploading(false);
    }
  }, [setJobData, navigate]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: { 'text/csv': ['.csv'] },
    multiple: false,
    onDragEnter: () => setDragHover(true),
    onDragLeave: () => setDragHover(false),
  });

  return (
    <div className="upload-page">
      <div className="page-header animate-in">
        <div className="page-title">Upload Dataset</div>
        <div className="page-desc">Drop a CSV file to begin the CloudSieve data quality pipeline</div>
      </div>

      {/* ── Dropzone ── */}
      <div className="animate-in animate-in-1">
        <div
          {...getRootProps()}
          className={`dropzone ${isDragActive || dragHover ? 'active' : ''} ${uploading ? 'loading' : ''}`}
        >
          <input {...getInputProps()} />
          {uploading ? (
            <div className="drop-content">
              <div className="spinner spinner-lg" />
              <p className="drop-main">Uploading & analyzing...</p>
              <p className="drop-sub">Detecting encoding and validating structure</p>
            </div>
          ) : isDragActive ? (
            <div className="drop-content">
              <div className="drop-icon-active">↓</div>
              <p className="drop-main">Release to upload</p>
            </div>
          ) : (
            <div className="drop-content">
              <div className="drop-icon-wrapper">
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                  <polyline points="17 8 12 3 7 8"/>
                  <line x1="12" y1="3" x2="12" y2="15"/>
                </svg>
              </div>
              <p className="drop-main">Drag & drop your CSV file here</p>
              <p className="drop-sub">or click to browse</p>
              <div className="drop-formats">
                <span className="format-tag">.csv</span>
                <span className="format-sep">·</span>
                <span className="format-note">Any size, auto-detect encoding</span>
              </div>
            </div>
          )}
        </div>
      </div>

      {error && <div className="error-msg animate-in" style={{marginTop:16}}>{error}</div>}

      {/* ── Sample Data ── */}
      <div className="card animate-in animate-in-2" style={{marginTop:20}}>
        <div className="sample-row">
          <div>
            <div className="sample-title">No dataset? Use sample data</div>
            <div className="sample-desc">Download a pre-built dirty dataset to test the full pipeline</div>
          </div>
          <a href={sampleDownloadUrl} className="btn btn-secondary" download>
            ↓ Download sample_data.csv
          </a>
        </div>
      </div>

      {/* ── Pipeline Steps ── */}
      <div className="animate-in animate-in-3" style={{marginTop:20}}>
        <div className="card-title" style={{marginBottom:16}}>Pipeline stages</div>
        <div className="steps-grid">
          {PIPELINE_STEPS.map((step, i) => (
            <div key={i} className="step-card animate-in" style={{animationDelay: `${0.1 + i*0.05}s`}}>
              <div className="step-num">{i + 1}</div>
              <div className="step-icon">{step.icon}</div>
              <div className="step-title">{step.title}</div>
              <div className="step-desc">{step.desc}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
