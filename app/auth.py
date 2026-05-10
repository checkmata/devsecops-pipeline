from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext

# ─────────────────────────────────────────────────────────────────────────────
# INTENTIONAL SECURITY ISSUE: hardcoded secret key.
# Trivy secret scanning and SonarQube will flag this.
# In production, load from environment variables or a secrets manager (Vault,
# AWS Secrets Manager, GCP Secret Manager, Azure Key Vault).
# ─────────────────────────────────────────────────────────────────────────────
SECRET_KEY = "hardcoded-secret-do-not-use-in-production-abc123xyz"  # noqa: S105
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# In-memory user store — replace with a real database in production
fake_users_db: dict[str, dict] = {
    "admin": {
        "username": "admin",
        "email": "admin@example.com",
        "hashed_password": pwd_context.hash("password123"),
    },
    "alice": {
        "username": "alice",
        "email": "alice@example.com",
        "hashed_password": pwd_context.hash("alice-secret"),
    },
}


def verify_password(plain: str, hashed: str) -> bool:
    """Compare a plaintext password against a bcrypt hash."""
    return pwd_context.verify(plain, hashed)


def create_access_token(data: dict) -> str:
    """Create a signed JWT token with an expiry claim."""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode["exp"] = expire
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def verify_token(token: str) -> dict | None:
    """Decode and verify a JWT token. Returns payload dict or None on failure."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None
