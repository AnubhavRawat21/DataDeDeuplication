// frontend/src/pages/HistoryPage.js
import React, { useEffect, useState } from 'react';
import { getHistory, downloadCleanUrl } from '../api';
import './HistoryPage.css';

export default function HistoryPage() {
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getHistory()
      .then(res => setHistory(res.data))
      .catch(() => setHistory([]))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div style={{padding:60,textAlign:'center'}}><div className="spinner spinner-lg" style={{margin:'0 auto'}}/></div>;

  return (
    <div className="history-page">
      <div className="page-header animate-in">
        <div className="page-title">Run History</div>
        <div className="page-desc">All previously processed pipeline jobs</div>
      </div>

      {history.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon">◷</div>
          <h3>No history yet</h3>
          <p>Previous pipeline runs will appear here.</p>
        </div>
      ) : (
        <div className="history-list">
          {history.map((job, i) => (
            <div key={i} className="history-card animate-in" style={{animationDelay: `${i * 0.05}s`}}>
              <div className="hc-left">
                <div className="hc-id mono">{job.job_id}</div>
                <div className="hc-meta">
                  {job.filename && <span>{job.filename}</span>}
                  {job.uploaded_at && <span className="hc-time">{new Date(job.uploaded_at).toLocaleString()}</span>}
                </div>
              </div>
              <div className="hc-stats">
                {job.clean_records != null && (
                  <div className="hc-stat">
                    <span className="hc-stat-label">Clean</span>
                    <span className="hc-stat-value text-emerald">{job.clean_records}</span>
                  </div>
                )}
                {job.cqi_score != null && (
                  <div className="hc-stat">
                    <span className="hc-stat-label">CQI</span>
                    <span className="hc-stat-value text-accent">{job.cqi_score}</span>
                  </div>
                )}
                {job.elapsed != null && (
                  <div className="hc-stat">
                    <span className="hc-stat-label">Time</span>
                    <span className="hc-stat-value">{job.elapsed}s</span>
                  </div>
                )}
              </div>
              <div className="hc-right">
                <span className={`badge ${job.status === 'complete' ? 'badge-emerald' : job.status === 'error' ? 'badge-red' : 'badge-amber'}`}>
                  {job.status || 'complete'}
                </span>
                <a href={downloadCleanUrl(job.job_id)} className="btn btn-secondary" style={{padding:'6px 12px',fontSize:12}} download>
                  ↓ CSV
                </a>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
