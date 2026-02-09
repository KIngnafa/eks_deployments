locals {
  enforced_tags = {
    Environment = var.environment
    OwnerEmail  = var.required_tags.OwnerEmail
    System      = var.required_tags.System
    Backup      = lower(var.required_tags.Backup)
  }

  final_tags = merge(local.enforced_tags, var.common_tags)
}

locals {
  az_count = var.environment == "prod" ? 3 : 2

  azs = slice(data.aws_availability_zones.available.names, 0, local.az_count)

  public_by_az = {
    for i, az in local.azs :
    az => cidrsubnet(var.vpc_cidr, 4, i)
  }

  private_by_az = {
    for i, az in local.azs :
    az => [
      cidrsubnet(var.vpc_cidr, 4, i + local.az_count)
    ]
  }
}
