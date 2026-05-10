.PHONY: help build run stop test lint scan clean smoke logs shell setup

# ── Default target ────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "DevSecOps Pipeline — available commands"
	@echo "────────────────────────────────────────"
	@echo "  setup    Install local dev dependencies"
	@echo "  build    Build the production Docker image"
	@echo "  run      Start the full stack (API + Prometheus + Grafana)"
	@echo "  stop     Stop all containers"
	@echo "  test     Run the test suite with coverage"
	@echo "  lint     Run flake8 linter"
	@echo "  scan     Run Trivy image scan"
	@echo "  smoke    Smoke-test the running API"
	@echo "  logs     Tail API container logs"
	@echo "  shell    Open a shell inside the API container"
	@echo "  clean    Remove containers, volumes, and Python cache"
	@echo ""

# ── Local dev setup ───────────────────────────────────────────────────────────
setup:
	pip install --upgrade pip
	pip install -r requirements.txt

# ── Docker ────────────────────────────────────────────────────────────────────
build:
	docker build --target production -t devsecops-api:local .
	@echo "✓ Image built: devsecops-api:local"

run:
	docker compose up -d
	@echo "✓ Stack started"
	@echo "  API        → http://localhost:8000"
	@echo "  Docs       → http://localhost:8000/docs"
	@echo "  Prometheus → http://localhost:9090"
	@echo "  Grafana    → http://localhost:3000  (admin / admin123)"

stop:
	docker compose down
	@echo "✓ Stack stopped"

logs:
	docker compose logs -f api

shell:
	docker compose exec api /bin/sh

# ── Quality ───────────────────────────────────────────────────────────────────
test:
	pytest tests/ -v --cov=app --cov-report=xml --cov-report=term-missing

lint:
	flake8 app/ tests/ --max-line-length=100 --statistics

# ── Security ──────────────────────────────────────────────────────────────────
scan: build
	@command -v trivy >/dev/null 2>&1 || { echo "Install trivy: https://aquasecurity.github.io/trivy"; exit 1; }
	trivy image devsecops-api:local

scan-fs:
	trivy fs . --severity HIGH,CRITICAL

# ── Smoke test ────────────────────────────────────────────────────────────────
smoke:
	@echo "Running smoke tests against http://localhost:8000 ..."
	@curl -sf http://localhost:8000/health | python3 -m json.tool
	@echo "✓ Health check passed"
	@curl -sf http://localhost:8000/ready  | python3 -m json.tool
	@echo "✓ Readiness check passed"

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	docker compose down -v --remove-orphans
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -f coverage.xml .coverage
	@echo "✓ Clean complete"
