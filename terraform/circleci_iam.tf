# CircleCI IAM User and Policy for Deployment

resource "aws_iam_user" "circleci_deploy" {
  name = "circleci-deploy-${var.default_tag}"
  path = "/service-accounts/"

  tags = {
    Name        = "CircleCI Deploy User"
    Project     = var.default_tag
    ManagedBy   = "terraform"
    Purpose     = "CI/CD Deployment"
  }
}

resource "aws_iam_policy" "circleci_deploy_policy" {
  name        = "circleci-deploy-policy-${var.default_tag}"
  description = "Policy for CircleCI to deploy to EC2 and access required AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AutoScalingAccess"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Access"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = "arn:aws:rds:${var.region}:*:db/*"
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.example.arn
      },
      {
        Sid    = "SSMDocumentAccess"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "arn:aws:ssm:${var.region}::document/AWS-RunShellScript"
      },
      {
        Sid    = "SSMInstanceAccess"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "arn:aws:ec2:${var.region}:*:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/aws:autoscaling:groupName" = aws_autoscaling_group.ec2_autoscaling_group.name
          }
        }
      },
      {
        Sid    = "S3DeploymentBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.deployment_artifacts.arn,
          "${aws_s3_bucket.deployment_artifacts.arn}/*"
        ]
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.api.arn
      }
    ]
  })
}

resource "aws_iam_group" "circleci_deploy_group" {
  name = "circleci-deploy-group-${var.default_tag}"
  path = "/service-accounts/"
}

resource "aws_iam_group_policy_attachment" "circleci_deploy_attach" {
  group      = aws_iam_group.circleci_deploy_group.name
  policy_arn = aws_iam_policy.circleci_deploy_policy.arn
}

resource "aws_iam_user_group_membership" "circleci_deploy_membership" {
  user = aws_iam_user.circleci_deploy.name

  groups = [
    aws_iam_group.circleci_deploy_group.name
  ]
}

# Create access key (stored in state - see security considerations)
resource "aws_iam_access_key" "circleci_deploy_key" {
  user = aws_iam_user.circleci_deploy.name
}

# Store credentials in AWS Secrets Manager for better security
resource "aws_secretsmanager_secret" "circleci_credentials" {
  name        = "circleci-aws-credentials-${var.default_tag}"
  description = "AWS credentials for CircleCI deployment"
  kms_key_id  = aws_kms_key.default.arn

  tags = {
    Name      = "CircleCI AWS Credentials"
    Project   = var.default_tag
    ManagedBy = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "circleci_credentials" {
  secret_id = aws_secretsmanager_secret.circleci_credentials.id
  secret_string = jsonencode({
    aws_access_key_id     = aws_iam_access_key.circleci_deploy_key.id
    aws_secret_access_key = aws_iam_access_key.circleci_deploy_key.secret
  })
}