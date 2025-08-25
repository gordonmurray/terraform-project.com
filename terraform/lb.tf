
resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Security group for the ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow inbound HTTPS traffic from the internet."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  }

  egress {
    description = "Allow outbound traffic to EC2 instances."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:aws-ec2-no-public-egress-sgr
  }

  tags = {
    Name = var.default_tag
  }
}

resource "aws_lb" "main" { # tfsec:ignore:aws-elb-alb-not-public
  name                       = "main-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb_sg.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true

  tags = {
    Name = "main-lb"
  }
}

resource "aws_lb_target_group" "main" {
  name     = "main-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "main-tg"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.ec2_autoscaling_group.name
  lb_target_group_arn    = aws_lb_target_group.main.arn
}
