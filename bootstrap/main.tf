
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# --------------------------------------------------
# AWS PROVIDER
# --------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# Get the current AWS account ID
data "aws_caller_identity" "current" {}

# Development bucket naming
locals {
  dev_bucket_name = "terraform-cicd-app-${data.aws_caller_identity.current.account_id}-ap-south-1"

  dev_bucket_arn = "arn:aws:s3:::${local.dev_bucket_name}"
}

# --------------------------------------------------
# 1. S3 BUCKET FOR TERRAFORM REMOTE STATE
# --------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  tags = {
    Name        = "Terraform Remote State"
    Environment = "bootstrap"
    Project     = "terraform-cicd-pipeline"
  }
}

# Enable S3 bucket versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------
# 2. GITHUB ACTIONS OIDC PROVIDER
# --------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name    = "GitHub Actions OIDC"
    Project = "terraform-cicd-pipeline"
  }
}

# --------------------------------------------------
# 3. GITHUB ACTIONS IAM ROLE
# --------------------------------------------------

resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            "token.actions.githubusercontent.com:sub" = "repo:${split("/", var.github_repository)[0]}@${var.github_owner_id}/${split("/", var.github_repository)[1]}@${var.github_repository_id}:environment:${var.github_environment}"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "GitHub Actions Terraform Deployment"
    Project = "terraform-cicd-pipeline"
  }
}

# --------------------------------------------------
# 4. GITHUB ACTIONS PERMISSIONS
# --------------------------------------------------

resource "aws_iam_role_policy" "github_s3_access" {
  name = "github-terraform-s3-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # Terraform remote state bucket listing
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}"
        ]

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "dev/*"
            ]
          }
        }
      },

      # Terraform state file permissions
      {
        Sid    = "TerraformStateObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}/dev/terraform.tfstate"
        ]
      },

      # Terraform native S3 lockfile permissions
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}/dev/terraform.tfstate.tflock"
        ]
      },

      # Allow creation of development S3 buckets in ap-south-1
      {
        Sid      = "CreateDevBucket"
        Effect   = "Allow"
        Action   = "s3:CreateBucket"
        Resource = "arn:aws:s3:::*"

        Condition = {
          StringEquals = {
            "s3:LocationConstraint" = "ap-south-1"
          }
        }
      },

      # Manage the designated development bucket
      {
        Sid    = "ManageDevBucket"
        Effect = "Allow"

        Action = [
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:ListBucket",

          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",

          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",

          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",

          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls",

          "s3:GetBucketTagging",
          "s3:PutBucketTagging"
        ]

        Resource = [
          local.dev_bucket_arn
        ]
      },

      # Manage objects inside the development bucket
      {
        Sid    = "ManageDevBucketObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${local.dev_bucket_arn}/*"
        ]
      }
    ]
  })
}
