
terraform {
  backend "s3" {
    bucket       = "terraform-cicd-state-035237531272-ap-south-1"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
