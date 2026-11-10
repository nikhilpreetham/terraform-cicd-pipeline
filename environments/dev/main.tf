
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# AWS provider
provider "aws" {
  region = "ap-south-1"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Development bucket name
locals {
  bucket_name = "terraform-cicd-app-${data.aws_caller_identity.current.account_id}-ap-south-1"
}

# 1. Create S3 bucket
resource "aws_s3_bucket" "dev" {
  bucket = local.bucket_name

  tags = {
    Name        = "Terraform CI/CD Development Bucket"
    Environment = "dev"
    Project     = "terraform-cicd-pipeline"
  }
}

# 2. Enable versioning
resource "aws_s3_bucket_versioning" "dev" {
  bucket = aws_s3_bucket.dev.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Enable AES256 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "dev" {
  bucket = aws_s3_bucket.dev.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Block public access
resource "aws_s3_bucket_public_access_block" "dev" {
  bucket = aws_s3_bucket.dev.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# 5. Enforce bucket owner ownership
resource "aws_s3_bucket_ownership_controls" "dev" {
  bucket = aws_s3_bucket.dev.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
