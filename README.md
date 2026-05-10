# DevSecOps Pipeline

> A production-style end-to-end CI/CD pipeline built for a portfolio.  
> Demonstrates enterprise DevSecOps practices — security scanning, container
> hardening, Kubernetes orchestration, and observability — on a free-tier stack.

![CI](https://github.com/checkmata/devsecops-pipeline/actions/workflows/ci.yml/badge.svg)
![Security](https://github.com/checkmata/devsecops-pipeline/actions/workflows/security.yml/badge.svg)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=YOUR_PROJECT_KEY&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=YOUR_PROJECT_KEY)

---

## Table of contents

1. [What this project demonstrates](#what-this-project-demonstrates)
2. [Architecture overview](#architecture-overview)
3. [Toolchain & versions](#toolchain--versions)
4. [Repository structure](#repository-structure)
5. [Quick start (local)](#quick-start-local)
6. [Phase-by-phase setup](#phase-by-phase-setup)
   - [Phase 0 — Prerequisites](#phase-0--prerequisites)
   - [Phase 1 — Application](#phase-1--application)
   - [Phase 2 — CI pipeline](#phase-2--ci-pipeline)
   - [Phase 3 — CD to Kubernetes](#phase-3--cd-to-kubernetes)
   - [Phase 4 — Monitoring](#phase-4--monitoring)
   - [Phase 5 — Terraform (cloud)](#phase-5--terraform-cloud)
7. [GitHub repository configuration](#github-repository-configuration)
8. [Intentional vulnerabilities](#intentional-vulnerabilities)
9. [Prometheus queries & dashboards](#prometheus-queries--dashboards)
10. [Cost breakdown](#cost-breakdown)
11. [What to add next](#what-to-add-next)
12. [Interview demo script](#interview-demo-script)

---

## What this project demonstrates

| Discipline | Evidence |
|---|---|
| **Source control** | GitFlow branching, branch protection rules, PR-gated merges |
| **CI** | GitHub Actions: lint → test → coverage → OWASP dep-check → Docker build |
| **SAST** | SonarQube via SonarCloud — quality gate, hotspots, SARIF upload |
| **Dependency scanning** | OWASP Dependency Check (fail on CVSS ≥ 7.0) |
| **Container security** | Trivy: image scan + IaC scan + secret detection |
| **DAST** | OWASP ZAP baseline scan against live staging instance |
| **Container registry** | GHCR with digest-pinned deployments |
| **Kubernetes** | Namespaced environments, resource limits, liveness/readiness probes, HPA, ServiceMonitor |
| **Infrastructure as Code** | Terraform VPC + EKS module for cloud promotion |
| **Observability** | Prometheus custom metrics + Grafana dashboards + Alertmanager |
| **Security hardening** | Non-root container, read-only root FS, all capabilities dropped, seccomp |

---

## Architecture overview

```
Developer → GitHub PR → ci.yml (lint, test, OWASP dep-check, Docker build)
                   ↓
              push to main
                   ↓
         security.yml (SonarCloud, Trivy FS, Trivy image, OWASP ZAP)
                   ↓
            git tag v*.*.*
                   ↓
           cd.yml ──────────────────────────────────────────────────────┐
             ├── Build + push to GHCR (digest-pinned)                   │
             ├── Trivy scan (HARD FAIL on HIGH/CRITICAL)                │
             ├── Deploy → staging (Minikube / EKS)                      │
             │     └── Smoke test /health                               │
             └── Deploy → production (requires manual approval)         │
                                                                        │
Kubernetes cluster                                                       │
  ├── Namespace: staging                                                 │
  │     ├── Deployment (2 replicas, rolling update)  ←──────────────────┘
  │     ├── Service (ClusterIP + Ingress)
  │     ├── ConfigMap
  │     ├── HPA (CPU 70% / memory 80%, max 10 pods)
  │     └── ServiceMonitor → Prometheus scrape /metrics
  └── Namespace: monitoring
        ├── Prometheus (kube-prometheus-stack)
        ├── Grafana (dashboards: request rate, error rate, P99 latency)
        └── Alertmanager
```

---

## Toolchain & versions

| Tool | Version | Role | Why chosen |
|---|---|---|---|
| Python | 3.11 | Runtime | Stable LTS, type hints improve SAST accuracy |
| FastAPI | 0.104.1 | Web framework | Auto OpenAPI docs, native async, easy Prometheus integration |
| Uvicorn | 0.24.0 | ASGI server | Production-grade, recommended by FastAPI |
| GitHub Actions | native | CI/CD orchestrator | Free for public repos, deep GitHub integration |
| SonarCloud | free tier | SAST | Zero infra, SARIF upload, quality gates |
| OWASP Dep-Check | 9.x | Dependency CVE scan | Gold-standard for CVE scanning, CVSS threshold gating |
| Trivy | 0.48+ | Image + IaC + secrets | Single binary, fastest scanner, supports SARIF |
| OWASP ZAP | 2.14 | DAST | Industry standard, official GitHub Action |
| GHCR | native | Container registry | Free, no rate limits, `GITHUB_TOKEN` auth |
| Docker | 24+ | Containerisation | Multi-stage builds, non-root image |
| Minikube | 1.32+ | Local Kubernetes | Free local cluster, LoadBalancer via tunnel |
| Helm | 3.13+ | Kubernetes package manager | Standard for deploying monitoring stack |
| kube-prometheus-stack | latest | Prometheus + Grafana | Installs full monitoring in one chart |
| Terraform | 1.6+ | IaC | EKS cluster provisioning for cloud demo path |

See `docs/ADR.md` for detailed reasoning behind each choice vs alternatives.

---

## Repository structure

```
devsecops-pipeline/
│
├── app/                        # FastAPI application source
│   ├── __init__.py
│   ├── main.py                 # Routes, middleware, Prometheus metrics
│   ├── auth.py                 # JWT token creation & verification
│   ├── models.py               # Pydantic schemas
│   └── config.py               # Environment-driven settings
│
├── tests/                      # Pytest test suite (>70% coverage enforced)
│   ├── __init__.py
│   ├── test_main.py            # Route tests (health, auth, protected)
│   └── test_auth.py            # Auth unit tests
│
├── k8s/                        # Kubernetes manifests
│   ├── namespace.yaml          # staging + production namespaces
│   ├── deployment.yaml         # Deployment with security context + probes
│   ├── service.yaml            # ClusterIP/LoadBalancer
│   ├── configmap.yaml          # Non-secret app config
│   ├── hpa.yaml                # HorizontalPodAutoscaler
│   ├── ingress.yaml            # Ingress + TLS (cert-manager)
│   └── service-monitor.yaml    # Prometheus operator ServiceMonitor
│
├── .github/
│   └── workflows/
│       ├── ci.yml              # PR: lint, test, OWASP dep-check, Docker build
│       ├── security.yml        # main: SonarCloud, Trivy FS, Trivy image, ZAP
│       └── cd.yml              # tag: build, push GHCR, deploy staging → prod
│
├── monitoring/
│   ├── prometheus.yml          # Prometheus config for docker-compose
│   └── grafana/
│       └── provisioning/       # Auto-configure datasource + dashboards
│
├── terraform/                  # EKS cluster (cloud promotion path)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── docs/
│   ├── ADR.md                  # Architecture Decision Records
│   └── DEMO_SCRIPT.md          # 5-minute interview walkthrough
│
├── scripts/
│   ├── install-monitoring.sh   # Helm install kube-prometheus-stack
│   └── smoke-test.sh           # End-to-end smoke tests
│
├── .zap/rules.tsv              # OWASP ZAP rule overrides
├── .env.example                # Environment variable template
├── .gitignore
├── Dockerfile                  # Multi-stage: builder → production (non-root)
├── docker-compose.yml          # API + Prometheus + Grafana
├── Makefile                    # Developer workflow commands
├── pytest.ini                  # Test configuration
├── requirements.txt            # Dependencies (some intentionally outdated)
└── sonar-project.properties    # SonarCloud project config
```

---

## Quick start (local)

You need: **Docker**, **Docker Compose**, and **Python 3.11+** on your machine.

```bash
# 1. Clone the repo
git clone https://github.com/checkmata/devsecops-pipeline.git
cd devsecops-pipeline

# 2. Copy env template
cp .env.example .env

# 3. Build the image
make build

# 4. Start the full stack (API + Prometheus + Grafana)
make run

# 5. Run smoke tests
make smoke
```

**URLs after `make run`:**

| Service | URL | Credentials |
|---|---|---|
| API (Swagger UI) | http://localhost:8000/docs | — |
| API health | http://localhost:8000/health | — |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin123 |

---

## Phase-by-phase setup

### Phase 0 — Prerequisites

#### Local machine

```bash
# macOS
brew install git docker kubectl minikube helm terraform

# Ubuntu / Debian
sudo apt-get update && sudo apt-get install -y git docker.io kubectl
# Install minikube, helm, terraform from their official install scripts

# Verify
docker --version        # 24+
kubectl version --client
minikube version        # v1.32+
helm version            # v3.13+
terraform version       # v1.6+
```

**Windows:** Install WSL2 + Docker Desktop. Run all commands inside the WSL2
Ubuntu terminal — Minikube uses the Docker driver on WSL2.

#### Python environment

```bash
pip install -r requirements.txt

# Run tests to verify the setup
make test
```

---

### Phase 1 — Application

The service is a FastAPI REST API with:

- `POST /auth/token` — obtain a JWT (username + password)
- `GET /users/me` — authenticated user info
- `GET /items/{id}` — fetch an item (intentionally buggy auth — see below)
- `GET /health` — liveness probe
- `GET /ready` — readiness probe
- `GET /metrics` — Prometheus metrics endpoint

**Run locally without Docker:**

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
# Open http://localhost:8000/docs
```

**Run with Docker:**

```bash
make build
docker run -p 8000:8000 devsecops-api:local
```

**Run tests:**

```bash
make test
# Or directly:
pytest tests/ -v --cov=app --cov-report=term-missing
```

The Dockerfile uses a **multi-stage build**:

1. `builder` stage — installs all dependencies into `/install`, has `gcc` and
   build tools available.
2. `production` stage — copies only `/install` from builder, copies app source,
   creates a non-root user (`appuser`), and drops to that user before starting.

This means the final image has no `pip`, no build tools, and no dev packages.

---

### Phase 2 — CI pipeline

Three workflow files in `.github/workflows/`:

#### `ci.yml` — triggered on every pull request to `main` or `develop`

| Job | What it does | Fails pipeline if... |
|---|---|---|
| `lint-test` | flake8 + pytest-cov | Coverage < 70% or lint errors |
| `dependency-check` | OWASP Dep-Check | Any dependency has CVSS ≥ 7.0 |
| `docker-build` | Multi-stage Docker build + Trivy CRITICAL scan | CRITICAL CVE in image |

**Set up the pipeline:**

1. Push your repo to GitHub.
2. Open a pull request from `develop` to `main`.
3. The three jobs run automatically. Check the Actions tab.

#### `security.yml` — triggered on push to `main`

| Job | Tool | Output |
|---|---|---|
| `sonarcloud` | SonarCloud | Quality gate + SARIF → Security tab |
| `trivy-fs` | Trivy | IaC misconfigs + secret detection → SARIF |
| `trivy-image` | Trivy | OS + app CVEs → SARIF |
| `zap-dast` | OWASP ZAP | Baseline DAST report (HTML artifact) |

#### `cd.yml` — triggered on `v*.*.*` tags or manual dispatch

```bash
# To trigger a production deployment:
git tag v1.0.0
git push origin v1.0.0
```

The workflow: build → push to GHCR → Trivy scan (HARD FAIL) → deploy staging
→ smoke test → deploy production (requires manual approval in GitHub UI).

---

### Phase 3 — CD to Kubernetes

#### Start Minikube

```bash
minikube start --cpus=4 --memory=8192 --driver=docker
minikube tunnel &   # runs in background — enables LoadBalancer IPs
```

#### Apply manifests manually (to understand each piece)

```bash
# 1. Namespaces
kubectl apply -f k8s/namespace.yaml

# 2. Config
kubectl apply -f k8s/configmap.yaml -n staging

# 3. Workload
kubectl apply -f k8s/deployment.yaml -n staging
kubectl apply -f k8s/service.yaml    -n staging
kubectl apply -f k8s/hpa.yaml        -n staging

# 4. Watch rollout
kubectl rollout status deployment/devsecops-api -n staging

# 5. Check pods
kubectl get pods -n staging -o wide

# 6. Check HPA
kubectl get hpa -n staging
```

#### Verify the deployment

```bash
# Get the external IP (via minikube tunnel)
kubectl get svc devsecops-api -n staging

# Smoke test against the cluster
BASE_URL=http://<EXTERNAL-IP> bash scripts/smoke-test.sh
```

#### Kubernetes security hardening applied

Every pod runs with these security settings (see `k8s/deployment.yaml`):

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true   # requires emptyDir for /tmp
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

This satisfies the CIS Kubernetes Benchmark and common admission controllers
like OPA Gatekeeper or Kyverno.

---

### Phase 4 — Monitoring

#### Local (docker-compose)

Prometheus and Grafana start automatically with `make run`.

- Prometheus config: `monitoring/prometheus.yml`
- Grafana datasource: auto-provisioned via `monitoring/grafana/provisioning/datasources/`
- Grafana URL: http://localhost:3000 (admin / admin123)

#### Kubernetes (Helm)

```bash
bash scripts/install-monitoring.sh

# Access Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Open http://localhost:3000
```

#### Useful PromQL queries (add these as Grafana panels)

```promql
# Request rate (all endpoints)
rate(http_requests_total[5m])

# Error rate percentage
100 * (
  rate(http_requests_total{status_code=~"[45].."}[5m])
  / rate(http_requests_total[5m])
)

# P99 request latency
histogram_quantile(0.99,
  rate(http_request_duration_seconds_bucket[5m])
)

# Requests per endpoint
sum by (endpoint) (rate(http_requests_total[5m]))

# Pod memory usage
container_memory_working_set_bytes{
  namespace="staging",
  container="api"
}

# HPA replica count
kube_horizontalpodautoscaler_status_current_replicas{
  namespace="staging"
}
```

---

### Phase 5 — Terraform (cloud)

Use this only when you want a live cloud URL for your portfolio demo. It will
cost approximately $3–5/day on AWS (t3.medium × 2 nodes + NAT Gateway).

```bash
cd terraform/

# Authenticate to AWS
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

# Preview the plan
terraform init
terraform plan

# Apply (creates VPC + EKS cluster — takes ~12 minutes)
terraform apply

# Configure kubectl to point at the new cluster
$(terraform output -raw kubeconfig_command)

# Tear down when done (avoid charges)
terraform destroy
```

After provisioning, apply the k8s manifests exactly as in Phase 3 — the same
manifests work on EKS.

---

## GitHub repository configuration

### Required secrets

Go to: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Where to get it | Used by |
|---|---|---|
| `SONAR_TOKEN` | sonarcloud.io → My Account → Security | `security.yml` |
| `NVD_API_KEY` | nvd.nist.gov/developers/request-an-api-key | `ci.yml` (Dep-Check) |

`GITHUB_TOKEN` is automatically available — no setup needed.

### Branch protection rules

Go to: **Settings → Branches → Add branch protection rule** for `main`:

- [x] Require pull request reviews before merging (1 required reviewer)
- [x] Require status checks to pass before merging
  - Add: `lint-test`, `dependency-check`, `docker-build`
- [x] Require branches to be up to date before merging
- [x] Do not allow bypassing the above settings

### Environments

Go to: **Settings → Environments → New environment**

1. Create `staging` — no protection rules
2. Create `production` — add yourself as a required reviewer

When the CD workflow reaches the production deploy step, GitHub will pause and
send you an email asking for approval.

### SonarCloud

1. Sign in at https://sonarcloud.io with your GitHub account
2. Click **+** → **Analyze new project** → select your repo
3. Copy the `projectKey` and `organization` values into `sonar-project.properties`
4. Copy the token into the `SONAR_TOKEN` repo secret

---

## Intentional vulnerabilities

The application ships with real, detectable issues to prove the toolchain works.
These are documented and harmless — none allow remote code execution.

| Vulnerability | Location | Detected by | How to fix |
|---|---|---|---|
| Hardcoded JWT secret | `app/auth.py:SECRET_KEY` | Trivy secrets, SonarQube hotspot | Load from env var: `os.environ["SECRET_KEY"]` |
| Outdated `requests==2.28.0` | `requirements.txt` | OWASP Dep-Check (CVSS 7.5), Trivy | `requests==2.31.0` |
| Outdated `Pillow==9.5.0` | `requirements.txt` | OWASP Dep-Check (CVSS 7.5+), Trivy | `Pillow==10.1.0` |
| Token not verified | `app/main.py:get_item()` | SonarQube (dead code / unused param) | Call `verify_token(token)` and raise 401 if None |

**Portfolio tip:** Let the pipeline fail on these findings, screenshot the red
check, fix one at a time in a PR, and screenshot the green. This demonstrates
the feedback loop — which is what interviewers want to see.

---

## Prometheus queries & dashboards

#### Recommended Grafana dashboard panels

**Panel 1 — Request rate**
```promql
sum(rate(http_requests_total[5m])) by (endpoint)
```
Visualization: Time series. Shows traffic breakdown per route.

**Panel 2 — Error rate**
```promql
100 * sum(rate(http_requests_total{status_code=~"[45].."}[5m]))
     / sum(rate(http_requests_total[5m]))
```
Visualization: Stat with threshold: green < 1%, yellow < 5%, red ≥ 5%.

**Panel 3 — P99 latency**
```promql
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```
Visualization: Gauge with threshold: green < 200ms, yellow < 500ms, red ≥ 500ms.

**Panel 4 — Pod replicas**
```promql
kube_deployment_status_replicas_available{deployment="devsecops-api"}
```
Visualization: Stat — shows HPA scaling in action.

---

## Cost breakdown

| Resource | Cost | Notes |
|---|---|---|
| GitHub Actions | **Free** | 2,000 min/month on public repos; unlimited on private with GitHub Free |
| SonarCloud | **Free** | Public repos only |
| GHCR | **Free** | Public repos only |
| Minikube | **Free** | Runs on your local machine |
| AWS EKS | ~$3–5/day | Only spin up for live portfolio demos; `terraform destroy` immediately after |
| Domain (DuckDNS) | **Free** | Optional — for HTTPS ingress demo |
| NVD API key | **Free** | For OWASP Dep-Check NVD database sync |

**Total to build this portfolio project: $0** (using local Minikube and free
tiers for everything else). Only spend on EKS if you need a live public URL.

---

## What to add next

Once the core pipeline is solid, these additions will make the project stand out
even more in interviews:

1. **SBOM generation** — add `trivy --format cyclonedx` to the CD workflow to
   produce a Software Bill of Materials for every release.

2. **Image signing** — use [Sigstore Cosign](https://docs.sigstore.dev/cosign)
   to sign images after push and verify the signature before deployment.
   Demonstrates supply-chain security awareness.

3. **External Secrets Operator** — replace the hardcoded secret with a proper
   pull from AWS Secrets Manager using
   [external-secrets.io](https://external-secrets.io). This is how teams
   actually solve the secrets-in-k8s problem.

4. **OPA Gatekeeper / Kyverno** — add a policy controller to the cluster that
   enforces the security context rules (non-root, no privilege escalation) at
   admission time. The deployment will be rejected by the cluster itself if it
   doesn't meet the policy.

5. **Loki for log aggregation** — add Grafana Loki to the Helm install and
   point the API container logs at it. Then create a Grafana explore query
   linking error logs to the error-rate panel.

6. **Multi-region / blue-green deployment** — extend the Terraform to provision
   two EKS clusters in different regions with Route53 weighted routing. This
   demonstrates zero-downtime deployments.

---

## Interview demo script

See `docs/DEMO_SCRIPT.md` for a full 5-minute walkthrough script with talking
points, live commands, and anticipated interviewer questions with prepared answers.

---

## License

MIT — use this freely as a portfolio template.

---

*Built to demonstrate enterprise DevSecOps practices on a student budget.*
