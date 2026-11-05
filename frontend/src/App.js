// frontend/src/App.js
// CloudSieve Pro — App Shell with Top Navigation

import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, NavLink, useLocation } from 'react-router-dom';
import { getHealth } from './api';
import UploadPage from './pages/UploadPage';
import PipelinePage from './pages/PipelinePage';
import ResultsPage from './pages/ResultsPage';
import HistoryPage from './pages/HistoryPage';
import DevOpsPage from './pages/DevOpsPage';
import InfraPage from './pages/InfraPage';
import DocsPage from './pages/DocsPage';
import './App.css';

const NAV_ITEMS = [
  { to: '/',           label: 'Upload',     icon: '↑' },
  { to: '/pipeline',   label: 'Pipeline',   icon: '⬡' },
  { to: '/results',    label: 'Results',     icon: '◈' },
  { to: '/history',    label: 'History',     icon: '◷' },
  { to: '/devops',     label: 'DevOps',      icon: '⟲' },
  { to: '/infra',      label: 'Infrastructure', icon: '◆' },
  { to: '/docs',       label: 'API',         icon: '⟡' },
];

function PageTransition({ children }) {
  const location = useLocation();
  const [show, setShow] = useState(false);
  useEffect(() => { setShow(false); requestAnimationFrame(() => setShow(true)); }, [location.pathname]);
  return <div className={`page-transition ${show ? 'visible' : ''}`}>{children}</div>;
}

export default function App() {
  const [jobData, setJobData] = useState(null);
  const [results, setResults] = useState(null);
  const [apiOk, setApiOk] = useState(false);

  useEffect(() => {
    const check = () => getHealth().then(() => setApiOk(true)).catch(() => setApiOk(false));
    check();
    const interval = setInterval(check, 15000);
    return () => clearInterval(interval);
  }, []);

  return (
    <BrowserRouter>
      <div className="app-root">
        {/* ── Top Navbar ── */}
        <header className="topnav">
          <div className="topnav-inner">
            <NavLink to="/" className="topnav-brand">
              <div className="brand-icon">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                  <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" stroke="url(#g)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <defs><linearGradient id="g" x1="2" y1="2" x2="22" y2="22"><stop stopColor="#7C3AED"/><stop offset="1" stopColor="#3B82F6"/></linearGradient></defs>
                </svg>
              </div>
              <span className="brand-text">CloudSieve</span>
              <span className="brand-badge">PRO</span>
            </NavLink>

            <nav className="topnav-links">
              {NAV_ITEMS.map(item => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.to === '/'}
                  className={({isActive}) => `nav-link ${isActive ? 'active' : ''}`}
                >
                  {item.label}
                </NavLink>
              ))}
            </nav>

            <div className="topnav-right">
              <div className={`status-pill ${apiOk ? 'online' : 'offline'}`}>
                <span className="status-dot" />
                <span>{apiOk ? 'Connected' : 'Offline'}</span>
              </div>
              <span className="version-label">v2.0</span>
            </div>
          </div>
        </header>

        {/* ── Main Content ── */}
        <main className="main">
          <div className="main-inner">
            <PageTransition>
              <Routes>
                <Route path="/"         element={<UploadPage setJobData={setJobData} />} />
                <Route path="/pipeline" element={<PipelinePage jobData={jobData} setResults={setResults} />} />
                <Route path="/results"  element={<ResultsPage results={results} jobData={jobData} />} />
                <Route path="/history"  element={<HistoryPage />} />
                <Route path="/devops"   element={<DevOpsPage />} />
                <Route path="/infra"    element={<InfraPage />} />
                <Route path="/docs"     element={<DocsPage />} />
              </Routes>
            </PageTransition>
          </div>
        </main>

        {/* ── Footer ── */}
        <footer className="app-footer">
          <span>CloudSieve Pro · Built with FastAPI + React + Docker + Terraform</span>
          <span className="footer-links">
            <a href="http://localhost:8000/docs" target="_blank" rel="noreferrer">Swagger</a>
            <span className="footer-dot">·</span>
            <a href="http://localhost:8000/health" target="_blank" rel="noreferrer">Health</a>
          </span>
        </footer>
      </div>
    </BrowserRouter>
  );
}
