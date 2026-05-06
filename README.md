# Fintech Application - DevOps Setup Guide

Production-ready fintech application deployment on AWS EKS with Kubernetes, Terraform IaC, and CI/CD automation.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Learner's Lab                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      VPC (Multi-AZ)                     │   │
│  │                   10.0.0.0/16 CIDR                      │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │          Public Subnets (3 AZs)                  │  │   │
│  │  │  ┌─────────────────────────────────────────────┐ │  │   │
│  │  │  │  ALB / NAT Gateway / Internet Gateway      │ │  │   │
│  │  │  └─────────────────────────────────────────────┘ │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  │                                                        │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │         Private Subnets (3 AZs)                 │  │   │
│  │  │  ┌─────────────────────────────────────────────┐ │  │   │
│  │  │  │  EKS Cluster / Worker Nodes                │ │  │   │
│  │  │  │  ┌────────────────┐    ┌────────────────┐  │ │  │   │
│  │  │  │  │  Backend Pods  │    │  Frontend Pods │  │ │  │   │
│  │  │  │  │  (Deployment)  │    │  (Deployment)  │  │ │  │   │
│  │  │  │  └────────────────┘    └────────────────┘  │ │  │   │
│  │  │  │  ┌────────────────┐    ┌────────────────┐  │ │  │   │
│  │  │  │  │   Prometheus   │    │   PostgreSQL   │  │ │  │   │
│  │  │  │  │  (Monitoring)  │    │   (StatefulSet)│  │ │  │   │
│  │  │  │  └────────────────┘    └────────────────┘  │ │  │   │
│  │  │  └─────────────────────────────────────────────┘ │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  │                                                        │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │  RDS PostgreSQL (Multi-AZ, Encrypted)           │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │        Container Registry (ECR)                        │   │
│  │  - fintech-backend                                     │   │
│  │  - fintech-frontend                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │        Monitoring & Logging                           │   │
│  │  - CloudWatch Logs                                     │   │
│  │  - CloudWatch Alarms                                   │   │
│  │  - Prometheus (in-cluster)                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### AWS Account
- AWS Learner's Lab access or AWS account
- IAM permissions for EKS, RDS, ECR, VPC, CloudWatch
- AWS CLI configured with credentials

### Local Machine Tools
- `aws-cli` v2.x
- `terraform` v1.6+
- `kubectl` v1.29+
- `docker` (for building images)
- `helm` v3.x (for package management)
- `git`

### GitHub
- GitHub repository (for CI/CD)
- GitHub Actions enabled
- Repository secrets configured

## Quick Start

### 1. Prerequisites Setup

```bash
# Clone the repository
git clone <repo-url>
cd fintech-devops

# Install tools
brew install awscli terraform kubectl docker helm  # macOS
# or use your system package manager

# Configure AWS credentials
aws configure --profile fintech-lab
export AWS_PROFILE=fintech-lab
```

### 2. Configure Terraform Variables

```bash
cd terraform

# Copy example terraform variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars

# Critical values to update:
# - aws_region (use your learner lab region)
# - db_username and db_password
# - alert_email for CloudWatch notifications
```

### 3. Provision Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan infrastructure
terraform plan -out=tfplan

# Apply infrastructure (this takes ~20-30 minutes)
terraform apply tfplan

# Save outputs
terraform output -json > outputs.json
```

### 4. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --name fintech-eks --region us-east-1

# Verify cluster connection
kubectl cluster-info
kubectl get nodes
```

### 5. Deploy Kubernetes Manifests

```bash
# Create namespace and deploy all manifests
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-secrets.yaml
kubectl apply -f k8s/03-postgres-init-script.yaml
kubectl apply -f k8s/03-database.yaml
kubectl apply -f k8s/04-backend.yaml
kubectl apply -f k8s/05-frontend.yaml
kubectl apply -f k8s/06-ingress.yaml
kubectl apply -f k8s/07-hpa.yaml
kubectl apply -f k8s/08-monitoring.yaml
kubectl apply -f k8s/09-rbac.yaml

# Or apply all at once
kubectl apply -f k8s/

# Verify deployments
kubectl get pods -n fintech
kubectl get services -n fintech
kubectl get ingress -n fintech
```

### 6. Build and Push Docker Images

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push backend
docker build -f Dockerfile.backend -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/fintech-backend:latest .
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/fintech-backend:latest

# Build and push frontend
docker build -f Dockerfile.frontend -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/fintech-frontend:latest .
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/fintech-frontend:latest
```

### 7. Update Kubernetes Manifests with Real ECR URLs

```bash
# Update backend deployment
kubectl set image deployment/fintech-backend \
  backend=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/fintech-backend:latest \
  -n fintech

# Update frontend deployment
kubectl set image deployment/fintech-frontend \
  frontend=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/fintech-frontend:latest \
  -n fintech
```

## Directory Structure

```
fintech-devops/
├── .github/
│   └── workflows/
│       ├── build.yaml              # Build Docker images
│       ├── deploy.yaml             # Deploy to EKS
│       └── terraform.yaml          # Provision infrastructure
├── k8s/
│   ├── 00-namespace.yaml           # Namespace & RBAC
│   ├── 01-configmap.yaml           # Configuration
│   ├── 02-secrets.yaml             # Secrets
│   ├── 03-database.yaml            # PostgreSQL StatefulSet
│   ├── 03-postgres-init-script.yaml # DB initialization
│   ├── 04-backend.yaml             # Backend deployment
│   ├── 05-frontend.yaml            # Frontend deployment
│   ├── 06-ingress.yaml             # Ingress configuration
│   ├── 07-hpa.yaml                 # Auto-scaling
│   ├── 08-monitoring.yaml          # Monitoring setup
│   └── 09-rbac.yaml                # RBAC policies
├── terraform/
│   ├── main.tf                     # Main configuration
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── terraform.tfvars.example    # Example variables
│   └── modules/
│       ├── vpc/                    # VPC module
│       ├── eks/                    # EKS cluster module
│       ├── rds/                    # RDS database module
│       ├── ecr/                    # ECR registry module
│       ├── iam/                    # IAM roles module
│       └── monitoring/             # CloudWatch module
├── Dockerfile.backend              # Backend image
├── Dockerfile.frontend             # Frontend image
├── nginx.conf                      # Nginx configuration
├── server.js                       # Node.js backend
├── package.json                    # Node.js dependencies
├── index.html                      # Frontend HTML
├── README.md                       # This file
└── scripts/
    ├── setup.sh                    # Setup script
    ├── deploy.sh                   # Deploy script
    └── cleanup.sh                  # Cleanup script
```

## Configuration

### Environment Variables

#### Backend (.env or ConfigMap)
```
DB_HOST=fintech-postgres.default.svc.cluster.local
DB_PORT=5432
DB_NAME=fintech
DB_USER=postgres
DB_PASSWORD=<from-secret>
NODE_ENV=production
LOG_LEVEL=info
API_PORT=3000
```

#### Terraform Variables (terraform.tfvars)
```hcl
aws_region               = "us-east-1"
project_name             = "fintech"
environment              = "production"
kubernetes_version       = "1.29"
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 100
db_password              = "ChangeMe!12345"
```

## Monitoring & Observability

### CloudWatch Dashboard
```bash
# Access CloudWatch dashboard
aws cloudwatch describe-dashboards --dashboard-name-prefix fintech
```

### Prometheus
```bash
# Port-forward to Prometheus
kubectl port-forward -n fintech svc/prometheus 9090:9090

# Access at http://localhost:9090
```

### Logs

```bash
# Backend logs
kubectl logs -f deployment/fintech-backend -n fintech

# Frontend logs
kubectl logs -f deployment/fintech-frontend -n fintech

# PostgreSQL logs
kubectl logs -f statefulset/fintech-postgres -n fintech
```

## Auto-Scaling

### Horizontal Pod Autoscaling (HPA)

```bash
# Check HPA status
kubectl get hpa -n fintech

# View HPA details
kubectl describe hpa fintech-backend-hpa -n fintech
```

### Cluster Auto-Scaling

Configured via Terraform. Worker nodes will scale up/down based on demand.

## Backup & Recovery

### Database Backups

Automated daily backups configured via Terraform:
- Retention: 30 days
- Window: 03:00-04:00 UTC
- Multi-AZ enabled

To restore:
```bash
# Using AWS Console or CLI
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier fintech-restored \
  --db-snapshot-identifier <snapshot-id>
```

## CI/CD Pipeline

### GitHub Actions Workflows

1. **build.yaml**: Builds Docker images, pushes to ECR
2. **deploy.yaml**: Deploys to EKS, runs health checks
3. **terraform.yaml**: Provisions/manages infrastructure

### Setting Up GitHub Secrets

```bash
# Required secrets in GitHub repository
AWS_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/... (optional)
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod <pod-name> -n fintech
kubectl logs <pod-name> -n fintech
```

### Database connection issues
```bash
# Test connection
kubectl run -it --rm debug --image=ubuntu --restart=Never -- /bin/bash
apt-get update && apt-get install -y postgresql-client
psql -h fintech-postgres -U postgres -d fintech
```

### EKS cluster issues
```bash
# Check cluster status
aws eks describe-cluster --name fintech-eks --region us-east-1

# Check worker nodes
kubectl top nodes
kubectl describe nodes
```

## Cost Optimization

### For AWS Learner's Lab
1. Use smaller instance types (t3.micro for RDS, t3.medium for worker nodes)
2. Set auto-scaling to minimize idle capacity
3. Delete resources when not in use

```bash
# Destroy all infrastructure
terraform destroy -auto-approve

# Or destroy specific resources
terraform destroy -target=aws_eks_cluster.main -auto-approve
```

## Security Best Practices

✅ Implemented:
- Network policies (Kubernetes NetworkPolicy)
- RBAC (Role-Based Access Control)
- Pod security policies
- Encrypted storage (RDS, EBS)
- Secret management (Kubernetes Secrets)
- VPC with private subnets
- IAM roles for service accounts (IRSA)
- Security groups with least privilege

⚠️ Additional recommendations:
- Use AWS Secrets Manager for production secrets
- Enable audit logging
- Use WAF (Web Application Firewall) for ALB
- Implement certificate management (ACM)
- Enable GuardDuty for threat detection
- Use AWS Systems Manager for patch management

## Performance Optimization

✅ Implemented:
- Multi-AZ deployment
- Horizontal Pod Autoscaling (HPA)
- Cluster Auto-Scaling
- Load balancing (ALB)
- Connection pooling
- Caching in nginx
- Resource limits and requests
- PodDisruptionBudgets

## Maintenance

### Update Kubernetes
```bash
# Update cluster version in terraform
# Then apply changes
terraform apply

# Update node groups
aws eks update-nodegroup-version ...
```

### Update Application
```bash
# Push new image
docker build -t $IMAGE:v2 .
docker push $IMAGE:v2

# Update deployment
kubectl set image deployment/fintech-backend backend=$IMAGE:v2 -n fintech
kubectl rollout status deployment/fintech-backend -n fintech
```

## Support & Documentation

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## Cleanup

```bash
# Delete all Kubernetes resources
kubectl delete namespace fintech

# Destroy Terraform infrastructure
cd terraform
terraform destroy -auto-approve

# Clean up local files
rm -rf .terraform terraform.tfstate*
```

## License

MIT License - See LICENSE file for details
