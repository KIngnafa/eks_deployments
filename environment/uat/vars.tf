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
  description = "Common tags to apply to all resources"
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
  description = "Network CIDR for VPC"
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
