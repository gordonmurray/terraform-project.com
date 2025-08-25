resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Security group for the EC2 instances"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow inbound HTTP traffic from the ALB."
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    description = "Allow outbound HTTP and HTTPS traffic."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-egress-sgr
  }

  egress {
    description = "Allow outbound HTTPS traffic to the internet for updates."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-egress-sgr
  }

  egress {
    description = "Allow outbound MySQL traffic to RDS."
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  tags = {
    Name = var.default_tag
  }
}
