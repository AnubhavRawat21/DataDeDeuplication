// frontend/src/pages/DocsPage.js
import React, { useEffect, useState } from 'react';
import { getEndpoints } from '../api';
import './DocsPage.css';

const METHOD_COLORS = {
  GET: 'badge-emerald',
  POST: 'badge-blue',
  WS: 'badge-accent',
  PUT: 'badge-amber',
  DELETE: 'badge-red',
};

export default function DocsPage() {
  const [endpoints, setEndpoints] = useState([]);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(null);
  const [tryResult, setTryResult] = useState({});

  useEffect(() => {
    getEndpoints()
      .then(r => setEndpoints(r.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const tryEndpoint = async (ep) => {
    if (ep.method !== 'GET') return;
    try {
      const res = await fetch(`http://localhost:8000${ep.path}`);
      const data = await res.json();
      setTryResult(prev => ({ ...prev, [ep.path]: { ok: true, data } }));
    } catch (e) {
      setTryResult(prev => ({ ...prev, [ep.path]: { ok: false, error: e.message } }));
    }
  };

  if (loading) return <div style={{padding:60,textAlign:'center'}}><div className="spinner spinner-lg" style={{margin:'0 auto'}}/></div>;

  return (
    <div className="docs-page">
      <div className="page-header animate-in">
        <div className="page-title">API Explorer</div>
        <div className="page-desc">Interactive documentation for all CloudSieve Pro endpoints</div>
      </div>

      <div className="docs-meta animate-in animate-in-1">
        <div className="meta-item">
          <span className="meta-key">Base URL</span>
          <span className="meta-val mono">http://localhost:8000</span>
        </div>
        <div className="meta-item">
          <span className="meta-key">Endpoints</span>
          <span className="meta-val">{endpoints.length}</span>
        </div>
        <div className="meta-item">
          <span className="meta-key">Docs</span>
          <a href="http://localhost:8000/docs" target="_blank" rel="noreferrer" className="meta-link">Swagger UI →</a>
        </div>
      </div>

      <div className="endpoint-list animate-in animate-in-2">
        {endpoints.map((ep, i) => (
          <div key={i} className={`endpoint-card ${expanded === i ? 'expanded' : ''}`}>
            <div className="ep-header" onClick={() => setExpanded(expanded === i ? null : i)}>
              <span className={`badge ${METHOD_COLORS[ep.method] || 'badge-accent'}`} style={{minWidth:40,justifyContent:'center'}}>
                {ep.method}
              </span>
              <span className="ep-path mono">{ep.path}</span>
              <span className="ep-desc">{ep.description}</span>
              <span className="ep-chevron">{expanded === i ? '−' : '+'}</span>
            </div>

            {expanded === i && (
              <div className="ep-body">
                <div className="ep-detail-row">
                  <span className="ep-detail-key">Full URL</span>
                  <code className="ep-detail-val">http://localhost:8000{ep.path}</code>
                </div>
                <div className="ep-detail-row">
                  <span className="ep-detail-key">Method</span>
                  <span className="ep-detail-val">{ep.method}</span>
                </div>

                {ep.method === 'GET' && !ep.path.includes('{') && (
                  <div style={{marginTop:12}}>
                    <button className="btn btn-secondary" style={{padding:'6px 14px',fontSize:12}}
                      onClick={() => tryEndpoint(ep)}>
                      ▶ Try it
                    </button>
                    {tryResult[ep.path] && (
                      <div className="try-result">
                        <div className={`try-status ${tryResult[ep.path].ok ? 'ok' : 'err'}`}>
                          {tryResult[ep.path].ok ? '200 OK' : 'Error'}
                        </div>
                        <pre className="try-body">
                          {tryResult[ep.path].ok
                            ? JSON.stringify(tryResult[ep.path].data, null, 2)
                            : tryResult[ep.path].error}
                        </pre>
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
