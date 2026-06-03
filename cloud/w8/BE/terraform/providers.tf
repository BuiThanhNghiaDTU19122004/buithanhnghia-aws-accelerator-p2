terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3       = var.floci_endpoint
    dynamodb = var.floci_endpoint
    sqs      = var.floci_endpoint
    events   = var.floci_endpoint
    lambda   = var.floci_endpoint
    iam      = var.floci_endpoint
    apigateway = var.floci_endpoint
    sns      = var.floci_endpoint
    cloudwatch = var.floci_endpoint
  }
}
