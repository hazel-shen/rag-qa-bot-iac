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
