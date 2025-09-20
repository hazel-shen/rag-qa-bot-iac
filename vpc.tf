# 沿用 Default VPC
data "aws_vpc" "default" {
  default = true
}

# 公有子網（放 EC2；無公網 IP，但可經 IGW 出網）
resource "aws_subnet" "public_a" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.100.0/24" # <-- 確認不與現有衝突
  availability_zone       = var.az
  map_public_ip_on_launch = false
  tags                    = { Name = "public-a" }
}

# 私有子網（放 RDS / Redis）
resource "aws_subnet" "private_a" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.101.0/24" # <-- 確認不與現有衝突
  availability_zone       = var.az
  map_public_ip_on_launch = false
  tags                    = { Name = "private-a" }
}

# private subnet c，因應 rds 要求，不會產生額外費用
resource "aws_subnet" "private_c" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.102.0/24" # <-- 確認不與現有衝突
  availability_zone       = var.az_secondary  # 需要不同的 AZ
  map_public_ip_on_launch = false
  tags = {
    Name    = "private-c"
    Purpose = "RDS-subnet-group-requirement"
  }
}

data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

# 4) 公有路由表改指向現有 IGW
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing.id
  }
  tags = { Name = "rtb-public" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# 私有路由表（不走 IGW/NAT）
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id
  tags   = { Name = "rtb-private" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}
