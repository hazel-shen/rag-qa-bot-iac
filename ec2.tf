# Amazon Linux 2023 ARM64
data "aws_ami" "al2023_arm" {
  owners      = ["137112412989"] # Amazon 官方
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"] # 這邊條件要設定好找 standard image，不然不會內建 ssm-agent
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

#####################################
# IAM Role for EC2 + SSM
########################################
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "demo-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "demo-ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

########################################
# Security Group（Inbound 0 條，Egress 全開）
########################################
resource "aws_security_group" "ec2_sg" {
  name        = "demo-ec2-sg"
  description = "No inbound; egress only"
  vpc_id      = var.vpc_id

  # 出站全開，允許拉 ghcr.io、cloudflared、更新套件
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "demo-ec2-sg" }
}

########################################
# EC2 Instance
########################################
resource "aws_instance" "app" {
  ami           = data.aws_ami.al2023_arm.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.public_a.id

  # 有公網 IP，才能出網拉 GHCR / Cloudflare Tunnel
  associate_public_ip_address = true

  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  root_block_device {
    volume_size = 15 # Free Tier 內，先設定低一點，之後有需要可以往上調整。
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    CONDA_DIR = "/opt/miniforge3"
  })


  tags = {
    Name        = "demo-ec2-app"
    Environment = "demo"
    CostCenter  = "free-tier"
  }
  lifecycle {
    ignore_changes = [
      user_data # 因為後來有改寫法，所以我先忽略改變
    ]
  }
}
