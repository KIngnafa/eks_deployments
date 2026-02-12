variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "test", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, uat, prod."
  }
}

variable "region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "assume_role_arn" {
  description = "IAM role Terraform will assume for this environment"
  type        = string
}

variable "common_tags" {
  description = "EKS addons configuration keyed by addon name"
  type        = map(string)
  default     = {}
}

variable "required_tags" {
  description = "Tags required to be specified on all resources"
  type = object({
    OwnerEmail = string
    System     = string
    Backup     = string
  })

  validation {
    condition     = var.required_tags.OwnerEmail != "" && var.required_tags.OwnerEmail == lower(var.required_tags.OwnerEmail)
    error_message = "OwnerEmail must be lowercase and non-empty."
  }

  validation {
    condition     = contains(["yes", "no"], lower(var.required_tags.Backup))
    error_message = "Backup must be either 'yes' or 'no' (case-insensitive)."
  }
}


variable "vpc_cidr" {
  description = "Netowrk cidr variable"
  type        = string
}

variable "vpc_name" {
  type = string
}

variable "single_nat_gateway" {
  type = bool
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}


variable "endpoint_public_access" {
  type = bool
}

variable "addons" {
  description = "EKS addons configuration keyed by addon name"
  type = map(object({
    enabled           = bool
    version           = optional(string)
    resolve_conflicts = optional(string)
  }))
  default = {}
}

variable "node_group" {
  description = "EKS managed node group configuration"
  type = object({
    name            = string
    capacity_type   = string
    instance_types  = list(string)
    desired_size    = number
    min_size        = number
    max_size        = number
    max_unavailable = number
  })
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
