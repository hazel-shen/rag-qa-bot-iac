
########################################
# ElastiCache Redis - Free Tier
########################################
resource "aws_elasticache_subnet_group" "redis" {
  name = "demo-redis-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id, # ap-northeast-1a
    aws_subnet.private_c.id  # ap-northeast-1c (必須不同 AZ)
  ]
  tags = { Name = "demo-redis-subnet-group" }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "demo-redis"
  description          = "Demo Redis (Free Tier - no encryption)"

  engine             = "redis"
  engine_version     = "7.0"
  node_type          = "cache.t3.micro" # ✅ Free Tier eligible
  num_cache_clusters = 1                # 單節點
  port               = 6379

  # Free Tier: 無加密、無 AUTH
  transit_encryption_enabled = false
  at_rest_encryption_enabled = false

  # 網路
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis_sg.id]

  # 單 AZ
  automatic_failover_enabled = false
  multi_az_enabled           = false

  parameter_group_name = "default.redis7"
  maintenance_window   = "sun:20:00-sun:21:00"

  tags = {
    Name        = "demo-redis"
    Environment = "demo"
    CostCenter  = "free-tier"
  }
}


########################################
# Security Group for Redis
########################################
resource "aws_security_group" "redis_sg" {
  name_prefix = "demo-redis-sg-"
  vpc_id      = data.aws_vpc.default.id
  description = "Security group for ElastiCache Redis"

  ingress {
    description     = "Redis from EC2 app"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "demo-redis-sg"
    Environment = "demo"
    CostCenter  = "free-tier"
  }
}
