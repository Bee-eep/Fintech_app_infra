terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  oidc_provider_prefix = join(
    "/",
    slice(split("/", var.oidc_provider_arn), 1, length(split("/", var.oidc_provider_arn)))
  )
}

# IRSA (IAM Roles for Service Accounts) for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_prefix}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${local.oidc_provider_prefix}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# IRSA for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.project_name}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_prefix}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${local.oidc_provider_prefix}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "${var.project_name}-cluster-autoscaler-policy"
  role = aws_iam_role.cluster_autoscaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      }
    ]
  })
}

# IRSA for ALB Ingress Controller
resource "aws_iam_role" "alb_ingress_controller" {
  name = "${var.project_name}-alb-ingress-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_prefix}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${local.oidc_provider_prefix}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "alb_ingress_controller" {
  name = "${var.project_name}-alb-ingress-controller-policy"
  role = aws_iam_role.alb_ingress_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elbv2:CreateLoadBalancer",
          "elbv2:CreateTargetGroup",
          "elbv2:CreateListener",
          "elbv2:DeleteLoadBalancer",
          "elbv2:DeleteTargetGroup",
          "elbv2:DeleteListener",
          "elbv2:DescribeLoadBalancers",
          "elbv2:DescribeTargetGroups",
          "elbv2:DescribeListeners",
          "elbv2:ModifyLoadBalancerAttributes",
          "elbv2:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:ListCertificates",
          "acm:DescribeCertificate"
        ]
        Resource = "*"
      }
    ]
  })
}

# IRSA for External Secrets Operator
resource "aws_iam_role" "external_secrets_operator" {
  name = "${var.project_name}-external-secrets-operator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_prefix}:sub" = "system:serviceaccount:external-secrets:external-secrets"
            "${local.oidc_provider_prefix}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "external_secrets_operator" {
  name = "${var.project_name}-external-secrets-operator-policy"
  role = aws_iam_role.external_secrets_operator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
      }
    ]
  })
}

# IAM Policy for Application Pod Access to RDS
resource "aws_iam_role" "app_pod_role" {
  name = "${var.project_name}-app-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_prefix}:sub" = "system:serviceaccount:fintech:fintech-app"
            "${local.oidc_provider_prefix}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_pod_role" {
  name = "${var.project_name}-app-pod-policy"
  role = aws_iam_role.app_pod_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/fintech/*"
      }
    ]
  })
}
