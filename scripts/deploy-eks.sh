#!/usr/bin/env bash
# scripts/deploy-eks.sh
# Deploy the full stack to AWS EKS using Terraform.
# Usage: bash scripts/deploy-eks.sh [plan|apply|destroy]

set -euo pipefail

ACTION="${1:-plan}"
TERRAFORM_DIR="$(dirname "$0")/../terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 DevSecOps Pipeline - EKS Deployment${NC}"
echo "Action: ${ACTION}"
echo "Terraform dir: ${TERRAFORM_DIR}"
echo ""

# Check prerequisites
check_prereqs() {
    echo "🔍 Checking prerequisites..."

    command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ terraform not found${NC}"; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ aws cli not found${NC}"; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl not found${NC}"; exit 1; }
    command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ helm not found${NC}"; exit 1; }

    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}❌ AWS credentials not configured${NC}"
        echo "Run: aws configure"
        exit 1
    fi

    echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Initialize Terraform
terraform_init() {
    echo "📦 Initializing Terraform..."
    cd "${TERRAFORM_DIR}"
    terraform init -upgrade
}

# Plan Terraform
terraform_plan() {
    echo "📋 Planning Terraform changes..."
    cd "${TERRAFORM_DIR}"
    terraform plan -out=tfplan
}

# Apply Terraform
terraform_apply() {
    echo "🚀 Applying Terraform..."
    cd "${TERRAFORM_DIR}"
    if [ -f "tfplan" ]; then
        terraform apply tfplan
    else
        terraform apply -auto-approve
    fi
}

# Destroy Terraform
terraform_destroy() {
    echo -e "${RED}💥 Destroying Terraform resources...${NC}"
    cd "${TERRAFORM_DIR}"
    terraform destroy -auto-approve
}

# Configure kubectl for EKS
configure_kubectl() {
    echo "⚙️  Configuring kubectl for EKS..."
    cd "${TERRAFORM_DIR}"
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "devsecops-prod")
    REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1")

    aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"
    echo -e "${GREEN}✅ kubectl configured for ${CLUSTER_NAME}${NC}"
}

# Deploy monitoring stack
deploy_monitoring() {
    echo "📊 Deploying monitoring stack (kube-prometheus-stack)..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --version 45.0.0 \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --wait --timeout 10m

    echo -e "${GREEN}✅ Monitoring stack deployed${NC}"
}

# Deploy cert-manager
deploy_cert_manager() {
    echo "🔐 Deploying cert-manager..."
    helm repo add jetstack https://charts.jetstack.io
    helm repo update

    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.13.2 \
        --set installCRDs=true \
        --wait --timeout 5m

    # Create Let's Encrypt ClusterIssuer for production
    cat <<EOF | kubectl apply -f -
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

    echo -e "${GREEN}✅ cert-manager deployed with Let's Encrypt ClusterIssuer${NC}"
    echo -e "${YELLOW}⚠️  Update email in ClusterIssuer before production use${NC}"
}

# Deploy nginx ingress controller
deploy_ingress() {
    echo "🌐 Deploying NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --version 4.7.0 \
        --set controller.service.type=LoadBalancer \
        --set controller.metrics.enabled=true \
        --wait --timeout 10m

    echo -e "${GREEN}✅ NGINX Ingress Controller deployed${NC}"
    echo "Get LoadBalancer IP: kubectl get svc -n ingress-nginx ingress-nginx-controller"
}

# Deploy application
deploy_app() {
    echo "📦 Deploying application to EKS..."
    cd "$(dirname "$0")/.."

    # Apply namespaces
    kubectl apply -f k8s/namespace.yaml

    # Apply ConfigMap for production
    kubectl apply -f k8s/configmap.yaml -n production

    # Deploy to production namespace
    kubectl apply -f k8s/deployment.yaml -n production
    kubectl apply -f k8s/service.yaml -n production
    kubectl apply -f k8s/hpa.yaml -n production
    kubectl apply -f k8s/ingress.yaml -n production
    kubectl apply -f k8s/service-monitor.yaml -n production

    # Wait for rollout
    kubectl rollout status deployment/devsecops-api -n production --timeout=300s

    echo -e "${GREEN}✅ Application deployed to production namespace${NC}"
}

# Full deployment
full_deploy() {
    check_prereqs
    terraform_init
    terraform_plan
    terraform_apply
    configure_kubectl
    deploy_monitoring
    deploy_cert_manager
    deploy_ingress
    deploy_app

    echo ""
    echo -e "${GREEN}🎉 Full EKS deployment complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Get Ingress IP: kubectl get svc -n ingress-nginx ingress-nginx-controller"
    echo "  2. Point your domain DNS to the LoadBalancer IP"
    echo "  3. Update email in ClusterIssuer: kubectl edit clusterissuer letsencrypt-prod"
    echo "  4. Test: curl https://api.yourdomain.com/health"
    echo ""
    echo "To tear down: bash scripts/deploy-eks.sh destroy"
}

# Main
case "${ACTION}" in
    plan)
        check_prereqs
        terraform_init
        terraform_plan
        ;;
    apply)
        check_prereqs
        terraform_init
        terraform_apply
        configure_kubectl
        ;;
    destroy)
        check_prereqs
        terraform_destroy
        ;;
    deploy)
        full_deploy
        ;;
    monitoring)
        check_prereqs
        configure_kubectl
        deploy_monitoring
        ;;
    cert-manager)
        check_prereqs
        configure_kubectl
        deploy_cert_manager
        ;;
    ingress)
        check_prereqs
        configure_kubectl
        deploy_ingress
        ;;
    app)
        check_prereqs
        configure_kubectl
        deploy_app
        ;;
    *)
        echo "Usage: $0 [plan|apply|destroy|deploy|monitoring|cert-manager|ingress|app]"
        echo ""
        echo "Commands:"
        echo "  plan        - Terraform plan only"
        echo "  apply       - Terraform apply only"
        echo "  destroy     - Destroy all EKS resources"
        echo "  deploy      - Full deployment (terraform + k8s)"
        echo "  monitoring  - Deploy monitoring stack only"
        echo "  cert-manager - Deploy cert-manager only"
        echo "  ingress     - Deploy NGINX Ingress only"
        echo "  app         - Deploy application only"
        exit 1
        ;;
esac