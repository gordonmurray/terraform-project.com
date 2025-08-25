resource "random_password" "password" {
  length  = 20
  special = true
  # excludes space, /, @, ", and also :, ?, #, &, +, ; to be URL-friendly even unencoded
  override_special = "!$%'()*,-._=~"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}


resource "aws_db_instance" "default" {
  identifier                   = "my-database"
  allocated_storage            = 20
  storage_type                 = "gp3"
  engine                       = "mariadb"
  engine_version               = "11.4.5"
  instance_class               = var.rds_instance_type
  username                     = "Admin"
  password                     = random_password.password.result
  parameter_group_name         = aws_db_parameter_group.default.name
  skip_final_snapshot          = true
  publicly_accessible          = false
  multi_az                     = true
  storage_encrypted            = true
  backup_retention_period      = 7
  db_subnet_group_name         = aws_db_subnet_group.default.name
  deletion_protection          = true
  performance_insights_enabled = false # Performance Insights is not supported on small instances.
  #performance_insights_kms_key_id = aws_kms_key.default.arn
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = var.default_tag
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "my-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = var.default_tag
  }
}

resource "aws_db_parameter_group" "default" {
  name   = "my-db-parameter-group"
  family = "mariadb11.4"

  parameter {
    name  = "max_connections"
    value = "{DBInstanceClassMemory/12582880}" # AWS use this formula to calculate max connections
  }

  parameter {
    name  = "binlog_format"
    value = "ROW" # Recommended for replication and point-in-time recovery
  }

  tags = {
    Name = var.default_tag
  }
}