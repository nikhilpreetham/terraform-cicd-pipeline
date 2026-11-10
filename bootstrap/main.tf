
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
  region = var.aws_region
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Resource names and ARNs
locals {
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket_name}"

  dev_bucket_name = "terraform-cicd-app-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  dev_bucket_arn  = "arn:aws:s3:::${local.dev_bucket_name}"

  dev_bucket_objects_arn = "${local.dev_bucket_arn}/*"

  github_owner_name = split("/", var.github_repository)[0]
  github_repo_name  = split("/", var.github_repository)[1]

  github_oidc_subject = "repo:${local.github_owner_name}@${var.github_owner_id}/${local.github_repo_name}@${var.github_repository_id}:environment:${var.github_environment}"
}

# --------------------------------------------------
# 1. Terraform remote state bucket
# --------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  tags = {
    Name        = "Terraform Remote State"
    Environment = "bootstrap"
    Project     = "terraform-cicd-pipeline"
  }
}

# Enable versioning for state recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt Terraform state
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# --------------------------------------------------
# 2. GitHub Actions OIDC provider
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
# 3. IAM role assumed by GitHub Actions
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

            "token.actions.githubusercontent.com:sub" = local.github_oidc_subject
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
# 4. GitHub Actions IAM permissions
# --------------------------------------------------

resource "aws_iam_role_policy" "github_s3_access" {
  name = "github-terraform-s3-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # Terraform state bucket listing
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          local.state_bucket_arn
        ]

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "dev/*"
            ]
          }
        }
      },

      # Terraform state file access
      {
        Sid    = "TerraformStateObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = [
          "${local.state_bucket_arn}/dev/terraform.tfstate"
        ]
      },

      # Terraform native S3 state locking
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${local.state_bucket_arn}/dev/terraform.tfstate.tflock"
        ]
      },

      # Create development bucket
      {
        Sid    = "CreateDevBucket"
        Effect = "Allow"

        Action = [
          "s3:CreateBucket"
        ]

        Resource = [
          "arn:aws:s3:::*"
        ]

        Condition = {
          StringEquals = {
            "s3:LocationConstraint" = var.aws_region
          }
        }
      },

      # Manage designated development bucket
      {
        Sid    = "ManageDevBucket"
        Effect = "Allow"

        Action = [
          # Bucket management
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:ListBucket",

          # Bucket configuration reads
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketWebsite",
          "s3:GetBucketVersioning",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketLogging",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketTagging",

          # Versioning
          "s3:PutBucketVersioning",

          # Encryption
          "s3:PutEncryptionConfiguration",

          # Public access block
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",

          # Ownership controls
          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls",

          # Bucket tags
          "s3:PutBucketTagging",

          # S3 Control tagging APIs
          "s3:ListTagsForResource",
          "s3:TagResource",
          "s3:UntagResource"
        ]

        Resource = [
          local.dev_bucket_arn
        ]
      },

      # Manage objects inside development bucket
      {
        Sid    = "ManageDevBucketObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          local.dev_bucket_objects_arn
        ]
      }
    ]
  })
}
