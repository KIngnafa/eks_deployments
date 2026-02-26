module "EKS-BASE-CONTROL-PLANE" {
  source = "git::https://github.com/KIngnafa/aws-terraform-modules.git//MODULES/EKS-BASE-1/controlplane"

  cluster_name           = var.cluster_name
  cluster_version        = var.cluster_version
  endpoint_public_access = var.endpoint_public_access
  addons                 = var.addons
  private_subnet_ids     = module.VPC-BASE.private_subnet_ids
  common_tags            = local.final_tags
}

module "EKS-BASE-DATA-PLANE" {
  source = "git::https://github.com/KIngnafa/aws-terraform-modules.git//MODULES/EKS-BASE-1/dataplane/nodes"

  cluster_name       = module.EKS-BASE-CONTROL-PLANE.cluster_name
  private_subnet_ids = module.VPC-BASE.private_subnet_ids
  node_group         = var.node_group
  common_tags        = local.final_tags
}

module "VPC-BASE" {
  source = "git::https://github.com/KIngnafa/aws-terraform-modules.git//MODULES/VPC-BASE"

  vpc_name           = var.vpc_name
  public_subnets     = local.public_by_az
  private_subnets    = local.private_by_az
  single_nat_gateway = var.single_nat_gateway
  enable_nat_gateway = true
  vpc_cidr           = var.vpc_cidr
  cluster_name       = var.cluster_name

  common_tags = local.final_tags
}
