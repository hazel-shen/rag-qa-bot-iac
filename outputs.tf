
output "ec2_instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "ec2_private_ip" {
  description = "The private IP of the EC2 instance"
  value       = aws_instance.app.private_ip
}

output "ec2_subnet_id" {
  description = "The Subnet ID where the EC2 instance is launched"
  value       = aws_subnet.public_a.id
}

output "ec2_ssm_target" {
  description = "SSM target string for AWS Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.app.id}"
}

# 輸出 RDS 連接資訊（方便應用程式使用）
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
  sensitive   = true
}

output "rds_db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
  sensitive   = true
}


# Redis
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}
