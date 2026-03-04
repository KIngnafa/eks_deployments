environment        = "test"
region             = "us-east-1"
vpc_cidr           = "10.30.0.0/16"
cluster_name       = "d1-test-cluster"
vpc_name           = "d1-test-vpc"
single_nat_gateway = true
cluster_version    = "1.31"
endpoint_public_access = true

assume_role_arn = "arn:aws:iam::891377046654:role/Engineer"

required_tags = {
  OwnerEmail = "yinka@company.com"
  System     = "eks-platform"
  Backup     = "yes"
}

node_group = {
  name            = "d1-test-ng"
  capacity_type   = "ON_DEMAND"
  instance_types  = ["t3.small"]
  desired_size    = 2
  min_size        = 1
  max_size        = 4
  max_unavailable = 1
}

addons = {
  "vpc-cni"            = { enabled = true }
  "coredns"            = { enabled = true }
  "kube-proxy"         = { enabled = true }
  "aws-ebs-csi-driver" = { enabled = true }
}
