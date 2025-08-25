resource "aws_secretsmanager_secret" "example" {
  kms_key_id              = aws_kms_key.default.key_id
  name                    = "rds_admin_password"
  description             = "RDS Admin password"
  recovery_window_in_days = 7

  tags = {
    Name = var.default_tag
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "secret" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = jsonencode({
    username = "Admin",
    password = random_password.password.result,
    host     = aws_db_instance.default.address,
    port     = aws_db_instance.default.port,
    dbname   = "demo"
  })
}
