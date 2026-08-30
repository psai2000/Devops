terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Uncomment and configure for remote state (recommended for team use)
  # backend "s3" {
  #   bucket         = "lucidity-terraform-state"
  #   key            = "eks/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

