// frontend/src/api.js
// CloudSieve Pro — API Layer with WebSocket support

import axios from 'axios';

const BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8001';

const API = axios.create({ baseURL: BASE_URL });

export const uploadFile = (file) => {
  const form = new FormData();
  form.append('file', file);
  return API.post('/upload', form, { headers: { 'Content-Type': 'multipart/form-data' } });
};

export const runPipeline = (jobId, fuzzyCol, threshold) =>
  API.post(`/run/${jobId}`, { fuzzy_col: fuzzyCol, threshold });

export const getJobStatus = (jobId) =>
  API.get(`/job/${jobId}/status`);

export const getJobResults = (jobId) =>
  API.get(`/job/${jobId}/results`);

export const downloadCleanUrl = (jobId) =>
  `${BASE_URL}/download/${jobId}`;

export const sampleDownloadUrl = `${BASE_URL}/sample`;

export const getHistory = () => API.get('/history');
export const getHealth = () => API.get('/health');
export const getDevOpsStatus = () => API.get('/devops/status');
export const getInfraStatus = () => API.get('/infrastructure/status');
export const getEndpoints = () => API.get('/api/endpoints');

// WebSocket connection for real-time pipeline progress
export const createPipelineWS = (jobId, onMessage, onClose) => {
  const wsProtocol = BASE_URL.startsWith('https') ? 'wss://' : 'ws://';
  const wsDomain = BASE_URL.replace(/^https?:\/\//, '');
  const wsUrl = `${wsProtocol}${wsDomain}/ws/pipeline/${jobId}`;
  
  const ws = new WebSocket(wsUrl);
  ws.onmessage = (event) => {
    try { onMessage(JSON.parse(event.data)); } catch(e) {}
  };
  ws.onclose = () => { if (onClose) onClose(); };
  ws.onerror = () => { if (onClose) onClose(); };
  return ws;
};
