# Implementation Details

This document describes how the pipeline was built, the full resource inventory, and how the pieces connect. The Terraform code and workflow files are the source of truth.

## Build timeline

The repository history shows how the project was built step by step, using pull requests into `main`.

| Step | Commit / PR | Change |
|---|---|---|
| 1 | `db4d7fa` | Initial project structure |
| 2 | `2e169e7` | Bootstrap configuration and development environment |
| 3 | `4105f05` | Terraform CI workflow (fmt, init, validate) |
| 4 | `8db650a` | Terraform CD workflow with AWS OIDC |
| 5 | `f4ef5a0`, PR #1 | Expanded the deployment role's S3 permissions after the first CD runs failed at `terraform plan`, and updated the README |
| 6 | PR #2 | Rewrote the README, added `environments/dev` variables and outputs, `bootstrap/terraform.tfvars.example`, and a TFLint step in CI |
| 7 | PR #3 | Moved the role ARN and state bucket name to GitHub repository variables, masked the account ID in logs, added the MIT license |

## Two configurations

| | `bootstrap/` | `environments/dev/` |
|---|---|---|
| Purpose | Creates what the pipeline needs to run | The infrastructure the pipeline deploys |
| Applied by | An admin, from a local terminal | GitHub Actions (Terraform CD) |
| State | Local `terraform.tfstate` (not committed) | Remote, `dev/terraform.tfstate` in the S3 state bucket |
| Credentials | The admin's AWS CLI profile | Temporary credentials from OIDC |

Bootstrap uses local state because the remote state bucket does not exist until bootstrap creates it.

## Resource inventory

### bootstrap (7 resources + 1 data source)

| Address | AWS resource | Key settings |
|---|---|---|
| `data.aws_caller_identity.current` | Data source | Current account ID, used to build the dev bucket name |
| `aws_s3_bucket.terraform_state` | S3 bucket | `var.state_bucket_name` |
| `aws_s3_bucket_versioning.terraform_state` | Versioning | Enabled |
| `aws_s3_bucket_server_side_encryption_configuration.terraform_state` | Encryption | `AES256` |
| `aws_s3_bucket_public_access_block.terraform_state` | Public access block | All four settings `true` |
| `aws_iam_openid_connect_provider.github` | OIDC provider | `https://token.actions.githubusercontent.com`, client ID `sts.amazonaws.com` |
| `aws_iam_role.github_actions` | IAM role | `github-actions-terraform-deploy` |
| `aws_iam_role_policy.github_s3_access` | Inline policy | `github-terraform-s3-access` |

### environments/dev (5 resources + 1 data source)

| Address | AWS resource | Key settings |
|---|---|---|
| `data.aws_caller_identity.current` | Data source | Current account ID |
| `aws_s3_bucket.dev` | S3 bucket | `terraform-cicd-app-<account-id>-<region>` |
| `aws_s3_bucket_versioning.dev` | Versioning | Enabled |
| `aws_s3_bucket_server_side_encryption_configuration.dev` | Encryption | `AES256` |
| `aws_s3_bucket_public_access_block.dev` | Public access block | All four settings `true` |
| `aws_s3_bucket_ownership_controls.dev` | Ownership controls | `BucketOwnerEnforced` |

## How the names line up

Several values must match across files. A mismatch causes `AccessDenied` or an OIDC login failure.

| Value | Defined in | Must match |
|---|---|---|
| Dev bucket name | `environments/dev/main.tf` (`local.bucket_name`) | `local.dev_bucket_name` in `bootstrap/main.tf`, which scopes the IAM policy |
| State key | `environments/dev/backend.tf` (`dev/terraform.tfstate`) | The state object and lock file ARNs in the IAM policy |
| GitHub environment | `environment: dev` in `terraform-cd.yml` | `var.github_environment` in bootstrap (OIDC `sub` claim) |
| Role ARN | `AWS_ROLE_ARN` repository variable | Bootstrap output `github_actions_role_arn` |
| State bucket | `TF_STATE_BUCKET` repository variable | Bootstrap output `terraform_state_bucket` |

## CD workflow, step by step

| # | Step | What happens |
|---|---|---|
| 1 | Checkout repository | `actions/checkout@v4` |
| 2 | Setup Terraform | `hashicorp/setup-terraform@v3`, version `1.15.8` |
| 3 | Check required repository variables | Fails early with a clear error if `AWS_ROLE_ARN` or `TF_STATE_BUCKET` is empty |
| 4 | Configure AWS credentials using OIDC | Requests a GitHub OIDC token and calls `AssumeRoleWithWebIdentity`; `mask-aws-account-id: true` hides the account ID in later log lines |
| 5 | Verify AWS identity | `aws sts get-caller-identity` |
| 6 | Terraform Initialize | `terraform init -backend-config="bucket=$TF_STATE_BUCKET"` |
| 7 | Terraform Plan | `terraform plan -out=tfplan` |
| 8 | Terraform Apply | `terraform apply -auto-approve tfplan`; applies exactly the saved plan |

The job runs in the `dev` GitHub environment, which is required for the OIDC subject claim to match the role's trust policy.
