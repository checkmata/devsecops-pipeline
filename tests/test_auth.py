from app.auth import (
    create_access_token,
    verify_token,
    verify_password,
    fake_users_db,
    pwd_context,
)


def test_verify_password_correct():
    hashed = pwd_context.hash("mysecret")
    assert verify_password("mysecret", hashed) is True


def test_verify_password_wrong():
    hashed = pwd_context.hash("mysecret")
    assert verify_password("wrongpassword", hashed) is False


def test_create_and_verify_token():
    token = create_access_token({"sub": "testuser"})
    payload = verify_token(token)
    assert payload is not None
    assert payload["sub"] == "testuser"


def test_verify_token_invalid():
    result = verify_token("not.a.real.token")
    assert result is None


def test_verify_token_tampered():
    token = create_access_token({"sub": "admin"})
    tampered = token[:-5] + "XXXXX"
    assert verify_token(tampered) is None


def test_fake_users_db_has_admin():
    assert "admin" in fake_users_db
    assert "email" in fake_users_db["admin"]
    assert "hashed_password" in fake_users_db["admin"]
