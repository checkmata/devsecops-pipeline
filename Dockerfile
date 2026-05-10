# ══════════════════════════════════════════════════════════════════════════════
# Stage 1 — builder
#   Installs only production dependencies into a prefix directory so we can
#   copy just the installed packages into the final image (no pip, no cache).
# ══════════════════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build tools needed for some packages (cryptography, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libffi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Strip dev/test packages and install the rest into /install
RUN pip install --upgrade pip && \
    grep -v -E "^(pytest|pytest-cov|pytest-asyncio|flake8|bandit|#|$)" requirements.txt \
    | pip install --no-cache-dir --prefix=/install -r /dev/stdin


# ══════════════════════════════════════════════════════════════════════════════
# Stage 2 — production image
#   Minimal image: only the app code and installed packages.
#   Runs as a non-root user (appuser:appgroup).
# ══════════════════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS production

LABEL org.opencontainers.image.title="DevSecOps Demo API"
LABEL org.opencontainers.image.description="Production-style FastAPI service"
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/devsecops-pipeline"

# Security: create a dedicated non-root user
RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --no-create-home appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy only the application source — never copy .env, secrets, or test files
COPY app/ ./app/

# Drop to non-root
USER appuser

EXPOSE 8000

# Liveness check baked into the image
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c \
        "import httpx; r = httpx.get('http://localhost:8000/health', timeout=5); r.raise_for_status()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "1", "--log-level", "info"]
