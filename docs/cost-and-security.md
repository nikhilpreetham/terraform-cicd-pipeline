# Cost and Security Review

## Cost

The pipeline uses only S3, IAM and GitHub Actions, so running costs are very low. Check the [AWS Pricing Calculator](https://calculator.aws/) for current S3 prices in `ap-south-1`.

| Resource | Billing | Notes |
|---|---|---|
| S3 state bucket | Storage + requests | State files are a few KB; versioning keeps every version, so old versions add up slowly |
| S3 development bucket | Storage + requests | Empty bucket; no cost until objects are stored |
| IAM role, policy, OIDC provider | No charge | |
| GitHub Actions | Minutes | Free for public repositories; private repositories include a monthly allowance |

**Cost controls:** add an S3 lifecycle rule to expire noncurrent state versions after a set number of days, and run the cleanup steps in the README when the project is no longer needed.

## Security

### Controls in place

| Control | Implementation |
|---|---|
| No long-lived AWS keys | GitHub Actions gets temporary credentials through OIDC (`AssumeRoleWithWebIdentity`) |
| Narrow trust policy | Audience `sts.amazonaws.com`; subject pinned to this repository's immutable owner and repository IDs and the `dev` environment |
| Least-privilege permissions | The role can only read and write `dev/terraform.tfstate` and its lock file, and manage the one development bucket |
| Read-only CI | `terraform-ci.yml` has `contents: read` and no AWS credentials, so pull request code never reaches AWS |
| No account ID in code | Role ARN and state bucket name are GitHub repository variables; `mask-aws-account-id: true` hides the account ID in run logs |
| Protected state | State bucket is versioned, encrypted (`AES256`) and blocks all public access; backend uses `encrypt = true` |
| Safe concurrency | `concurrency` group `terraform-dev-deployment` plus native S3 locking (`use_lockfile = true`) |
| Saved-plan apply | CD applies the exact `tfplan` it just created, not a fresh plan |
| Nothing sensitive committed | `.gitignore` excludes `*.tfstate*`, `*.tfvars`, `backend.hcl`, `*.tfplan`, `.terraform/`, keys and credentials |

### Public repository considerations

- **Fork pull requests** run Terraform CI only. CI has read-only permissions and no AWS access, and the role's trust policy accepts only jobs in this repository's `dev` environment.
- **Repository variables** are not shown to visitors, but they are not secret. They hold identifiers (role ARN, bucket name), not credentials.
- **Run logs** of a public repository can be read by anyone signed in to GitHub. Runs created before PR #3 used a hard-coded role ARN and print the account ID in the "Verify AWS identity" step. AWS account IDs are identifiers, not credentials, and the role cannot be assumed from outside this repository.
- **Early commits** contain the account ID in `backend.tf` and `terraform-cd.yml`. The current files do not.

### Gaps and recommended hardening

| Gap | Recommendation |
|---|---|
| `s3:CreateBucket` allowed on `arn:aws:s3:::*` (limited by region) | Restrict the resource to the development bucket ARN |
| Apply runs with `-auto-approve` | Add **Required reviewers** to the `dev` environment so each apply waits for approval |
| No plan visible on pull requests | Add a read-only plan role trusted for pull requests and post the plan as a PR comment |
| Bootstrap state is local | Keep a secure backup, or migrate bootstrap state into the state bucket after creation |
| No static security scanning | Add `checkov` or `tfsec` to CI |
| SSE-S3 encryption | Use SSE-KMS with a customer-managed key if key-level access control is required |
| No lifecycle rule on state versions | Expire noncurrent versions after a retention period |
