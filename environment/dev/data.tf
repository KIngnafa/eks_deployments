data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az1_name = data.aws_availability_zones.available.names[0]
  az2_name = data.aws_availability_zones.available.names[1]
  az1_id   = data.aws_availability_zones.available.zone_ids[0]
  az2_id   = data.aws_availability_zones.available.zone_ids[1]

  public_by_az = {
    (local.az1_name) = var.public_cidrs.az1
    (local.az2_name) = var.public_cidrs.az2
  }

  private_by_az = merge(
    { for i, cidr in var.private_cidrs.az1 : "${local.az1_name}-${i + 1}" => { az_name = local.az1_name, az_id = local.az1_id, cidr = cidr } },
    { for i, cidr in var.private_cidrs.az2 : "${local.az2_name}-${i + 1}" => { az_name = local.az2_name, az_id = local.az2_id, cidr = cidr } }
  )

  db_subnet_keys = [
    "${local.az1_name}-2",
    "${local.az2_name}-2",
  ]
}

data "aws_ami" "stack_ami" {
  owners      = ["self"]
  name_regex  = "^ami-stack-2"
  most_recent = true
  filter {
    name   = "name"
    values = ["ami-stack-2"]
  }
}
