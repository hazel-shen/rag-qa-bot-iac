variable "vpc_id" {
  description = "The ID of the VPC"
  default     = "vpc-0184f19f84537a027"
  type        = string
}

# Only ap-northeast-1a, ap-northeast-1c, ap-northeast-1d
variable "az" {
  type    = string
  default = "ap-northeast-1a" # Tokyo
}

variable "az_secondary" {
  type    = string
  default = "ap-northeast-1c" # Tokyo
}

# 全球服務，us-east-1
variable "global_region" {
  description = "Region in AWS"
  default     = "us-east-1"
  type        = string
}

variable "region" {
  description = "Region in AWS"
  default     = "ap-northeast-1"
  type        = string
}

variable "profile" {
  description = "AWS SSO Profile"
  default     = "demo"
  type        = string
}

# RDS postgres settings

variable "rds_port" {
  description = "RDS port"
  default     = 5432
  type        = number
}


############################
# GitHub CI/CD
############################
# 你的 GitHub 倉庫（org/user 與 repo 名）
variable "github_owner" {
  description = "GitHub org or user"
  default     = "hazel-shen"
  type        = string
}
variable "github_repo" {
  description = "GitHub repository name"
  default     = "rag-qa-bot"
  type        = string
}

# 允許能 AssumeRole 的分支（預設只允許 main）
variable "allowed_branches" {
  description = "Branches allowed to assume the deploy role"
  type        = list(string)
  default     = ["main"]
}

# （可選）限制能被下指令的 EC2 實例 IDs（不填就用 *，先跑通再收斂）
variable "target_instance_ids" {
  description = "EC2 instance IDs allowed for SSM SendCommand. Empty -> allow all (simplest for first run)."
  type        = list(string)
  default = [
    "i-0be210d262d4eeb47"
  ]
}

############################
# GitHub CI/CD
############################

variable "ghcr_secret_name" {
  default = "demo/ghcr"
}

variable "ghcr_pat_value" {
  type      = string
  sensitive = true
  default   = null
}

############################
# RAG-FAQ-BOT App Secret
############################

variable "rag_faq_bot_app_secret_name" {
  default = "demo/app"
}

variable "rag_faq_bot_app_secret_value" {
  type      = string
  sensitive = true
  default   = null
}

############################
# s3 bucket
############################
variable "bucket_name_prefix" {
  default = "rag-faq-bot"
}

############################
# EC2
############################
variable "ec2_instance_type" {
  default = "t4g.medium" # 不用 medium 跑不起來
}

variable "iam_s3_policy_prefix" {
  default = "tmp"
}
