// frontend/src/pages/PipelinePage.js
import React, { useState, useRef, useCallback, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { runPipeline, createPipelineWS, getJobResults } from '../api';
import './PipelinePage.css';

const STAGES = [
  { key: 'profiling',   label: 'Data Profiling',       color: '#3B82F6' },
  { key: 'exact_dedup', label: 'Exact Deduplication',   color: '#8B5CF6' },
  { key: 'fuzzy_dedup', label: 'Fuzzy Deduplication',   color: '#10B981' },
  { key: 'repair',      label: 'Data Repair',           color: '#F59E0B' },
  { key: 'anomaly',     label: 'Anomaly Detection',     color: '#F43F5E' },
  { key: 'cqi',         label: 'CQI Scoring',           color: '#06B6D4' },
];

export default function PipelinePage({ jobData, setResults }) {
  const [fuzzyCol, setFuzzyCol] = useState('');
  const [threshold, setThreshold] = useState(85);
  const [running, setRunning] = useState(false);
  const [currentStage, setCurrentStage] = useState(-1);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');
  const [elapsed, setElapsed] = useState(0);
  const wsRef = useRef(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (jobData?.columns?.length > 0 && !fuzzyCol) {
      const nameCol = jobData.columns.find(c => c.toLowerCase().includes('name'));
      setFuzzyCol(nameCol || jobData.columns[0]);
    }
  }, [jobData, fuzzyCol]);

  const pollResults = useCallback(async (jobId) => {
    let attempts = 0;
    const poll = async () => {
      try {
        const res = await getJobResults(jobId);
        if (res.data && res.data.status !== 'running') {
          setResults(res.data);
          setDone(true);
          setRunning(false);
          setTimeout(() => navigate('/results'), 600);
          return;
        }
      } catch(e) {}
      attempts++;
      if (attempts < 30) setTimeout(poll, 1000);
    };
    setTimeout(poll, 2000);
  }, [setResults, navigate]);

  const handleRun = async () => {
    if (!jobData) return;
    setRunning(true);
    setDone(false);
    setError('');
    setCurrentStage(0);
    setElapsed(0);

    try {
      await runPipeline(jobData.job_id, fuzzyCol, threshold);

      // Connect WebSocket for progress
      const ws = createPipelineWS(
        jobData.job_id,
        (msg) => {
          if (msg.status === 'running') {
            setCurrentStage(msg.current_stage || 0);
            setElapsed(msg.elapsed || 0);
          } else if (msg.status === 'complete') {
            setCurrentStage(STAGES.length);
            ws.close();
          } else if (msg.status === 'error') {
            setError(msg.error || 'Pipeline failed');
            setRunning(false);
            ws.close();
          }
        },
        () => { /* onClose — fetch results */ }
      );
      wsRef.current = ws;

      // Also poll for results as fallback
      pollResults(jobData.job_id);

    } catch (err) {
      setError(err.response?.data?.detail || 'Pipeline failed. Check backend logs.');
      setRunning(false);
    }
  };

  useEffect(() => { return () => { if (wsRef.current) wsRef.current.close(); }; }, []);

  if (!jobData) return (
    <div className="empty-state">
      <div className="empty-icon">⬡</div>
      <h3>No file uploaded</h3>
      <p>Upload a CSV file first to configure the pipeline.</p>
    </div>
  );

  return (
    <div className="pipeline-page">
      <div className="page-header animate-in">
        <div className="page-title">Configure Pipeline</div>
        <div className="page-desc">Tune settings and run CloudSieve on your dataset</div>
      </div>

      <div className="pipeline-layout">
        {/* ── Left: Settings ── */}
        <div className="pipeline-settings">
          {/* File Info */}
          <div className="card animate-in animate-in-1">
            <div className="card-title">Dataset</div>
            <div className="info-grid">
              <div className="info-item">
                <span className="info-label">File</span>
                <span className="info-value mono">{jobData.filename}</span>
              </div>
              <div className="info-item">
                <span className="info-label">Records</span>
                <span className="info-value text-blue">{jobData.rows?.toLocaleString()}</span>
              </div>
              <div className="info-item">
                <span className="info-label">Columns</span>
                <span className="info-value">{jobData.columns?.length}</span>
              </div>
              <div className="info-item">
                <span className="info-label">Job ID</span>
                <span className="info-value mono" style={{fontSize:12}}>{jobData.job_id}</span>
              </div>
            </div>
            <div className="col-tags" style={{marginTop:12}}>
              {jobData.columns?.map(col => (
                <span key={col} className="col-tag">{col}</span>
              ))}
            </div>
          </div>

          {/* Settings */}
          <div className="card animate-in animate-in-2">
            <div className="card-title">Settings</div>
            <div className="setting">
              <label className="setting-label">Fuzzy Match Column</label>
              <select value={fuzzyCol} onChange={e => setFuzzyCol(e.target.value)} className="setting-select">
                {jobData.columns?.map(col => (
                  <option key={col} value={col}>{col}</option>
                ))}
              </select>
              <p className="setting-hint">Column to apply Levenshtein distance matching</p>
            </div>
            <div className="setting" style={{marginTop:16}}>
              <label className="setting-label">
                Similarity Threshold <span className="threshold-val">{threshold}%</span>
              </label>
              <input type="range" min="60" max="100" step="5" value={threshold}
                onChange={e => setThreshold(Number(e.target.value))} className="setting-range" />
              <p className="setting-hint">
                {threshold >= 90 ? 'Very strict — near-identical matches only'
                  : threshold >= 80 ? 'Balanced — recommended for most datasets'
                  : 'Lenient — catches more but may over-match'}
              </p>
            </div>
          </div>

          {/* Run Button */}
          <div className="animate-in animate-in-3">
            <button className="btn btn-primary run-btn" onClick={handleRun} disabled={running}>
              {running ? (
                <><div className="spinner" style={{width:16,height:16,borderWidth:2}} /> Running Pipeline...</>
              ) : '▶ Run CloudSieve Pipeline'}
            </button>
          </div>

          {error && <div className="error-msg" style={{marginTop:12}}>{error}</div>}
          {done && (
            <div className="success-msg animate-in" style={{marginTop:12}}>
              ✓ Pipeline complete — redirecting to results...
            </div>
          )}
        </div>

        {/* ── Right: Stage Tracker ── */}
        <div className="pipeline-tracker animate-in animate-in-2">
          <div className="card-title">Pipeline Stages</div>
          {running && <div className="elapsed-timer mono">{elapsed.toFixed(1)}s</div>}
          <div className="stages">
            {STAGES.map((stage, i) => {
              const state = !running && !done ? 'idle'
                : done ? 'done'
                : i < currentStage ? 'done'
                : i === currentStage ? 'active'
                : 'pending';
              return (
                <div key={stage.key} className={`stage ${state}`}>
                  <div className="stage-connector" style={i === 0 ? {opacity:0} : {}} />
                  <div className="stage-node" style={state === 'active' || state === 'done' ? {borderColor: stage.color, boxShadow: `0 0 12px ${stage.color}33`} : {}}>
                    {state === 'done' ? (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={stage.color} strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg>
                    ) : state === 'active' ? (
                      <div className="spinner" style={{width:14,height:14,borderWidth:2,borderTopColor:stage.color}} />
                    ) : (
                      <div className="stage-dot" />
                    )}
                  </div>
                  <div className="stage-info">
                    <div className="stage-label">{stage.label}</div>
                    <div className="stage-status">
                      {state === 'done' ? <span className="badge badge-emerald">Done</span>
                        : state === 'active' ? <span className="badge badge-blue">Running</span>
                        : state === 'pending' ? <span className="badge" style={{background:'var(--bg-t)',color:'var(--text-m)'}}>Queued</span>
                        : <span className="badge" style={{background:'var(--bg-t)',color:'var(--text-m)'}}>Idle</span>}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
