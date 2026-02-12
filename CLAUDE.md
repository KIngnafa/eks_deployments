# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## User Preferences

- **Do not make file changes without explicit user approval.** Always explain proposed changes first and wait for confirmation before writing, editing, or deleting files.

## Project Overview

This is an AWS EKS Terraform deployment project that provisions EKS clusters with VPC networking using remote modules from `github.com/KIngnafa/aws-terraform-modules`.

## Common Commands

```bash
# Initialize Terraform (from environment directory)
cd environment/dev
terraform init

# Plan with environment-specific variables
terraform plan -var-file="../common.tfvars" -var-file="dev.tfvars"

# Apply changes
terraform apply -var-file="../common.tfvars" -var-file="dev.tfvars"

# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Connect to EKS cluster after deployment
aws eks update-kubeconfig --name d1-dev-cluster --region us-east-1

# Apply Kubernetes manifests
kubectl apply -f ../../k8s/
```

## Architecture

### Directory Structure

- `environment/` - Environment-specific configurations (dev, test, uat, prod)
- `environment/common.tfvars` - Shared variables across all environments
- `environment/<env>/` - Per-environment Terraform root modules
- `k8s/` - Kubernetes manifest files for post-deployment resources
- `scripts/` - Helper scripts (e.g., bastion setup)

### Module Architecture

The project uses three remote Git modules:

1. **EKS-BASE-CONTROL-PLANE** (`MODULES/EKS-BASE-1/controlplane`)
   - EKS cluster creation
   - OIDC provider for IRSA (IAM Roles for Service Accounts)
   - EKS addons (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver)
   - IAM role for AWS Load Balancer Controller

2. **EKS-BASE-DATA-PLANE** (`MODULES/EKS-BASE-1/dataplane/nodes`)
   - Managed node groups with launch templates
   - Worker node IAM roles and policies
   - Node group scaling configuration

3. **VPC-BASE** (`MODULES/VPC-BASE`)
   - VPC with public/private subnets across AZs
   - NAT gateway configuration
   - Route tables and internet gateway

### Variable Files

Two-tier variable system:
- `common.tfvars` - Project-wide settings (region, tags, addons)
- `<env>.tfvars` - Environment-specific overrides (cluster name, VPC CIDR, node sizing)

### Tagging Strategy

Required tags enforced via validation:
- `OwnerEmail` - Must be lowercase
- `System` - Application/platform identifier
- `Backup` - Must be "yes" or "no"

### IRSA Configuration

OIDC provider is pre-configured for:
- AWS Load Balancer Controller (`system:serviceaccount:kube-system:aws-load-balancer-controller-sa`)
- EBS CSI Driver (via addon configuration)

## Environment Support

Valid environments: `dev`, `test`, `uat`, `prod`

Production (`prod`) automatically provisions 3 AZs; other environments use 2 AZs.

## AWS Provider

Provider assumes an IAM role specified by `assume_role_arn` variable. Region is hardcoded to `us-east-1`.
