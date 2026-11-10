# ☁️ CloudSieve Pro — Enterprise Data Quality Platform

[![CI/CD Pipeline](https://github.com/am4352/cloudsieve-pro/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/am4352/cloudsieve-pro/actions)
[![Live on Render](https://img.shields.io/badge/Render-Live%20Deployment-46E3B7?logo=render&logoColor=white)](https://dashboard.render.com)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://hub.docker.com)
[![Terraform](https://img.shields.io/badge/Terraform-IaC%20Provisioned-844FBA?logo=terraform&logoColor=white)](https://registry.terraform.io)

> **CloudSieve Pro** is a cloud-native, automated **Data Quality Engine** and **CI/CD Platform** inspired by modern Vercel/Stripe minimalist design. It profiles, deduplicates (exact + fuzzy), repairs, anomaly-detects, and scores any CSV dataset with live WebSocket streaming and automated cloud deployment.

📄 **[View FT-III Case Study & Viva Guide](./CASE_STUDY.md)**

---

## 🏗️ System Architecture

```
Developer (git push)
        │
        ▼
GitHub (Version Control)
        │
        ▼
GitHub Actions CI/CD Pipeline
  ├── 🔍 Stage 1: Lint      (flake8 Python + Node build)
  ├── 🧪 Stage 2: Test      (pytest — 15 automated test cases)
  ├── 🐳 Stage 3: Docker    (multi-stage container builds)
  └── 🚀 Stage 4: Deploy    (zero-downtime Render webhook)
        │
        ▼
Render.com Cloud Infrastructure
  ├── cloudsieve-backend   → FastAPI (Python 3.11) Web Service
  └── cloudsieve-frontend  → React Static Site (Global Edge CDN)
        ▲
        │
Terraform (Infrastructure as Code)
  └── Docker network, container specifications, and volume mounts
```

---

## ⚙️ 6-Stage Data Quality Pipeline

1. **Data Profiling**: Instant dataset dimension analysis, type detection, and null rate measurement using vectorized Pandas.
2. **Exact Deduplication**: Vectorized duplicate removal across full record tuples.
3. **Fuzzy Deduplication**: Levenshtein distance string similarity scoring via `rapidfuzz`. Optimized with unique frequency hashing ($O(U^2)$ complexity) for sub-second execution on 100k+ records.
4. **Data Repair**: Automatic numeric median imputation, categorical missing value resolution, age clamping, and email validation.
5. **Anomaly Detection**: Unsupervised outlier isolation using scikit-learn's `IsolationForest` ML model.
6. **CQI (Cloud Quality Index)**: Multi-dimensional composite quality metric (0–100) combining Completeness, Uniqueness, Validity, Consistency, and Accuracy.

---

## 📁 Repository Structure

```
cloudsieve/
├── .github/workflows/
│   └── ci-cd.yml             # 4-stage GitHub Actions workflow
├── backend/
│   ├── main.py               # FastAPI application with WebSockets & health APIs
│   ├── engine.py             # Core data quality algorithms & pipeline
│   ├── requirements.txt      # Python dependencies
│   ├── sample_data.csv       # Test dataset with dirty records
│   └── tests/
│       └── test_pipeline.py  # 15 automated pytest test cases
├── frontend/
│   ├── package.json          # React dependencies
│   ├── src/
│   │   ├── App.js            # Main application shell with navigation
│   │   ├── api.js            # Axios client with dynamic environment URLs & WSS
│   │   ├── index.css         # Minimalist high-contrast design system
│   │   └── pages/
│   │       ├── UploadPage.js # Drag-and-drop CSV upload with live pipeline
│   │       ├── ResultsPage.js# CQI radar charts, metrics & data tables
│   │       ├── DevOpsPage.js # Real-time CI/CD and container monitoring
│   │       └── InfraPage.js  # Interactive Terraform graph & cloud links
├── docker/
│   ├── Dockerfile.backend    # Multi-stage Python 3.11 image
│   ├── Dockerfile.frontend   # Node build + Nginx Alpine runner
│   └── docker-compose.yml    # Local multi-container orchestration
├── terraform/
│   ├── main.tf               # Docker provider resources & networking
│   ├── variables.tf          # Configurable variables
│   └── outputs.tf            # Infrastructure endpoint outputs
├── render.yaml               # Infrastructure blueprint for Render.com
└── CASE_STUDY.md             # Complete FT-III presentation & Viva guide
```

---

## 🚀 Local Development Setup

### 1. Backend (Terminal 1)
```powershell
cd backend
python -m pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```
*API will run on:* `http://localhost:8001`  
*Interactive Swagger docs:* `http://localhost:8001/docs`

### 2. Frontend (Terminal 2)
```powershell
cd frontend
npm install
npm start
```
*Frontend will run on:* `http://localhost:3000`

---

## 🧪 Automated Testing & Quality Checks

Run the automated test suite locally:
```powershell
cd backend
python -m pytest tests/ -v
python -m flake8 main.py engine.py --max-line-length=120
```

---

## ☁️ Cloud, DevOps & Monitoring Services

| Service | Category | Function | Endpoint / Port |
|---|---|---|---|
| **FastAPI Backend** | Application API | Data quality engine, REST APIs & WebSocket | Port `8000` (`/docs`, `/health`) |
| **React Frontend** | Client UI | Responsive dashboard & dataset cleaner | Port `80` & `3000` |
| **Prometheus** | Monitoring | Time-series metrics collection & scraping | Port `9090` |
| **Grafana** | Visualization | Live performance & resource telemetry dashboards | Port `3001` (admin/admin) |
| **Alertmanager** | Alerting | Multi-tier alerting for outages, latency & anomalies | Port `9093` |
| **Node Exporter** | Host Telemetry | Host-level OS metrics (CPU, RAM, disk, network) | Port `9100` (`/metrics`) |
| **Docker Compose** | Container Orchestration | Multi-container microservices management | Root `/docker` |
| **GitHub Actions** | CI/CD Automation | 4-stage pipeline (Lint, Test, Docker Build, Deploy) | `.github/workflows/ci-cd.yml` |

---

## 📊 Monitoring & Alerts Architecture

CloudSieve Pro integrates an enterprise observability stack:
1. **Metrics Scraping**: Prometheus periodically scrapes FastAPI `/metrics`, Node Exporter `/metrics`, and Alertmanager.
2. **Alert Rules**: Pre-configured in `monitoring/prometheus/alert.rules.yml` for:
   - `CloudSieveBackendDown` — triggered if the backend service stops responding.
   - `HighHttpErrorRate` — triggered if 5xx error rate exceeds threshold.
   - `HighRequestLatency` — triggered if p95 latency exceeds 2 seconds.
   - `HostHighCpuLoad` / `HostHighMemoryUsage` / `HostDiskLowSpace` — host saturation alerts.
3. **Alertmanager Routing**: Routes and deduplicates alerts defined in `monitoring/alertmanager/alertmanager.yml`.
4. **Grafana Dashboards**: Automatically provisioned with the `CloudSieve Pro — Overview` dashboard tracking live CQI scores, active jobs, request throughput, and system health.

---

## 📄 Presentation & Viva
For the academic evaluation (FT-III demo), refer to **[CASE_STUDY.md](./CASE_STUDY.md)** for:
- Problem identification & cloud design justification
- Technical execution details & networking/security
- Performance benchmarks (100k records in < 2s) and cost analysis ($0/mo)
- Viva questions with model answers
