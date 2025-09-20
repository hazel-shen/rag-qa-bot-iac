# versions.tf
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.73"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

# Budgets 是全球服務，API 位於 us-east-1
provider "aws" {
  alias   = "budgets"
  region  = var.global_region
  profile = var.profile
}
