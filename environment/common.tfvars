project_name = "baseline"
region = "us-east-1"

common_tags = {
  ManagedBy = "terraform"
  Owner     = "Yinka"
}

required_tags = {
  OwnerEmail = "yinka@company.com"
  System     = "eks-platform"
  Backup     = "yes"
}
cluster_version = "1.31"

endpoint_public_access = true

addons = {
  "vpc-cni"            = { enabled = true }
  "coredns"            = { enabled = true }
  "kube-proxy"         = { enabled = true }
  "aws-ebs-csi-driver" = { enabled = true }
}
