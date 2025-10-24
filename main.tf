# module "EKS-BASE" {
#   source = "git::https://github.com/KIngnafa/STACK_MODULES.git//MODULES/EKS-BASE?ref=v0.1.0-clean"

#   EKS_COMPONENTS       = var.EKS_COMPONENTS
#   launch_template_name = local.launch_template_name


# }

module "VPC-BASE" {
  source = "git::https://github.com/KIngnafa/STACK_MODULES.git//MODULES/VPC-BASE?ref=main"

  VPC_COMPONENTS      = var.VPC_COMPONENTS
  public_by_az        = local.public_by_az
  private_by_az       = local.private_by_az
  db_subnet_keys      = local.db_subnet_keys
  public_subnet_cidrs = var.public_cidrs
}
