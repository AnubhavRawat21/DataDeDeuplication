// frontend/src/pages/InfraPage.js
import React, { useEffect, useState } from 'react';
import { getInfraStatus } from '../api';
import './InfraPage.css';

const RESOURCE_ICONS = {
  docker_network: '⬡', docker_container: '▣', docker_volume: '◧',
};

const SERVICE_ICONS = {
  containerization: '🐳', iac: '⟐', cicd: '⟲', hosting: '☁',
};

const SERVICE_URLS = {
  'Docker': 'https://github.com/aryadhotre/cloudsieve-pro/blob/main/docker/Dockerfile.backend',
  'Terraform': 'https://github.com/aryadhotre/cloudsieve-pro/tree/main/terraform',
  'GitHub Actions': 'https://github.com/aryadhotre/cloudsieve-pro/actions',
  'Render.com': 'https://dashboard.render.com',
};

export default function InfraPage() {
  const [infra, setInfra] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getInfraStatus()
      .then(r => setInfra(r.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div style={{padding:60,textAlign:'center'}}><div className="spinner spinner-lg" style={{margin:'0 auto'}}/></div>;

  const tf = infra?.terraform;
  const services = infra?.services || [];

  return (
    <div className="infra-page">
      <div className="page-header animate-in">
        <div className="page-title">Infrastructure</div>
        <div className="page-desc">Terraform-managed resources and cloud service topology</div>
      </div>

      {/* ── Service Cards ── */}
      <div className="bento-grid bento-4 animate-in animate-in-1" style={{marginBottom:20}}>
        {services.map((svc, i) => {
          const url = SERVICE_URLS[svc.name] || '#';
          return (
            <a key={i} href={url} target="_blank" rel="noopener noreferrer" className="service-card" style={{textDecoration: 'none', color: 'inherit'}}>
              <div className="svc-icon">{SERVICE_ICONS[svc.type] || '◆'}</div>
              <div className="svc-name">{svc.name}</div>
              <span className={`badge ${svc.status === 'active' || svc.status === 'applied' || svc.status === 'passing' || svc.status === 'deployed' ? 'badge-emerald' : 'badge-amber'}`}>
                {svc.status}
              </span>
              <div className="svc-type">{svc.type}</div>
            </a>
          );
        })}
      </div>

      {/* ── Terraform Resource Graph ── */}
      <div className="card animate-in animate-in-2">
        <div className="card-title">Terraform Resource Graph</div>
        <div className="tf-header">
          <span className="badge badge-accent">Terraform {tf?.version}</span>
          <span className="badge badge-blue">Provider: {tf?.provider}</span>
          <span className={`badge ${tf?.state === 'applied' ? 'badge-emerald' : 'badge-amber'}`}>State: {tf?.state}</span>
        </div>

        <div className="resource-graph">
          {/* Central node */}
          <div className="graph-center">
            <div className="graph-hub">
              <span className="hub-icon">⟐</span>
              <span className="hub-label">Terraform</span>
            </div>
          </div>

          {/* Resource nodes */}
          <div className="resource-nodes">
            {tf?.resources?.map((res, i) => (
              <div key={i} className="resource-node animate-in" style={{animationDelay: `${0.1 + i*0.06}s`}}>
                <div className="rn-connector" />
                <div className="rn-card">
                  <div className="rn-icon">{RESOURCE_ICONS[res.type] || '◆'}</div>
                  <div className="rn-info">
                    <div className="rn-name">{res.name}</div>
                    <div className="rn-type mono">{res.type}</div>
                  </div>
                  <span className={`badge ${res.status === 'running' || res.status === 'active' || res.status === 'mounted' ? 'badge-emerald' : 'badge-amber'}`}>
                    {res.status}
                  </span>
                  {res.port && <span className="rn-port mono">:{res.port}</span>}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ── Architecture Overview ── */}
      <div className="card animate-in animate-in-3" style={{marginTop:16}}>
        <div className="card-title">Architecture Overview</div>
        <div className="arch-flow">
          <div className="arch-node">
            <div className="arch-icon">⟡</div>
            <div className="arch-label">Developer</div>
            <div className="arch-sub">git push</div>
          </div>
          <div className="arch-arrow">→</div>
          <div className="arch-node">
            <div className="arch-icon">⟲</div>
            <div className="arch-label">GitHub Actions</div>
            <div className="arch-sub">Lint → Test → Build</div>
          </div>
          <div className="arch-arrow">→</div>
          <div className="arch-node">
            <div className="arch-icon">▣</div>
            <div className="arch-label">Docker</div>
            <div className="arch-sub">Build & Package</div>
          </div>
          <div className="arch-arrow">→</div>
          <div className="arch-node">
            <div className="arch-icon">⟐</div>
            <div className="arch-label">Terraform</div>
            <div className="arch-sub">Provision Infra</div>
          </div>
          <div className="arch-arrow">→</div>
          <div className="arch-node accent">
            <div className="arch-icon">☁</div>
            <div className="arch-label">Render.com</div>
            <div className="arch-sub">Live Deployment</div>
          </div>
        </div>
      </div>
    </div>
  );
}
