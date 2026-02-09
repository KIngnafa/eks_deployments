output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

# Helper output - copy this to your environment backend.tf files
output "backend_config" {
  description = "Backend configuration to use in environment modules"
  value       = <<-EOT

    # Copy this to your environment's backend.tf file:
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "eks/<ENVIRONMENT>/terraform.tfstate"  # Replace <ENVIRONMENT>
        region         = "${var.region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
        encrypt        = true
      }
    }
  EOT
}

# ─────────────────────────────────────────────────────────────
# GitHub Actions OIDC Outputs
# ─────────────────────────────────────────────────────────────
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions to assume"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
