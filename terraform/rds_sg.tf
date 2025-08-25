
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for the RDS instance"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow inbound traffic from the EC2 instances."
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  tags = {
    Name = var.default_tag
  }
}
