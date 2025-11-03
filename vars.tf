locals {
  cluster_name          = var.EKS_COMPONENTS["cluster_name"]
  nat_gateway_name      = "${local.cluster_name}-${var.EKS_COMPONENTS["nat_gateway_name"]}"
  internet_gateway_name = "${local.cluster_name}-${var.VPC_COMPONENTS["igw_name"]}"
  worker_node_name      = "${local.cluster_name}-${var.EKS_COMPONENTS["node_name"]}"
  launch_template_name  = "${var.EKS_COMPONENTS["cluster_name"]}-${var.EKS_COMPONENTS["launch_template_name"]}"
}

variable "EKS_COMPONENTS" {
  type        = map(string)
  description = "Map containing standard EC2 components"
  default = {
    #cluster
    cluster_name           = "D1-cluster"
    cluster_version        = "1.31"
    endpoint_public_access = true
    nat_gateway_name       = "ngw"
    private_rt_name        = "private_rt"
    cluster_igw            = "igw"
    public_rt_name         = "public_rt"

    ##node group
    capacity_type        = "ON_DEMAND"
    node_group_name      = "private_node_group"
    instance_types       = "t3.small"
    desired_size         = 2
    max_size             = 3
    min_size             = 2
    node_name            = "worker-node"
    launch_template_name = "launch_template"
    #update_config
    max_unavailable = 1

  }
}

#VPC
variable "VPC_COMPONENTS" {
  type        = map(string)
  description = "Map containing standard EC2 components"

  default = {

    vpc_cidr_block          = "10.0.0.0/16"
    enable_dns_hostnames    = true
    enable_dns_support      = true
    vpc_name                = "D1-vpc"
    igw_name                = "D1-IGW"
    db_subnet_group_name    = "app_db_subnet_group"
    domain                  = "vpc"
    route_table_cidr        = "0.0.0.0/0"
    route_table_tag_public  = "public_rt"
    route_table_tag_private = "private_rt"
  }
}

variable "EC2_COMPONENTS" {
  type        = map(string)
  description = "Map containing standard EC2 components"
  default = {
    image_id                    = "ami-0a3de17ca0cb151be"
    instance_type               = "t2.micro"
    min_size                    = 2
    max_size                    = 2
    desired_capacity            = 2
    encrypted                   = "true"
    volume_size                 = 30
    volume_type                 = "gp2"
    delete_on_termination       = true
    associate_public_ip_address = true
    iam_instance_profile        = "EC2_TO_S3_ADMIN"
    key_name                    = "stack_devops_man"
    tag_bastion                 = "dev_bastion"
    tag_db                      = "ACT6_DB"
  }
}

variable "public_cidrs" {
  type = object({
    az1 = string
    az2 = string
  })
  default = {
    az1 = "10.0.0.0/24"
    az2 = "10.0.1.0/24"
  }

  validation {
    condition     = can(cidrnetmask(var.public_cidrs.az1)) && can(cidrnetmask(var.public_cidrs.az2))
    error_message = "public_cidrs.az1 and az2 must be valid CIDR blocks."
  }
}

variable "private_cidrs" {
  type = object({
    az1 = list(string)
    az2 = list(string)
  })
  default = {
    az1 = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24", "10.0.14.0/24"]
    az2 = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24", "10.0.24.0/24"]
  }

  validation {
    condition     = length(var.private_cidrs.az1) == 5 && length(var.private_cidrs.az2) == 5
    error_message = "Provide exactly 5 private CIDRs for az1 and 5 for az2."
  }
  validation {
    condition     = alltrue([for c in concat(var.private_cidrs.az1, var.private_cidrs.az2) : can(cidrnetmask(c))])
    error_message = "All private_cidrs entries must be valid CIDR blocks."
  }
}
