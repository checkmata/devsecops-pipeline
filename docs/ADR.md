# Architecture Decision Records (ADR)

This file documents key architectural decisions made in this project, along with
the context and reasoning behind each choice.

---

## ADR-001: FastAPI over Flask or Django

**Status:** Accepted

**Context:** The demo service needs to expose a REST API with JWT auth and a
`/metrics` endpoint compatible with Prometheus. It should be simple enough for
a portfolio project but realistic enough to demonstrate production patterns.

**Decision:** Use FastAPI with Uvicorn.

**Reasons:**
- Native async support enables accurate latency benchmarking under load.
- Built-in OpenAPI/Swagger UI at `/docs` — zero extra config.
- `prometheus-client` integrates trivially via a WSGI middleware.
- Type annotations (via Pydantic) make SAST scanners more effective.

**Trade-offs:** Flask has wider industry adoption; Django REST Framework is more
batteries-included. For a portfolio demo FastAPI's auto-docs are visually compelling.

---

## ADR-002: SonarCloud over self-hosted SonarQube

**Status:** Accepted

**Context:** SAST scanning is a required pipeline stage.

**Decision:** SonarCloud (free for public repos) rather than a self-hosted
SonarQube instance.

**Reasons:**
- Zero infrastructure to maintain during the demo phase.
- SARIF reports upload natively to GitHub Security tab.
- Free tier includes quality gates, code smells, coverage tracking, and
  security hotspot detection.

**Trade-offs:** Self-hosted SonarQube offers more plugin flexibility and
on-premise data residency. For a real enterprise engagement, self-hosted
would be preferred. Noted in portfolio commentary.

---

## ADR-003: GHCR over Docker Hub

**Status:** Accepted

**Context:** A container registry is needed to store and version production images.

**Decision:** GitHub Container Registry (GHCR).

**Reasons:**
- Seamless authentication via `GITHUB_TOKEN` — no extra secret management.
- Free for public repositories with no pull-rate limits.
- Image digest pinning is first-class — CD workflow pins by digest, not tag.
- Lives inside the same GitHub org as source and Actions, reducing blast radius.

**Trade-offs:** Docker Hub has broader ecosystem familiarity. For a multi-cloud
deployment or vendor-neutral setup, an AWS ECR or GCP Artifact Registry would
be more appropriate.

---

## ADR-004: Minikube for local Kubernetes, EKS as promotion target

**Status:** Accepted

**Context:** Kubernetes orchestration is required. Running a full cloud cluster
24/7 for a portfolio project is expensive.

**Decision:** Use Minikube for development and local CI demos. Terraform
provisions an EKS cluster only for live portfolio showcases.

**Reasons:**
- Minikube is free, fully local, and supports LoadBalancer via `minikube tunnel`.
- The same manifests apply to both environments — only the image and namespace change.
- Terraform is provided so the reviewer can see the cloud path is real.

---

## ADR-005: Intentional vulnerabilities

**Status:** Accepted (by design)

**Context:** To demonstrate that the security toolchain actually works, the
application includes real detectable issues.

**Vulnerabilities introduced:**
1. Hardcoded JWT secret in `app/auth.py` — detected by Trivy secret scanning
   and SonarQube security hotspot.
2. Outdated `requests==2.28.0` and `Pillow==9.5.0` — detected by Trivy image
   scan and OWASP Dependency Check (CVSS ≥ 7.0).
3. Unverified token in `GET /items/{id}` — detected by SonarQube (unused
   parameter, dead code path).

All issues are documented in `README.md` and flagged in code comments. None
introduce exploitable attack surface against the demo environment.
