# S3 bucket for CircleCI deployment artifacts

resource "aws_s3_bucket" "deployment_artifacts" {
  bucket = "circleci-deployments-${random_id.bucket_suffix.hex}"

  tags = {
    Name      = "Deployment Artifacts Bucket"
    Project   = var.default_tag
    ManagedBy = "terraform"
    Purpose   = "CircleCI deployment artifacts"
  }
}

resource "aws_s3_bucket_logging" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_public_access_block" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.default.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  rule {
    id     = "delete_old_deployments"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}