variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "assume_role_arn" {
  description = "IAM role Terraform will assume (optional - skip if already authenticated)"
  type        = string
  default     = null
}

variable "state_bucket_name" {
  description = "Name of S3 bucket for Terraform state (must be globally unique)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-lock"
}
