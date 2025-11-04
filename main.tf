module "EKS-BASE" {
  source = "git::ssh://git@github.com/KIngnafa/aws-terraform-modules.git//MODULES/EKS-BASE-1"

  EKS_COMPONENTS       = var.EKS_COMPONENTS
  launch_template_name = local.launch_template_name
  private_subnet_ids   = module.VPC-BASE.private_subnet_ids
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

# module "SECURITY-BASE" {
#   source = "git::ssh://git@github.com/KIngnafa/aws-terraform-modules.git//MODULES/SECURITY-BASE/bastion"

#   vpc_id = module.VPC-BASE.vpc_id
# }

# module "EC2-BASE" {
#   source = "git::ssh://git@github.com/KIngnafa/aws-terraform-modules.git//MODULES/EC2-BASE"

#   EC2_COMPONENTS = var.EC2_COMPONENTS
#   security_group = module.SECURITY-BASE.bastion_sg_id
#   public_az      = module.VPC-BASE.public_subnets
#   ami            = data.aws_ami.stack_ami.id
# }
