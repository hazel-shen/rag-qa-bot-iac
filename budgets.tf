############################
# variables
############################
variable "daily_budget_usd" {
  description = "每日預算上限（USD）"
  type        = number
  default     = 10.00
}

variable "budget_emails" {
  description = "要接收告警的 Email 清單"
  type        = list(string)
  default     = ["mail@hazel.style"]
}

############################
# AWS Budgets - Daily Cost
############################
resource "aws_budgets_budget" "daily_cost" {
  provider     = aws.budgets
  name         = "daily-cost-email-notification"
  budget_type  = "COST"
  time_unit    = "DAILY"
  limit_amount = format("%.2f", var.daily_budget_usd)
  limit_unit   = "USD"

  # （選用）只監控特定服務/標籤
  # cost_filters = {
  #   Service      = ["Amazon Elastic Compute Cloud - Compute"] # 只看 EC2
  #   TagKeyValue  = ["CostCenter$free-tier"]                   # 例如 CostCenter=free-tier
  # }

  # 50% ACTUAL
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_emails
  }

  # 80% ACTUAL
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_emails
  }

  # 100% ACTUAL
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_emails
  }
}
