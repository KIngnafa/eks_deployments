environment        = "prod"
region             = "us-east-1"
vpc_cidr           = "10.50.0.0/16"
cluster_name       = "d1-prod-cluster"
vpc_name           = "d1-prod-vpc"
single_nat_gateway = false  # HA: NAT gateway per AZ
cluster_version    = "1.31"
endpoint_public_access = false  # Private endpoint only for production

assume_role_arn = "arn:aws:iam::891377046654:role/Engineer"

required_tags = {
  OwnerEmail = "yinka@company.com"
  System     = "eks-platform"
  Backup     = "yes"
}

node_group = {
  name            = "d1-prod-ng"
  capacity_type   = "ON_DEMAND"
  instance_types  = ["t3.medium", "t3.large"]  # Multiple types for flexibility
  desired_size    = 3
  min_size        = 3
  max_size        = 10
  max_unavailable = 1
}

addons = {
  "vpc-cni"            = { enabled = true }
  "coredns"            = { enabled = true }
  "kube-proxy"         = { enabled = true }
  "aws-ebs-csi-driver" = { enabled = true }
}
