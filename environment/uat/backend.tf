terraform {
  backend "s3" {
    bucket         = "d1-eks-terraform-state-975050060097"
    key            = "eks/uat/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "d1-eks-terraform-locks"
    encrypt        = true
  }
}
