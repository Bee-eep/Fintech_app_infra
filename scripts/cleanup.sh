#!/bin/bash

# Cleanup Script - Removes all infrastructure
# Use with caution!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Confirmation prompt
confirm_cleanup() {
    log_warning "This will DELETE all infrastructure and data!"
    log_warning "This action CANNOT be undone."
    echo ""
    read -p "Type 'DELETE_EVERYTHING' to confirm: " CONFIRM
    
    if [ "$CONFIRM" != "DELETE_EVERYTHING" ]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
}

# Delete Kubernetes resources
delete_kubernetes() {
    log_info "Deleting Kubernetes resources..."
    
    if kubectl get namespace fintech &> /dev/null; then
        # Delete all resources in fintech namespace
        log_info "Deleting fintech namespace and all resources..."
        kubectl delete namespace fintech --ignore-not-found=true
        
        # Wait for namespace deletion
        log_info "Waiting for namespace to be deleted..."
        kubectl wait --for=delete namespace/fintech --timeout=5m || true
        
        log_success "Kubernetes resources deleted"
    else
        log_info "Fintech namespace not found"
    fi
}

# Destroy Terraform infrastructure
destroy_terraform() {
    log_info "Destroying Terraform infrastructure..."
    
    if [ ! -d "terraform" ]; then
        log_warning "Terraform directory not found"
        return
    fi
    
    cd terraform
    
    if [ ! -f "terraform.tfstate" ]; then
        log_warning "No Terraform state file found"
        cd ..
        return
    fi
    
    log_info "Running terraform destroy..."
    terraform destroy -auto-approve || {
        log_error "Terraform destroy failed"
        cd ..
        exit 1
    }
    
    log_success "Infrastructure destroyed"
    cd ..
}

# Clean local files
cleanup_local() {
    log_info "Cleaning up local files..."
    
    # Remove Terraform state
    rm -rf terraform/.terraform terraform/*.tfstate* terraform/.terraform.lock.hcl
    
    # Remove build artifacts
    rm -rf build dist *.tar.gz
    
    log_success "Local files cleaned"
}

# Delete ECR repositories
delete_ecr() {
    log_info "Deleting ECR repositories..."
    
    AWS_REGION=${AWS_REGION:-us-east-1}
    AWS_PROFILE=${AWS_PROFILE:-default}
    
    for repo in fintech-backend fintech-frontend; do
        if aws ecr describe-repositories --repository-names $repo --region $AWS_REGION --profile $AWS_PROFILE &> /dev/null; then
            log_info "Deleting ECR repository: $repo"
            aws ecr delete-repository --repository-name $repo --force --region $AWS_REGION --profile $AWS_PROFILE || true
        fi
    done
    
    log_success "ECR repositories deleted"
}

# Main
main() {
    log_warning "======================================="
    log_warning "         INFRASTRUCTURE CLEANUP         "
    log_warning "======================================="
    echo ""
    
    confirm_cleanup
    echo ""
    
    delete_kubernetes
    echo ""
    
    delete_ecr
    echo ""
    
    destroy_terraform
    echo ""
    
    cleanup_local
    echo ""
    
    log_success "Cleanup completed!"
    log_info "All infrastructure has been removed"
}

main "$@"
