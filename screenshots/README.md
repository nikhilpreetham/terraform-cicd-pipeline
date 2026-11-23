# Screenshots

This folder is for **genuine screenshots captured from this pipeline**. No screenshots have been added yet.

Before adding an image, blur or crop out AWS account IDs, ARNs, email addresses and repository variable values.

| # | Suggested file name | What it should show |
|---|---|---|
| 1 | `01-ci-pull-request-checks.png` | A pull request with the **Terraform CI** check passing |
| 2 | `02-ci-run-steps.png` | Terraform CI run: fmt, TFLint, init and validate steps all green |
| 3 | `03-cd-run-steps.png` | Terraform CD run with every step green |
| 4 | `04-cd-oidc-identity.png` | "Verify AWS identity" step showing the assumed role, with the account ID masked as `***` |
| 5 | `05-cd-plan-output.png` | "Terraform Plan" step output |
| 6 | `06-cd-variable-check-failure.png` | The run that stopped at "Check required repository variables" (see troubleshooting) |
| 7 | `07-s3-state-object.png` | S3 console: `dev/terraform.tfstate` in the state bucket (bucket name blurred) |
| 8 | `08-iam-oidc-provider.png` | IAM console: the `token.actions.githubusercontent.com` identity provider |
| 9 | `09-iam-role-trust-policy.png` | Trust policy of `github-actions-terraform-deploy` (IDs blurred) |
| 10 | `10-dev-bucket-settings.png` | Development bucket: versioning, encryption and public access block |

After adding images, link them from the README.
