#!/usr/bin/env bash
# =============================================================================
# Install Prometheus + Grafana monitoring stack on the EKS cluster
# Prerequisites: kubectl configured, helm v3 installed
# =============================================================================
set -euo pipefail

NAMESPACE="monitoring"
RELEASE_NAME="monitoring"
CHART_VERSION="58.2.2"  # kube-prometheus-stack chart version

echo "==> Creating namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying gp3 StorageClass"
kubectl apply -f storageclass.yaml

echo "==> Adding prometheus-community Helm repo"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "==> Installing kube-prometheus-stack"
helm upgrade --install "${RELEASE_NAME}" \
  prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values values-prometheus-stack.yaml \
  --wait --timeout 10m

echo "==> Applying Hello World Grafana dashboard"
kubectl apply -f hello-world-dashboard-configmap.yaml

echo "==> Applying alerting rules"
kubectl apply -f alerts.yaml

echo ""
echo "✅ Monitoring stack installed successfully!"
echo ""
echo "Access Grafana:"
echo "  kubectl get svc -n ${NAMESPACE} monitoring-grafana"
echo "  Default credentials: admin / lucidity-admin"
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/monitoring-prometheus 9090:9090"

