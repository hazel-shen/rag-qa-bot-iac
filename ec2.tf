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

# s3 Get objects policy
data "aws_iam_policy_document" "s3_get_prefix" {

  # 不加沒辦法複製
  statement {
    sid       = "ListOnlyThatPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.this.id}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "${var.iam_s3_policy_prefix}", # e.g. "tmp/"
        "${var.iam_s3_policy_prefix}*" # e.g. "tmp/*"
      ]
    }
  }


  statement {
    sid    = "AllowGetObjectOnlyForPrefix"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.this.id}/${var.iam_s3_policy_prefix}*"
    ]
  }
}

resource "aws_iam_policy" "s3_get_prefix" {
  name        = "ec2-s3-get-prefix"
  description = "Allow EC2 to GetObject from ${aws_s3_bucket.this.id}/${var.iam_s3_policy_prefix}"
  policy      = data.aws_iam_policy_document.s3_get_prefix.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_get_prefix.arn
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
  instance_type = var.ec2_instance_type
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


############################
# GitHub CI/CD
############################
# 給 EC2 Instance Role 讀該 Secret 的權限
resource "aws_iam_policy" "ec2_read_ghcr_secret" {
  name = "ec2-read-ghcr-secret"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource : [
          "${aws_secretsmanager_secret.ghcr.arn}",
          "${aws_secretsmanager_secret.app.arn}"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ec2_read_ghcr_secret_attach" {
  role       = aws_iam_role.ec2_role.name # 你的 EC2 角色名稱
  policy_arn = aws_iam_policy.ec2_read_ghcr_secret.arn
}
