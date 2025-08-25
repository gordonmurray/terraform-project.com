output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.default.address
}

output "ec2_instance_ids" {
  description = "Current EC2 instance IDs in the ASG"
  value       = data.aws_instances.asg_instances.ids
}

output "deployment_s3_bucket" {
  description = "S3 bucket name for deployment artifacts"
  value       = aws_s3_bucket.deployment_artifacts.id
}

data "aws_instances" "asg_instances" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.ec2_autoscaling_group.name]
  }

  instance_state_names = ["running"]
}

output "ecr_repo_url" {
  value = aws_ecr_repository.api.repository_url
}
