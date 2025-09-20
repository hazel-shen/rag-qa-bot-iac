
########################################
# RDS PostgreSQL (Free Tier，要注意 RDS 也會用到 EBS)
########################################
# ⚠️ 即使是 single instance，仍需要至少 2 個不同 AZ 的 subnets
# 這是 AWS RDS 的技術要求，不是為了高可用
resource "aws_db_subnet_group" "rds_subnets" {
  name = "demo-rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id, # ap-northeast-1a
    aws_subnet.private_c.id  # ap-northeast-1c (必須不同 AZ)
  ]                          # 放 private subnet

  tags = { Name = "demo-rds-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier     = "demo-rds"
  engine         = "postgres"
  engine_version = "15.8"

  # ✅ Free Tier 儲存設定
  instance_class        = "db.t3.micro"
  allocated_storage     = 20 # ✅ 20GB 免費 (RDS 額度)
  max_allocated_storage = 20
  storage_type          = "gp2" # RDS Free Tier 只支援 gp2

  db_name = "demo"

  # ⚡ 從 Secret Manager 取得認證資訊
  username = jsondecode(aws_secretsmanager_secret_version.rds.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.rds.secret_string)["password"]
  port     = jsondecode(aws_secretsmanager_secret_version.rds.secret_string)["port"]

  # 網路設定
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # ✅ Single Instance + Free Tier 設定
  multi_az            = false
  publicly_accessible = false

  # ✅ Free Tier 最佳化備份設定
  backup_retention_period = 1
  backup_window           = "03:00-04:00"

  # 效能設定
  performance_insights_enabled = false # Free tier 不支援
  monitoring_interval          = 0     # 基本監控免費

  # 開發環境設定（生產環境請調整）
  skip_final_snapshot      = true  # ⚠️ 生產環境建議設為 false
  delete_automated_backups = true  # ⚠️ 生產環境建議設為 false
  deletion_protection      = false # ⚠️ 生產環境建議設為 true

  depends_on = [
    aws_secretsmanager_secret_version.rds,
    aws_db_subnet_group.rds_subnets
  ]

  tags = {
    Name        = "demo-rds"
    Environment = "demo"
    CostCenter  = "free-tier"
  }
}

# rds security group
resource "aws_security_group" "rds_sg" {
  name_prefix = "demo-rds-sg-" # ✅ 避免命名衝突
  vpc_id      = data.aws_vpc.default.id
  description = "Security group for RDS PostgreSQL instance"

  ingress {
    description     = "Postgres from EC2 app SG"
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id] # 允許 EC2 → RDS
  }

  # ✅ 更嚴格的 egress 設定（可選）
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "demo-rds-sg"
    Environment = "demo"
  }

  lifecycle {
    create_before_destroy = true # ✅ 避免更新時的中斷
  }
}
