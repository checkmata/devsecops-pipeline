#!/usr/bin/env bash
# scripts/install-monitoring.sh
# Installs kube-prometheus-stack via Helm into a "monitoring" namespace.
# Run this once after your cluster is up.

set -euo pipefail

RELEASE_NAME="monitoring"
NAMESPACE="monitoring"
CHART="prometheus-community/kube-prometheus-stack"
GRAFANA_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"

echo "==> Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "==> Installing ${CHART} as release '${RELEASE_NAME}' in namespace '${NAMESPACE}'..."
helm upgrade --install "${RELEASE_NAME}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set grafana.adminPassword="${GRAFANA_PASSWORD}" \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.retention=7d \
  --wait \
  --timeout 5m

echo ""
echo "✓ Monitoring stack installed."
echo ""
echo "  Access Grafana:"
echo "    kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-grafana 3000:80"
echo "    Open http://localhost:3000  (admin / ${GRAFANA_PASSWORD})"
echo ""
echo "  Access Prometheus:"
echo "    kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-kube-prometheus-prometheus 9090:9090"
echo "    Open http://localhost:9090"
