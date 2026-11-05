// frontend/src/pages/ResultsPage.js
import React, { useState } from 'react';
import { downloadCleanUrl } from '../api';
import {
  RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis,
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell
} from 'recharts';
import './ResultsPage.css';

const CQI_COLOR = (s) => s >= 80 ? '#10B981' : s >= 60 ? '#F59E0B' : '#EF4444';

export default function ResultsPage({ results, jobData }) {
  const [tab, setTab] = useState('overview');

  if (!results) return (
    <div className="empty-state">
      <div className="empty-icon">◈</div>
      <h3>No results yet</h3>
      <p>Upload a file and run the pipeline first.</p>
    </div>
  );

  const { profile, cqi, exact_removed, fuzzy_removed, total_repairs,
          anomaly_count, raw_count, clean_count, clean_data, columns,
          fuzzy_matches, repair_log } = results;

  const radarData = [
    { dim: 'Completeness', val: cqi.completeness },
    { dim: 'Uniqueness',   val: cqi.uniqueness },
    { dim: 'Validity',     val: cqi.validity },
    { dim: 'Consistency',  val: cqi.consistency },
    { dim: 'Accuracy',     val: cqi.accuracy },
  ];

  const barData = [
    { name: 'Exact Dups', value: exact_removed, fill: '#8B5CF6' },
    { name: 'Fuzzy Dups', value: fuzzy_removed, fill: '#3B82F6' },
    { name: 'Repairs',    value: total_repairs, fill: '#F59E0B' },
    { name: 'Anomalies',  value: anomaly_count, fill: '#EF4444' },
  ];

  const cqiColor = CQI_COLOR(cqi.cqi_score);
  const TABS = ['overview', 'data', 'fuzzy', 'repairs'];

  return (
    <div className="results-page">
      <div className="page-header animate-in" style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start'}}>
        <div>
          <div className="page-title">Pipeline Results</div>
          <div className="page-desc">
            Job <span className="mono">{jobData?.job_id}</span> · {jobData?.filename}
          </div>
        </div>
        <a href={downloadCleanUrl(jobData?.job_id)} className="btn btn-primary" download>
          ↓ Download Clean CSV
        </a>
      </div>

      {/* ── CQI Hero ── */}
      <div className="cqi-hero animate-in animate-in-1">
        <div className="cqi-left">
          <div className="cqi-label">Cloud Quality Index</div>
          <div className="cqi-score-row">
            <span className="cqi-score" style={{color: cqiColor}}>{cqi.cqi_score}</span>
            <span className="cqi-max">/100</span>
          </div>
          <div className="progress-bg" style={{marginTop:12}}>
            <div className="progress-fill" style={{width:`${cqi.cqi_score}%`, background: cqiColor}} />
          </div>
          <div className="cqi-verdict" style={{color: cqiColor}}>
            {cqi.cqi_score >= 80 ? '✓ Excellent Data Quality'
              : cqi.cqi_score >= 60 ? '⚠ Acceptable Quality'
              : '✕ Poor Quality — Action Required'}
          </div>
        </div>
        <div className="cqi-right">
          <ResponsiveContainer width="100%" height={200}>
            <RadarChart data={radarData}>
              <PolarGrid stroke="rgba(255,255,255,0.06)" />
              <PolarAngleAxis dataKey="dim" tick={{fill:'var(--text-m)',fontSize:11}} />
              <PolarRadiusAxis domain={[0,100]} tick={false} axisLine={false} />
              <Radar dataKey="val" stroke={cqiColor} fill={cqiColor} fillOpacity={0.15} strokeWidth={2} />
            </RadarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* ── Stats ── */}
      <div className="bento-grid bento-4 animate-in animate-in-2" style={{marginBottom:20}}>
        <div className="stat-card"><div className="stat-label">Raw Records</div><div className="stat-value">{raw_count}</div></div>
        <div className="stat-card"><div className="stat-label">Clean Records</div><div className="stat-value text-emerald">{clean_count}</div></div>
        <div className="stat-card"><div className="stat-label">Total Removed</div><div className="stat-value text-amber">{raw_count - clean_count}</div></div>
        <div className="stat-card"><div className="stat-label">Records Repaired</div><div className="stat-value text-blue">{total_repairs}</div></div>
      </div>

      {/* ── Tabs ── */}
      <div className="tabs animate-in animate-in-3">
        {TABS.map(t => (
          <button key={t} className={`tab-btn ${tab === t ? 'active' : ''}`} onClick={() => setTab(t)}>
            {t === 'overview' ? 'Overview' : t === 'data' ? 'Clean Data' : t === 'fuzzy' ? 'Fuzzy Matches' : 'Repair Log'}
          </button>
        ))}
      </div>

      {/* ── Overview ── */}
      {tab === 'overview' && (
        <div className="bento-grid bento-2 animate-in">
          <div className="card">
            <div className="card-title">Issues Resolved</div>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={barData}>
                <XAxis dataKey="name" tick={{fill:'var(--text-m)',fontSize:11}} axisLine={false} tickLine={false} />
                <YAxis tick={{fill:'var(--text-m)',fontSize:11}} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={{background:'var(--bg-s)',border:'1px solid var(--border)',borderRadius:8,fontSize:12}} />
                <Bar dataKey="value" radius={[4,4,0,0]}>
                  {barData.map((e, i) => <Cell key={i} fill={e.fill} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="card">
            <div className="card-title">Quality Dimensions</div>
            <div className="dims">
              {radarData.map(d => (
                <div key={d.dim} className="dim-row">
                  <span className="dim-name">{d.dim}</span>
                  <div className="progress-bg" style={{flex:1}}>
                    <div className="progress-fill" style={{width:`${d.val}%`, background: CQI_COLOR(d.val)}} />
                  </div>
                  <span className="dim-val mono" style={{color: CQI_COLOR(d.val)}}>{d.val}%</span>
                </div>
              ))}
            </div>
          </div>

          <div className="card" style={{gridColumn:'1 / -1'}}>
            <div className="card-title">Column Profile</div>
            <div className="table-wrap">
              <table className="data-table">
                <thead><tr><th>Column</th><th>Type</th><th>Nulls</th><th>Null Rate</th><th>Unique</th><th>Status</th></tr></thead>
                <tbody>
                  {profile?.columns?.map((col, i) => (
                    <tr key={i}>
                      <td><span className="mono">{col.column}</span></td>
                      <td><span className="badge badge-accent">{col.dtype}</span></td>
                      <td>{col.null_count}</td>
                      <td>{col.null_rate}%</td>
                      <td>{col.unique_count}</td>
                      <td>{col.null_count === 0
                        ? <span className="badge badge-emerald">Clean</span>
                        : <span className="badge badge-amber">Has Nulls</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ── Clean Data ── */}
      {tab === 'data' && (
        <div className="card animate-in">
          <div className="card-title">Clean Data Preview (top 50 rows)</div>
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr>{columns?.map(c => <th key={c}>{c}</th>)}</tr></thead>
              <tbody>
                {clean_data?.map((row, i) => (
                  <tr key={i}>
                    {columns?.map(c => (
                      <td key={c}>
                        {c === 'anomaly_flag'
                          ? <span className={`badge ${row[c]?.includes?.('Anomaly') ? 'badge-red' : 'badge-emerald'}`}>{row[c]}</span>
                          : String(row[c] ?? '')}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── Fuzzy ── */}
      {tab === 'fuzzy' && (
        <div className="card animate-in">
          <div className="card-title">Fuzzy Matches ({fuzzy_matches?.length || 0})</div>
          {!fuzzy_matches?.length ? <p style={{color:'var(--text-m)',fontSize:13}}>No fuzzy duplicates found above the threshold.</p> : (
            <div className="table-wrap">
              <table className="data-table">
                <thead><tr><th>Original</th><th>Duplicate</th><th>Similarity</th></tr></thead>
                <tbody>
                  {fuzzy_matches?.map((m, i) => (
                    <tr key={i}>
                      <td>{m.original}</td>
                      <td style={{color:'var(--red)'}}>{m.duplicate}</td>
                      <td><span className="mono" style={{color: m.similarity >= 90 ? 'var(--red)' : 'var(--amber)'}}>{m.similarity}%</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ── Repairs ── */}
      {tab === 'repairs' && (
        <div className="card animate-in">
          <div className="card-title">Repair Log ({repair_log?.length || 0} operations)</div>
          {!repair_log?.length ? <p style={{color:'var(--text-m)',fontSize:13}}>No repairs needed — data was clean!</p> : (
            <div className="table-wrap">
              <table className="data-table">
                <thead><tr><th>Column</th><th>Repair Type</th><th>Records Fixed</th></tr></thead>
                <tbody>
                  {repair_log?.map((r, i) => (
                    <tr key={i}>
                      <td><span className="mono">{r.column}</span></td>
                      <td><span className="badge badge-amber">{r.type?.replace(/_/g,' ')}</span></td>
                      <td>{r.count}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
