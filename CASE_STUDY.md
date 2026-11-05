# CloudSieve Pro — FT-III Case Study Guide
## *Enterprise Data Quality Pipeline with Full CI/CD on Cloud*

---

## SECTION 1 — Problem Analysis & Cloud Design *(2 Marks)*

### Problem Identification
Organizations store massive datasets (CRM records, sensor logs, transactional data) that suffer from:
- **Incompleteness** — missing/null values corrupt analytics
- **Duplication** — exact and fuzzy/near-duplicate records waste storage and distort results
- **Anomalies** — statistical outliers skew machine learning models
- **No Quality Score** — no way to quantify or audit data trustworthiness

Manual data cleaning is slow, error-prone, and doesn't scale. Traditional SQL/Excel tools lack automation, cloud integration, and versioning.

### Solution: CloudSieve Pro
A cloud-native, automated **Data Quality Engine** that profiles, deduplicates, repairs, anomaly-detects, and scores any CSV dataset through a fully automated CI/CD pipeline — deployed live on the internet.

### Cloud Architecture

```
Developer (git push)
        ↓
GitHub (Source Control — Public Repo)
        ↓
GitHub Actions CI/CD Pipeline
  ├─ 🔍 Stage 1: Lint      (flake8 Python + Node build)
  ├─ 🧪 Stage 2: Test      (pytest — 15 automated test cases)
  ├─ 🐳 Stage 3: Docker    (build backend + frontend images)
  └─ 🚀 Stage 4: Deploy    (auto-trigger Render.com webhook)
        ↓
Render.com Cloud Platform
  ├─ cloudsieve-backend  →  FastAPI (Python 3.11) Web Service
  └─ cloudsieve-frontend →  React Static Site on Global CDN
        ↑
Terraform (Infrastructure as Code)
  └─ Defines containers, networks, volumes in main.tf
```

### IaaS / PaaS / SaaS Classification
| Service | Type | Role in CloudSieve |
|---|---|---|
| **Docker** | IaaS | Containerizes backend & frontend for reproducible deployments |
| **Terraform** | IaaS | Provisions containers, networks, volumes as code |
| **GitHub Actions** | PaaS | Runs the automated 4-stage CI/CD pipeline |
| **Render.com** | PaaS | Hosts the live cloud application with zero-downtime deploys |
| **FastAPI API** | SaaS | The data quality engine service consumed by the frontend |
| **React UI** | SaaS | Complete end-user SaaS product for data cleaning |

---

## SECTION 2 — Implementation & Technical Execution *(4 Marks)*

### 6-Stage Data Pipeline (engine.py)

| Stage | What It Does | Algorithm / Library |
|---|---|---|
| **1. Profiling** | Analyzes schema, null counts, data types, unique values | Pandas vectorized operations |
| **2. Exact Dedup** | Removes 100% identical duplicate rows | `df.drop_duplicates()` |
| **3. Fuzzy Dedup** | Removes near-duplicate strings (e.g. "Jon" vs "John") | `rapidfuzz` — Levenshtein distance |
| **4. Data Repair** | Fills nulls (median for numbers, "Unknown" for text), fixes invalid ages & emails | Pandas `.fillna()`, regex |
| **5. Anomaly Detection** | Flags statistical outliers in numeric columns | `sklearn IsolationForest` (unsupervised ML) |
| **6. CQI Scoring** | Generates a 0–100 Cloud Quality Index score | 5-dimension composite formula |

**CQI Formula:**
```
CQI = (Completeness + Uniqueness + Validity + Consistency + Accuracy) / 5 × 100
```

### CI/CD Pipeline (`.github/workflows/ci-cd.yml`)
Triggered automatically on every `git push to main`:
1. **Lint** — `flake8` checks Python code quality
2. **Test** — `pytest` runs 15 test cases covering all 6 pipeline stages
3. **Docker Build** — Builds `cloudsieve-backend` and `cloudsieve-frontend` images
4. **Deploy** — Calls Render.com webhook to trigger zero-downtime redeploy

### Docker Configuration
- **`Dockerfile.backend`** — Python 3.11 Alpine → installs `requirements.txt` → runs uvicorn
- **`Dockerfile.frontend`** — Node 18 Alpine (builds React) → Nginx Alpine (serves production bundle)
- Nginx handles all SPA routing with `try_files` rewrite rules

### Terraform (`terraform/main.tf`)
Provisions complete Docker infrastructure as code:
- `docker_network` — Isolated bridge network for inter-container communication
- `docker_container` (backend) — FastAPI on port 8001 with volume mounts
- `docker_container` (frontend) — Nginx on port 3000
- `docker_volume` (uploads, outputs) — Persistent storage across container restarts

### Backend API Endpoints (`main.py`)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Health check — uptime, active jobs, storage stats |
| POST | `/upload` | Upload CSV → returns `job_id` + preview |
| POST | `/run/{job_id}` | Start pipeline in background thread |
| GET | `/job/{job_id}/status` | Poll pipeline progress |
| WS | `/ws/pipeline/{job_id}` | WebSocket real-time stage updates |
| GET | `/download/{job_id}` | Download cleaned CSV |
| GET | `/devops/status` | CI/CD pipeline status for DevOps page |
| GET | `/infrastructure/status` | Terraform resource status for Infra page |

### Security & Networking
- CORS middleware on FastAPI with wildcard `*` (dev) / specific origin (prod)
- Environment variable `REACT_APP_API_URL` isolates prod from localhost config
- `wss://` (secure WebSocket) used automatically on HTTPS Render deployment
- Render provides automatic free SSL certificates

---

## SECTION 3 — Results & Technical Evaluation *(2 Marks)*

### Performance Benchmarks
| Dataset Size | Total Pipeline Time |
|---|---|
| 1,000 rows | ~0.05 seconds |
| 10,000 rows | ~0.2 seconds |
| 50,000 rows | ~0.19 seconds |
| 100,000 rows | **< 2 seconds** |

### Key Optimization Achievement
The fuzzy deduplication algorithm was originally **O(N²)** — comparing every row against every other row.
- 10,000 rows = 50 million comparisons = **5+ minutes**
- Fixed by switching to **O(U²)** — comparing only unique values (capped at 2000)
- 100,000 rows now processes in **< 1 second**

### Scalability Design
- **Stateless API** — each job uses a UUID; any number of users can run jobs simultaneously
- **Containerized** — Docker containers can be replicated behind a load balancer instantly
- **CDN Frontend** — React static site served globally from Render's edge nodes

### Cost Analysis
| Resource | Service | Monthly Cost |
|---|---|---|
| Backend server | Render Free Tier | **\$0** |
| Frontend hosting | Render Static Site | **\$0** |
| CI/CD pipeline | GitHub Actions (2000 free min/month) | **\$0** |
| Source control | GitHub Public Repository | **\$0** |
| **Total Running Cost** | | **\$0 / month** |

> The entire production-grade platform runs at **zero cost** — demonstrating that modern cloud-native architecture using free tiers can deliver enterprise capabilities without any infrastructure investment.

---

## SECTION 4 — VIVA Preparation

### Q: What is CloudSieve Pro?
> CloudSieve Pro is a cloud-native automated data quality platform. It takes any dirty CSV file, runs it through a 6-stage pipeline (profiling → exact dedup → fuzzy dedup → repair → anomaly detection → CQI scoring), and returns a cleaned file with a quality score between 0 and 100.

### Q: What cloud services did you use and why?
> We used GitHub Actions (PaaS) for CI/CD automation, Docker (IaaS) for containerization, Terraform (IaaS) for infrastructure-as-code, and Render.com (PaaS) for live cloud hosting. This stack gives us automated deployments, reproducible environments, and zero infrastructure management overhead.

### Q: What is the CQI score?
> CQI stands for Cloud Quality Index. It is a composite score from 0–100 calculated across 5 dimensions: Completeness (null coverage), Uniqueness (duplicate ratio), Validity (anomaly rate), Consistency (column distribution), and Accuracy (combined measure). It gives a single number that quantifies overall data trustworthiness.

### Q: What is Docker and why use it here?
> Docker packages the application code along with all its dependencies (Python, libraries, OS) into a portable container. This guarantees the app behaves identically on my laptop, the GitHub Actions server, and the Render cloud — eliminating "works on my machine" issues.

### Q: What is Terraform?
> Terraform is Infrastructure-as-Code. Instead of clicking buttons in a dashboard to create servers, we write `.tf` files that define the infrastructure. Terraform reads the file and automatically provisions the Docker network, containers, and storage volumes with a single `terraform apply` command.

### Q: How does the CI/CD pipeline work end-to-end?
> I write code → push to GitHub → GitHub Actions automatically runs: (1) Lint to check code quality, (2) Test to run 15 automated pytest cases, (3) Docker Build to create production images, (4) Deploy to send a webhook to Render which automatically swaps in the new version with zero downtime.

### Q: What algorithm is used for fuzzy deduplication?
> We use the Levenshtein distance algorithm via the `rapidfuzz` library. It computes string similarity as a percentage. Records above the threshold (default 85%) are flagged as near-duplicates. We optimized the algorithm from O(N²) brute force to O(U²) unique-set matching, reducing 100k record processing from hours to under 1 second.

### Q: How is anomaly detection implemented?
> We use scikit-learn's `IsolationForest` — an unsupervised ML algorithm. It works by randomly partitioning the data; points that get isolated in fewer splits are statistical outliers. We set contamination=0.1 meaning it expects up to 10% of points to be anomalies.

---

## Recommended Demo Flow

1. **GitHub repo** → show folder structure (backend, frontend, docker, terraform, .github/workflows)
2. **GitHub Actions** → click latest green pipeline run → walk through all 4 stages
3. **Open live Render site** → show "Connected" pill (green)
4. **Upload a CSV** → watch the animated pipeline stages fire in real-time
5. **Results page** → show CQI score, radar chart, click all 4 tabs (Overview, Clean Data, Fuzzy Matches, Repair Log)
6. **Download Clean CSV** → show the fully cleaned file
7. **Infrastructure page** → click GitHub Actions card (shows live pipeline), Render card (shows deployment)
8. **FastAPI Docs** → open `https://[backend-url].onrender.com/docs` to show the professional API documentation
