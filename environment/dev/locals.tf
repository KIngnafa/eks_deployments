locals {
  tags = {
    ManagedBy   = "terraform"
    Owner       = "Yinka"
    Environment = var.environment
    Project     = "eks-platform"
  }
}


locals {
  # Choose how many AZs per env (example)
  az_count = var.environment == "prod" ? 3 : 2

  azs = slice(data.aws_availability_zones.available.names, 0, local.az_count)

  # Example: make each subnet a /20 inside the /16
  # Adjust newbits/indexing to your taste.
  public_by_az = {
    for i, az in local.azs :
    az => cidrsubnet(var.vpc_cidr, 4, i)
  }

  private_by_az = {
    for i, az in local.azs :
    az => [
      cidrsubnet(var.vpc_cidr, 4, i + local.az_count)  # one private subnet per AZ
    ]
  }
}
