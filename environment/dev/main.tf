module "EKS-BASE" {
  source = "git::ssh://git@github.com/KIngnafa/aws-terraform-modules.git//MODULES/EKS-BASE-1/controlplane"

  EKS_COMPONENTS       = var.EKS_COMPONENTS
  launch_template_name = local.launch_template_name
  private_subnet_ids   = module.VPC-BASE.private_subnet_ids
}

module "EKS-BASE-dataplane" {
  source = "git::ssh://git@github.com/KIngnafa/aws-terraform-modules.git//MODULES/EKS-BASE-1/dataplane/nodes"

  EKS_COMPONENTS       = var.EKS_COMPONENTS
  launch_template_name = local.launch_template_name
  subnet_ids           = module.VPC-BASE.private_subnet_ids
  cluster_name         = module.EKS-BASE.cluster_name
}

module "VPC-BASE" {
  source = "git::ssh://git@github.com/KIngnafa/aws-terraform-modules.git//MODULES/VPC-BASE"

  vpc_name           = var.vpc_name
  public_subnets     = local.public_by_az
  private_subnets    = local.private_by_az
  single_nat_gateway = var.single_nat_gateway
  enable_nat_gateway = true
  vpc_cidr           = var.vpc_cidr
  cluster_name       = var.cluster_name

  common_tags = local.final_tags
}

