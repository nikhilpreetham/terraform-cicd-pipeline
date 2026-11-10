# Automated Terraform CI/CD Pipeline

A hands-on DevOps project demonstrating automated Terraform
validation and deployment using GitHub Actions and AWS.

## Technologies

* Terraform
* AWS
* GitHub Actions
* AWS IAM
* AWS OIDC
* Amazon S3

## Project Objectives

* Automate Terraform validation through CI.
* Automate infrastructure deployment through CD.
* Authenticate GitHub Actions with AWS using OIDC.
* Store Terraform state remotely in Amazon S3.
* Implement native S3 state locking.
* Apply least-privilege IAM permissions.

## Project Status

In development.
## CI/CD Workflow



This project uses GitHub Actions to automate Terraform validation and deployment.



\### Continuous Integration (CI)

\- Runs on pull requests targeting `main`.

\- Checks Terraform formatting.

\- Initializes Terraform configurations.

\- Validates bootstrap and development configurations.



\### Continuous Deployment (CD)

\- Runs after changes are pushed to `main`.

\- Authenticates to AWS using GitHub OIDC.

\- Uses Terraform remote state stored in S3.

\- Executes Terraform plan and apply.

