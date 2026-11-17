terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # TODO: Bật Remote Backend S3 khi làm việc trong nhóm hoặc môi trường CI/CD
  # backend "s3" {
  #   bucket         = "nt548-terraform-state-bucket"
  #   key            = "mongodb-cluster/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   dynamodb_table = "nt548-terraform-locks"
  #   encrypt        = true
  # }
}

