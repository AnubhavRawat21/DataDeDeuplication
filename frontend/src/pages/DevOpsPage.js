// frontend/src/pages/DevOpsPage.js
import React, { useEffect, useState } from 'react';
import { getDevOpsStatus, getHealth } from '../api';
import './DevOpsPage.css';

export default function DevOpsPage() {
  const [devops, setDevops] = useState(null);
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      getDevOpsStatus().then(r => setDevops(r.data)).catch(() => {}),
      getHealth().then(r => setHealth(r.data)).catch(() => {}),
    ]).finally(() => setLoading(false));
  }, []);

  if (loading) return <div style={{padding:60,textAlign:'center'}}><div className="spinner spinner-lg" style={{margin:'0 auto'}}/></div>;

  const pipeline = devops?.pipeline;
  const containers = devops?.docker?.containers || [];
  const deployments = devops?.deployments || [];

  return (
    <div className="devops-page">
      <div className="page-header animate-in">
        <div className="page-title">DevOps Dashboard</div>
        <div className="page-desc">CI/CD pipeline status, container health, and deployment history</div>
      </div>

      {/* ── CI/CD Pipeline Visualization ── */}
      <div className="card animate-in animate-in-1">
        <div className="card-title">CI/CD Pipeline · {pipeline?.provider}</div>
        <div className="cicd-pipeline">
          {pipeline?.stages?.map((stage, i) => (
            <React.Fragment key={i}>
              {i > 0 && <div className="cicd-connector"><div className="cicd-line" /></div>}
              <div className={`cicd-stage ${stage.status}`}>
                <div className="cicd-node">
                  {stage.status === 'passed' ? (
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                  ) : stage.status === 'running' ? (
                    <div className="spinner" style={{width:16,height:16,borderWidth:2}} />
                  ) : (
                    <div style={{width:8,height:8,borderRadius:'50%',background:'currentColor'}} />
                  )}
                </div>
                <div className="cicd-label">{stage.name}</div>
                <div className="cicd-duration mono">{stage.duration}</div>
              </div>
            </React.Fragment>
          ))}
        </div>
        <div className="pipeline-status-bar">
          <span className={`badge ${pipeline?.status === 'passing' ? 'badge-emerald' : 'badge-red'}`}>
            {pipeline?.status === 'passing' ? '✓ All checks passed' : '✕ Pipeline failed'}
          </span>
        </div>
      </div>

      <div className="bento-grid bento-2" style={{marginTop:16}}>
        {/* ── Container Status ── */}
        <div className="card animate-in animate-in-2">
          <div className="card-title">Docker Containers</div>
          <div className="container-list">
            {containers.map((c, i) => (
              <div key={i} className="container-card">
                <div className="cc-header">
                  <span className="cc-name">{c.name}</span>
                  <span className={`badge ${c.status === 'running' ? 'badge-emerald' : 'badge-red'}`}>{c.status}</span>
                </div>
                <div className="cc-details">
                  <div className="cc-detail"><span className="cc-key">Image</span><span className="cc-val mono">{c.image}</span></div>
                  <div className="cc-detail"><span className="cc-key">Port</span><span className="cc-val mono">:{c.port}</span></div>
                  <div className="cc-detail"><span className="cc-key">Uptime</span><span className="cc-val">{c.uptime}</span></div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* ── System Health ── */}
        <div className="card animate-in animate-in-3">
          <div className="card-title">System Health</div>
          {health ? (
            <div className="health-grid">
              <div className="health-item">
                <span className="health-key">Status</span>
                <span className="badge badge-emerald">{health.status}</span>
              </div>
              <div className="health-item">
                <span className="health-key">Version</span>
                <span className="health-val mono">{health.version}</span>
              </div>
              <div className="health-item">
                <span className="health-key">Uptime</span>
                <span className="health-val">{health.uptime_human}</span>
              </div>
              <div className="health-item">
                <span className="health-key">Platform</span>
                <span className="health-val">{health.platform}</span>
              </div>
              <div className="health-item">
                <span className="health-key">Python</span>
                <span className="health-val mono">{health.python}</span>
              </div>
              <div className="health-item">
                <span className="health-key">Active Jobs</span>
                <span className="health-val">{health.active_jobs}</span>
              </div>
              <div className="health-item">
                <span className="health-key">Total Processed</span>
                <span className="health-val">{health.total_jobs_processed}</span>
              </div>
              <div className="health-item">
                <span className="health-key">Uploads</span>
                <span className="health-val">{health.storage?.uploads}</span>
              </div>
            </div>
          ) : <p style={{color:'var(--text-m)'}}>Could not load health data.</p>}
        </div>
      </div>

      {/* ── Deployments ── */}
      <div className="card animate-in animate-in-4" style={{marginTop:16}}>
        <div className="card-title">Recent Deployments</div>
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>ID</th><th>Commit</th><th>Status</th><th>Environment</th><th>Timestamp</th></tr></thead>
            <tbody>
              {deployments.map((d, i) => (
                <tr key={i}>
                  <td><span className="mono">{d.id}</span></td>
                  <td><span className="mono">{d.commit}</span></td>
                  <td><span className={`badge ${d.status === 'live' ? 'badge-emerald' : 'badge-amber'}`}>{d.status}</span></td>
                  <td>{d.environment}</td>
                  <td className="mono" style={{fontSize:11}}>{new Date(d.timestamp).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
