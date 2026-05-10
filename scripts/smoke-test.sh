#!/usr/bin/env bash
# scripts/smoke-test.sh
# Quick end-to-end smoke test against a running API.
# Usage: BASE_URL=http://localhost:8000 bash scripts/smoke-test.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2"
  shift 2
  local actual
  actual=$(curl -s -o /dev/null -w "%{http_code}" "$@")
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ ${desc} (${actual})"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${desc} — expected ${expected}, got ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "Smoke tests → ${BASE_URL}"
echo "────────────────────────────────"

check "GET /health returns 200"  200 "${BASE_URL}/health"
check "GET /ready  returns 200"  200 "${BASE_URL}/ready"
check "GET /metrics returns 200" 200 "${BASE_URL}/metrics"
check "POST /auth/token (valid)" 200 \
  -X POST "${BASE_URL}/auth/token" \
  -d "username=admin&password=password123"

TOKEN=$(curl -s -X POST "${BASE_URL}/auth/token" \
  -d "username=admin&password=password123" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

check "GET /users/me with token"       200 "${BASE_URL}/users/me" -H "Authorization: Bearer ${TOKEN}"
check "GET /users/me without token"    401 "${BASE_URL}/users/me"
check "POST /auth/token (wrong pass)"  401 \
  -X POST "${BASE_URL}/auth/token" \
  -d "username=admin&password=wrong"

echo "────────────────────────────────"
echo "  Passed: ${PASS}   Failed: ${FAIL}"
echo ""

[ "$FAIL" -eq 0 ] || exit 1
