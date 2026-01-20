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

  VPC_COMPONENTS    = var.VPC_COMPONENTS
  private_az        = local.private_by_az
  public_az         = local.public_by_az
  db_subnet_keys    = local.db_subnet_keys
  availability_zone = data.aws_availability_zones.available
  cluster_name      = local.cluster_name
}

module "SECURITY-BASE" {
  source = "git::ssh://git@github.com/KIngnafa/aws-terraform-modules.git//MODULES/SECURITY-BASE/bastion"

  vpc_id = module.VPC-BASE.vpc_id
}

