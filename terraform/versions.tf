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

  # IMPORTANT: For GitHub Actions CI/CD, you MUST use a remote backend.
  # Local state does not persist between pipeline runs.
  #
  # One-time setup (run this from AWS CloudShell or any machine with AWS access):
  #
  #   aws s3api create-bucket \
  #     --bucket <YOUR-UNIQUE-BUCKET-NAME> \
  #     --region ap-south-1 \
  #     --create-bucket-configuration LocationConstraint=ap-south-1
  #
  #   aws dynamodb create-table \
  #     --table-name terraform-locks \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST \
  #     --region ap-south-1
  #
  # Then uncomment the backend block below and replace the bucket name:

  # backend "s3" {
  #   bucket         = "lucidity-terraform-state-CHANGE-ME"
  #   key            = "eks/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

