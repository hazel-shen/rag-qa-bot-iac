
############################
# GitHub OIDC Provider（若帳號已建立可略過此資源）
############################
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC 的固定 Thumbprint（如未來變動，需更新）
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

############################
# AssumeRole 信任政策（限制到你的 repo + 指定分支）
############################
locals {
  # 允許的 sub patterns，例如：
  # repo:owner/repo:ref:refs/heads/main
  oidc_sub_patterns = [
    for b in var.allowed_branches :
    "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${b}"
  ]
}

data "aws_iam_policy_document" "gha_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.oidc_sub_patterns
    }
  }
}

############################
# 部署 Role（給 GitHub Actions 用）
############################
resource "aws_iam_role" "gha_deploy" {
  name               = "gha-deploy-ssm"
  assume_role_policy = data.aws_iam_policy_document.gha_trust.json
  description        = "Role assumed by GitHub Actions via OIDC to deploy via SSM"
}

############################
# 權限政策：SSM 發佈 + DescribeInstances
############################
# 最小可用：先允許 *；跑通後你可以收斂至：
# - Resource: arn:aws:ssm:<region>:<acct>:document/AWS-RunShellScript
# - Resource: arn:aws:ec2:<region>:<acct>:instance/<id>（或對應的 managed-instance ARN）
# 並加上條件（如 ec2:ResourceTag/ssm:resourceTag），這裡為了簡潔先給通用型
data "aws_iam_policy_document" "gha_permissions" {
  statement {
    sid    = "SSMSendCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:ListCommands",
      "ssm:ListCommandInvocations",
      "ssm:GetCommandInvocation"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EC2Describe"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "gha_policy" {
  name        = "gha-deploy-ssm-policy"
  description = "Allow GitHub Actions to deploy via SSM and describe EC2 instances"
  policy      = data.aws_iam_policy_document.gha_permissions.json
}

resource "aws_iam_role_policy_attachment" "gha_attach" {
  role       = aws_iam_role.gha_deploy.name
  policy_arn = aws_iam_policy.gha_policy.arn
}

############################
# 輸出：給 GitHub workflow 使用
############################
output "deploy_role_arn" {
  value       = aws_iam_role.gha_deploy.arn
  description = "Put this into GitHub Actions Secret: AWS_ROLE_TO_ASSUME"
}
