output "dev_bucket_name" {
  description = "Name of the development S3 bucket"
  value       = aws_s3_bucket.dev.bucket
}

output "dev_bucket_arn" {
  description = "ARN of the development S3 bucket"
  value       = aws_s3_bucket.dev.arn
}

output "aws_region" {
  description = "AWS region of the development environment"
  value       = var.aws_region
}
