variable "ecr_repo_name" {
  type    = string
  default = "terraform-project-api"
}

resource "aws_ecr_repository" "api" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.default.arn
  }
}

# Keep last 10 untagged images; purge older
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy     = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images beyond 10"
      selection    = {
        tagStatus     = "untagged"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = { type = "expire" }
    }]
  })
}