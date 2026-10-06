#!/usr/bin/env bash
# scripts/install-cert-manager.sh
# Install cert-manager and create a self-signed ClusterIssuer for local Minikube development.
# Usage: bash scripts/install-cert-manager.sh

set -euo pipefail

echo "📦 Installing cert-manager..."

# Install cert-manager via Helm
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.2 \
  --set installCRDs=true \
  --wait

echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Available deployment -n cert-manager --all --timeout=120s

echo "📝 Creating self-signed ClusterIssuer for local development..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # CHANGE THIS
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # CHANGE THIS
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

echo "✅ cert-manager installed with ClusterIssuers:"
echo "   - selfsigned-issuer (for local Minikube testing)"
echo "   - letsencrypt-staging (for staging environments)"
echo "   - letsencrypt-prod (for production - rate limited!)"
echo ""
echo "🔧 To use with Minikube Ingress, update k8s/ingress.yaml:"
echo "   cert-manager.io/cluster-issuer: \"selfsigned-issuer\""
echo ""
echo "📋 For cloud (EKS), use letsencrypt-staging/prod and ensure:"
echo "   - Ingress controller (nginx) is installed"
echo "   - DNS points to the LoadBalancer IP"
echo "   - Email is updated in ClusterIssuer manifests"