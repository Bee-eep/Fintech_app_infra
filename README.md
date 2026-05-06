# Fintech Application
## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Learner's Lab                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                      VPC (Multi-AZ)                     │    │
│  │                   10.0.0.0/16 CIDR                      │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │          Public Subnets (3 AZs)                  │   │    │
│  │  │  ┌─────────────────────────────────────────────┐ │   │    │
│  │  │  │  ALB / NAT Gateway / Internet Gateway       │ │   │    │
│  │  │  └─────────────────────────────────────────────┘ │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  │                                                         │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │         Private Subnets (3 AZs)                  │   │    │
│  │  │  ┌─────────────────────────────────────────────┐ │   │    │
│  │  │  │  EKS Cluster / Worker Nodes                 │ │   │    │
│  │  │  │  ┌────────────────┐    ┌────────────────┐   │ │   │    │
│  │  │  │  │  Backend Pods  │    │  Frontend Pods │   │ │   │    │
│  │  │  │  │  (Deployment)  │    │  (Deployment)  │   │ │   │    │
│  │  │  │  └────────────────┘    └────────────────┘   │ │   │    │
│  │  │  │  ┌────────────────┐    ┌────────────────┐   │ │   │    │
│  │  │  │  │   Prometheus   │    │   PostgreSQL   │   │ │   │    │
│  │  │  │  │  (Monitoring)  │    │   (StatefulSet)│   │ │   │    │
│  │  │  │  └────────────────┘    └────────────────┘   │ │   │    │
│  │  │  └─────────────────────────────────────────────┘ │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  │                                                         │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │  RDS PostgreSQL (Multi-AZ, Encrypted)            │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │        Container Registry (ECR)                         │    │
│  │  - fintech-backend                                      │    │
│  │  - fintech-frontend                                     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │        Monitoring & Logging                             │    │
│  │  - CloudWatch Logs                                      │    │ 
│  │  - CloudWatch Alarms                                    │    │
│  │  - Prometheus (in-cluster)                              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

# DevOps Class Assignment - BTech CSET 452

**Author:** Apurv Jha (E23CSEU1833)

## Architecture Design

### VPC Structure
- The application runs across 2 Availability Zones (AZs) inside a custom VPC with one public and one private subnet.
- **Public Subnets:** Contain the Application Load Balancer (ALB) and NAT Gateway for internet traffic entry/exit.
- **Private Subnets:** Contain PostgreSQL, EKS nodes, and Redis.

### Service Placement

| Component | Subnet | Reason |
| :--- | :--- | :--- |
| ALB | Public | Handles incoming traffic. |
| EKS Nodes | Private | Safer, not publicly accessible. |
| PostgreSQL | Private | Contains sensitive data. |
| Redis | Private | Contains sensitive cache data. |
| NAT Gateway | Public | Provides outbound internet access. |

### Load Balancing
Traffic first reaches the ALB and then goes to Kubernetes Ingress. API traffic is routed to backend services while frontend requests go to frontend pods. This setup is easier to manage and update.

### Multi-Region Setup and Availability
Using two deployment zones:
1.  **us-east-1** (Primary)
2.  **us-west-2** (Backup)

Multi-region setup also helps with autoscaling and load balancing, eventually reducing downtime.

### Security and Cost
- **Security:** Security groups are given least privileges, and all secrets are stored in AWS Secrets Manager.
- **Cost:** An active-passive multi-region strategy is chosen over active-active for cost efficiency. The standby region uses smaller instance types and minimal node counts, scaling up only during a real failover.

## Terraform Strategy

### Module Design

| Module | Responsibility |
| :--- | :--- |
| `vpc` | VPC, public/private subnets, route tables, IGW, NAT Gateways, security groups. |
| `eks` | EKS cluster, managed node groups, IAM roles, OIDC provider, add-ons (CoreDNS, ALB controller). |
| `rds` | RDS PostgreSQL instance, subnet group, parameter group, Multi-AZ option. |
| `redis` | ElastiCache Redis cluster, subnet group, replication group for HA. |

This keeps the code cleaner and easier to manage.

### Remote State Management
- `tfstate` is stored in **S3** with **DynamoDB locking** to avoid state corruption.
- Each environment has its own state file.

### Environment Separation
Instead of workspaces, separate folders are used for each environment. This makes configuration easier and avoids mistakes.

### Multi-Region Provisioning
Terraform provider aliases are used for the secondary region. Each region has its own infrastructure and separate state file.

### Challenges
- **State Drift:** Mitigated by running `terraform plan` in CI on every pull request and enforcing no manual AWS console changes in production.
- **Region Synchronisation:** Module versions must be identical across regions. A shared module registry (or pinned Git tag) ensures both regions are on the same infrastructure version.
- **Cross-region Data Resources:** Some data sources (e.g., AMI IDs) differ per region and must use the correct provider alias, requiring careful variable templating.

## Docker and Image Strategy

### Dockerfile Optimization
- **Multi-stage builds** are used to reduce image size. Only required files are copied into the final image.
- **Docker layer caching** improves CI build speed. Dependencies are copied and installed before application code, maximizing cache usage (a code change only invalidates the last layer).

### Security
- **Non-root user:** Every Dockerfile ends with `USER node` or `USER appuser`.
- **Minimal base images:** `alpine` and `slim` variants contain only OS essentials, reducing the attack surface.
- **Vulnerability scanning:** **Trivy** is integrated into the CI pipeline and fails the build if any HIGH or CRITICAL CVEs are detected.
- **No secrets in images:** All credentials are injected at runtime via Kubernetes Secrets or AWS Secrets Manager.

### Image Versioning
Images are stored in **Amazon ECR**, which integrates natively with IAM for access control and supports automatic lifecycle policies.

### CI/CD Integration
On every push to the `main` or `release/*` branch, GitHub Actions builds the image, runs Trivy scanning, pushes to ECR, and then ArgoCD deploys the latest version to Kubernetes.

## Kubernetes Deployment

### Zero Downtime Deployment
- **RollingUpdates** are used on all pods so new pods are ready before old ones stop.
- **Readiness probes** ensure no traffic is routed to a new pod until it passes its readiness check.
- **Liveness probes** restart pods that are in a deadlock or hung state.

### Autoscaling
- **Horizontal Pod Autoscaling (HPA):** Scales pods based on:
    1.  CPU utilization (Target 60%).
    2.  Custom request-rate metric via Prometheus Adapter.
- **Cluster Autoscaler:** Adds or removes nodes based on pod resource requests.

### Secret Management
Kubernetes Secrets are stored in AWS Secrets Manager and synced to K8s using the **External Secrets Operator**.

### Inter-Service Communication
- All services communicate internally using **ClusterIP** services and DNS names.
- **Istio** service mesh provides mTLS security, retries, and timeout policies between pods.
- **Network policies** restrict pod communication (e.g., frontend pods cannot directly access the database).

### GitOps with ArgoCD
Argo CD constantly checks the Kubernetes manifests in Git repositories. After image tags are updated by GitHub Actions, Argo CD immediately pushes the updates to the cluster. Rollbacks are performed by reverting Git commits.

## CI/CD Pipeline

### Overview
GitHub Actions handles testing, image building, and security scans. Argo CD handles deployments to Kubernetes.

| Stage | Trigger | What Happens |
| :--- | :--- | :--- |
| Lint & Unit Tests | Every push / PR | ESLint, unit tests, code coverage check; fails fast on any error. |
| Build Docker Image | Push to `main` or `release/*` | Multi-stage Docker build using cached layers. |
| Security Scan | After build | Trivy scans image; pipeline fails on HIGH/CRITICAL CVEs. |
| Push to ECR | After scan passes | Image pushed with commit SHA tag and branch tag. |
| Update GitOps Repo | After push | Automated PR or direct commit updating image tag in manifests repo. |

### Argo CD Stages
1.  **Sync Detection:** Argo CD polls the GitOps repo every 3 minutes (or via webhook) and detects image tag changes.
2.  **Progressive Rollout:** Argo CD Rollouts are used for canary deployments in production (e.g., 10% traffic to new version first with automated analysis).
3.  **Health Gates:** Argo CD checks the health of all Deployments, Services, and Ingress resources before marking a sync as Healthy.

### Failure and Rollback
If vulnerabilities or deployment failures occur, the rollout is stopped automatically. Rollbacks are done by reverting Git commits.

## Failure and Failover

**Scenario:** Primary Region (us-east-1) becomes unavailable.

### Traffic Failover
Route 53 health checks monitor the primary region. If it fails, traffic is redirected to the backup region.

### Data Consistency Between Regions
- **Cross-region RDS replicas** are used for disaster recovery. Replication is asynchronous, so some data loss may occur.
- After failover, when `us-east-1` recovers, a controlled failback process re-syncs data and redirects Route 53 back to the primary manually to avoid split-brain scenarios.

### Tools & Services Summary

| Concern | Tool / Service |
| :--- | :--- |
| DNS failover | Amazon Route 53 with health checks. |
| Health monitoring | Route 53 health checks + CloudWatch alarms. |
| Database replication | RDS Cross-Region Read Replica, promoted on failover. |
| Object storage replication | S3 Cross-Region Replication (CRR). |
| Secondary cluster readiness | Terraform-provisioned standby EKS cluster (low capacity). |
| Alerting during failover | PagerDuty + Slack (via CloudWatch alarms). |

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

