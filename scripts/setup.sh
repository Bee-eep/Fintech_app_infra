#!/bin/bash

# Setup Script for Fintech Application DevOps
# This script sets up all prerequisites and deploys the infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[@]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

# Configure AWS credentials
configure_aws() {
    log_info "Configuring AWS credentials..."
    
    read -p "Enter AWS Region (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    read -p "Enter AWS Profile name (default: default): " AWS_PROFILE
    AWS_PROFILE=${AWS_PROFILE:-default}
    
    export AWS_REGION
    export AWS_PROFILE
    
    # Test AWS credentials
    if ! aws sts get-caller-identity --profile $AWS_PROFILE &> /dev/null; then
        log_error "Failed to authenticate with AWS. Please check your credentials."
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE)
    log_success "AWS credentials configured. Account ID: $AWS_ACCOUNT_ID"
}

# Setup Terraform
setup_terraform() {
    log_info "Setting up Terraform..."
    
    cd terraform
    
    # Copy example tfvars if it doesn't exist
    if [ ! -f terraform.tfvars ]; then
        cp terraform.tfvars.example terraform.tfvars
        log_warning "terraform.tfvars created from example. Please edit it with your values."
        log_info "Edit terraform.tfvars and run this script again."
        exit 0
    fi
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate || {
        log_error "Terraform validation failed"
        exit 1
    }
    
    # Plan
    log_info "Planning infrastructure..."
    terraform plan -out=tfplan
    
    read -p "Do you want to apply this plan? (yes/no): " APPLY_PLAN
    if [ "$APPLY_PLAN" != "yes" ]; then
        log_warning "Deployment cancelled"
        exit 0
    fi
    
    # Apply
    log_info "Applying Terraform configuration (this may take 20-30 minutes)..."
    terraform apply tfplan
    
    # Save outputs
    terraform output -json > outputs.json
    log_success "Infrastructure provisioned successfully"
    
    cd ..
}

# Configure kubectl
configure_kubectl() {
    log_info "Configuring kubectl..."
    
    CLUSTER_NAME=$(cd terraform && terraform output -raw eks_cluster_id 2>/dev/null || echo "fintech-eks")
    
    log_info "Updating kubeconfig for cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION --profile $AWS_PROFILE
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        log_success "kubectl configured successfully"
        log_info "Cluster Info:"
        kubectl cluster-info
    else
        log_error "Failed to connect to Kubernetes cluster"
        exit 1
    fi
}

# Deploy Kubernetes manifests
deploy_kubernetes() {
    log_info "Deploying Kubernetes manifests..."
    
    # Apply manifests in order
    local manifests=(
        "k8s/00-namespace.yaml"
        "k8s/01-configmap.yaml"
        "k8s/02-secrets.yaml"
        "k8s/03-postgres-init-script.yaml"
        "k8s/03-database.yaml"
        "k8s/04-backend.yaml"
        "k8s/05-frontend.yaml"
        "k8s/06-ingress.yaml"
        "k8s/07-hpa.yaml"
        "k8s/08-monitoring.yaml"
        "k8s/09-rbac.yaml"
    )
    
    for manifest in "${manifests[@]}"; do
        if [ -f "$manifest" ]; then
            log_info "Applying $manifest..."
            kubectl apply -f "$manifest" || {
                log_error "Failed to apply $manifest"
                exit 1
            }
        fi
    done
    
    log_success "Kubernetes manifests deployed"
}

# Build and push Docker images
build_docker_images() {
    log_info "Building and pushing Docker images..."
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE)
    ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Login to ECR
    log_info "Logging into ECR..."
    aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
        docker login --username AWS --password-stdin $ECR_REGISTRY
    
    # Build and push backend
    log_info "Building and pushing backend image..."
    docker build -f Dockerfile.backend -t $ECR_REGISTRY/fintech-backend:latest .
    docker push $ECR_REGISTRY/fintech-backend:latest
    log_success "Backend image pushed to $ECR_REGISTRY/fintech-backend:latest"
    
    # Build and push frontend
    log_info "Building and pushing frontend image..."
    docker build -f Dockerfile.frontend -t $ECR_REGISTRY/fintech-frontend:latest .
    docker push $ECR_REGISTRY/fintech-frontend:latest
    log_success "Frontend image pushed to $ECR_REGISTRY/fintech-frontend:latest"
    
    # Update deployments
    log_info "Updating deployments with new images..."
    kubectl set image deployment/fintech-backend \
        backend=$ECR_REGISTRY/fintech-backend:latest \
        -n fintech
    
    kubectl set image deployment/fintech-frontend \
        frontend=$ECR_REGISTRY/fintech-frontend:latest \
        -n fintech
    
    log_success "Deployments updated"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    log_info "Pods:"
    kubectl get pods -n fintech
    
    log_info "Services:"
    kubectl get services -n fintech
    
    log_info "Ingress:"
    kubectl get ingress -n fintech
    
    log_info "Horizontal Pod Autoscalers:"
    kubectl get hpa -n fintech
    
    log_success "Deployment verification complete"
}

# Print summary
print_summary() {
    log_info "Setup Summary:"
    echo ""
    echo "=== Cluster Information ==="
    kubectl cluster-info | head -3
    echo ""
    
    echo "=== Nodes ==="
    kubectl get nodes -o wide
    echo ""
    
    echo "=== Fintech Namespace ==="
    kubectl get all -n fintech
    echo ""
    
    echo "=== Useful Commands ==="
    echo "# View logs"
    echo "kubectl logs -f deployment/fintech-backend -n fintech"
    echo ""
    echo "# Port-forward to Prometheus"
    echo "kubectl port-forward -n fintech svc/prometheus 9090:9090"
    echo ""
    echo "# View HPA status"
    echo "kubectl get hpa -n fintech -w"
    echo ""
    echo "# Cleanup everything"
    echo "bash scripts/cleanup.sh"
    echo ""
}

# Main execution
main() {
    log_info "Starting Fintech Application Setup..."
    echo ""
    
    check_prerequisites
    configure_aws
    
    log_info "Setup Options:"
    echo "1. Full setup (infrastructure + kubernetes + docker)"
    echo "2. Infrastructure only (Terraform)"
    echo "3. Kubernetes only"
    echo "4. Docker images only"
    echo "5. Verify existing deployment"
    
    read -p "Select option (1-5): " SETUP_OPTION
    
    case $SETUP_OPTION in
        1)
            setup_terraform
            configure_kubectl
            deploy_kubernetes
            build_docker_images
            verify_deployment
            ;;
        2)
            setup_terraform
            ;;
        3)
            configure_kubectl
            deploy_kubernetes
            ;;
        4)
            build_docker_images
            ;;
        5)
            configure_kubectl
            verify_deployment
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "Setup completed!"
    print_summary
}

# Run main function
main "$@"
