from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
import time
import logging

from app.auth import create_access_token, verify_token, fake_users_db, verify_password
from app.models import Token, UserOut

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="DevSecOps Demo API",
    version="1.0.0",
    description="A production-style FastAPI app demonstrating DevSecOps best practices.",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── Prometheus metrics ────────────────────────────────────────────────────────
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status_code"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["endpoint"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


@app.middleware("http")
async def metrics_middleware(request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status_code=response.status_code,
    ).inc()
    REQUEST_LATENCY.labels(endpoint=request.url.path).observe(duration)
    return response


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health", tags=["Ops"])
async def health():
    """Liveness probe — returns 200 when the service is up."""
    return {"status": "healthy", "version": "1.0.0"}


@app.get("/ready", tags=["Ops"])
async def ready():
    """Readiness probe — returns 200 when the service is ready to receive traffic."""
    return {"status": "ready"}


@app.get("/metrics", tags=["Ops"])
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/auth/token", response_model=Token, tags=["Auth"])
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """Obtain a JWT bearer token via username + password."""
    user = fake_users_db.get(form_data.username)
    if not user or not verify_password(form_data.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token({"sub": form_data.username})
    logger.info("User %s authenticated successfully", form_data.username)
    return {"access_token": token, "token_type": "bearer"}


@app.get("/users/me", response_model=UserOut, tags=["Users"])
async def read_users_me(token: str = Depends(oauth2_scheme)):
    """Return the currently authenticated user's profile."""
    payload = verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    username = payload.get("sub")
    user = fake_users_db.get(username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserOut(username=username, email=user["email"])


@app.get("/items/{item_id}", tags=["Items"])
async def get_item(item_id: int, token: str = Depends(oauth2_scheme)):
    """
    Fetch an item by ID.

    INTENTIONAL SECURITY ISSUE: token is accepted but not validated here.
    SonarQube / SAST tools will flag this. Used to demonstrate scanner detection.
    """
    # BUG: verify_token(token) is never called — SonarQube will flag dead param
    return {"item_id": item_id, "name": f"Item {item_id}", "owner": "unverified"}
