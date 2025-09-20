# 1) 隨機密碼生成器
resource "random_password" "rds_password" {
  length  = 16
  special = true
  keepers = {
    rds_instance = "demo" # 只要這個不變，密碼不會重生
  }
}

# 2) Secrets Manager Secret
resource "aws_secretsmanager_secret" "rds" {
  name = "demo/rds"
  tags = { Name = "demo-rds-secret" }
}

# 3) Secrets Manager Secret Version (JSON 格式)
resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = "demo_user"
    password = random_password.rds_password.result
    port     = 5432
    dbname   = "demo"
  })
}
