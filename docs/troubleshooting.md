# Troubleshooting

This document records problems that actually happened while building the pipeline, and lists common issues with their checks. The full run history is visible in the repository's **Actions** tab.

## Issues encountered

### 1. First CD runs failed at `terraform plan`

| | |
|---|---|
| When | First deployments after the CD workflow was added (four runs) |
| Failed step | **Terraform Plan**: `Terraform exited with code 1` |
| Cause | The deployment role did not yet have all the S3 permissions Terraform needs to plan the development bucket (the exact errors are in those runs' logs) |
| Fix | Expanded the role's S3 permissions in `bootstrap/main.tf`, re-applied bootstrap locally, and re-ran CD, which then succeeded. The policy change was committed in `f4ef5a0` (PR #1) |

**Lesson:** the AWS provider reads many bucket settings during `plan` (ACL, CORS, website, logging, lifecycle, replication, encryption, object lock, tagging and more), even for settings the configuration does not use. A least-privilege role must allow all of those `s3:Get*` reads on the managed bucket. These are the read actions now listed in the `ManageDevBucket` statement.

### 2. CD failed after moving values to repository variables

| | |
|---|---|
| When | After PR #3 moved the role ARN and bucket name out of the code |
| Failed step | **Check required repository variables** |
| Error | `Set the AWS_ROLE_ARN and TF_STATE_BUCKET repository variables` |
| Cause | The variables had not been created yet. On the next attempt, the role ARN had been saved as a single variable named `ID` with the value `AWS_ROLE_ARN = arn:aws:iam::...`, and `TF_STATE_BUCKET` was still missing |
| Fix | Deleted `ID` and created two repository variables, `AWS_ROLE_ARN` and `TF_STATE_BUCKET`, each holding only its value. The re-run passed every step |

**Lesson:** the early check step made this failure obvious and safe. The job stopped before any AWS call or Terraform command.

## Common issues

| Symptom | Likely cause | Check |
|---|---|---|
| `Could not assume role with OIDC` / `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The OIDC `sub` claim does not match the trust policy | The job must use `environment: dev`; `github_owner_id` and `github_repository_id` in bootstrap must be the numeric IDs of this repository; `id-token: write` must be in the workflow permissions |
| `Credentials could not be loaded` | `id-token: write` permission missing | `permissions:` block in `terraform-cd.yml` |
| `Error acquiring the state lock` | A previous run stopped while holding the lock, or two runs overlapped | Wait for the other run; if no run is active, delete `dev/terraform.tfstate.tflock` from the state bucket, or run `terraform force-unlock <LOCK_ID>` locally |
| `AccessDenied` on `s3:ListBucket` for the state bucket | The backend key prefix is outside `dev/` | `key` in `backend.tf` must start with `dev/` |
| `AccessDenied` on the dev bucket | Bucket name in `environments/dev` differs from `local.dev_bucket_name` in bootstrap | Compare both names; both use the account ID and region |
| `Backend configuration changed` when running locally | The bucket is no longer in `backend.tf` | `terraform init -reconfigure -backend-config=backend.hcl` |
| CI fails on `terraform fmt -check` | Unformatted files | Run `terraform fmt -recursive` and commit |
| CI fails on TFLint | Unused declarations or other lint findings | Run `tflint --recursive` locally |
| CD did not run after a merge | No changed files under `bootstrap/`, `environments/dev/` or the CD workflow | Start it manually: **Actions > Terraform CD > Run workflow** |

## Useful commands

```powershell
# Confirm local credentials
aws sts get-caller-identity

# Inspect remote state objects
aws s3 ls s3://<state-bucket>/dev/

# Bootstrap outputs (role ARN, state bucket)
cd bootstrap
terraform output

# Local plan against the remote state
cd ../environments/dev
terraform init -backend-config=backend.hcl
terraform plan
```
