terraform {
  # The state bucket name is passed in at init time so the AWS account ID is not committed.
  #   GitHub Actions: -backend-config="bucket=$TF_STATE_BUCKET" (repository variable)
  #   Local:          terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
