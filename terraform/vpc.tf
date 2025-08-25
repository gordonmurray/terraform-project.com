resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = var.default_tag
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  vpc_id               = aws_vpc.vpc.id
  iam_role_arn         = aws_iam_role.flow_log_role.arn
}
