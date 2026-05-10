# 5-Minute Interview Demo Script

This script walks a hiring manager through the complete pipeline in under 5 minutes.
Each step has a talking point and a command to run live.

---

## Setup (before the interview — run these in advance)

```bash
make build          # pre-build the image
make run            # start the full stack
minikube start      # if demoing the k8s path
```

---

## Step 1 — Introduce the application (30 sec)

"This is a production-style FastAPI microservice with JWT authentication, a
Prometheus metrics endpoint, and a health check. It's intentionally built with
a few vulnerabilities so I can demonstrate the security toolchain catching them."

```bash
# Show the running API
curl http://localhost:8000/health
curl http://localhost:8000/docs   # open in browser
```

---

## Step 2 — Trigger the CI pipeline (60 sec)

"When I open a pull request, three jobs run in parallel — linting, unit tests
with coverage enforcement, and OWASP dependency scanning."

- Open a PR on GitHub and show the Actions tab running.
- Point to the coverage badge and the red OWASP check (the old `Pillow` version
  triggers a CVSS 7+ finding).

**Talking point:** "The pipeline fails fast — OWASP runs in parallel with tests,
so we don't waste minutes waiting for tests to finish before catching a known CVE."

---

## Step 3 — Show security findings (60 sec)

"On push to main, three security scans run: SonarCloud for SAST, Trivy for the
image, and OWASP ZAP for DAST."

- Open the GitHub Security tab → Code scanning alerts.
- Show the hardcoded secret finding from Trivy.
- Show the SonarQube security hotspot for the unused token parameter.

**Talking point:** "These findings come in as SARIF reports, which GitHub renders
natively. A security engineer can triage from the same interface they use for PRs."

---

## Step 4 — Deploy and show Kubernetes (60 sec)

```bash
kubectl get pods -n staging
kubectl get hpa -n staging
```

"The deployment uses digest-pinned images, runs as a non-root user, with a
read-only root filesystem and all Linux capabilities dropped. The HPA scales
between 2 and 10 replicas based on CPU and memory."

---

## Step 5 — Show observability (60 sec)

"Open Grafana at localhost:3000."

- Show the request rate panel: `rate(http_requests_total[5m])`
- Show P99 latency: `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))`

**Talking point:** "The API exposes custom Prometheus metrics via the
`/metrics` endpoint. The ServiceMonitor in k8s tells the Prometheus operator
to scrape it automatically — no config file editing."

---

## Step 6 — Fix a vulnerability live (30 sec, optional)

Update `Pillow` to `10.1.0` in `requirements.txt`, open a PR, and show the
OWASP check turn green. This demonstrates the feedback loop end-to-end.

---

## Questions to anticipate

**"Why not use Jenkins?"**
GitHub Actions has zero infrastructure overhead, better GitHub integration, and
free minutes for public repos. Jenkins is better for complex enterprise pipelines
with existing on-prem infrastructure. I documented this in `docs/ADR.md`.

**"How would this scale in production?"**
Replace Minikube with EKS (Terraform is already written). Add a proper secrets
manager (AWS Secrets Manager + External Secrets Operator) to remove the hardcoded
key. Add multi-region ingress and a CDN in front.

**"What would you add next?"**
SBOM generation (Trivy `--format cyclonedx`), supply-chain signing (Sigstore
Cosign), and policy enforcement (OPA Gatekeeper on the cluster).
