
resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.bucket_name_prefix}-${random_id.suffix.hex}"
  force_destroy = true # 允許刪桶時自動刪物件
}

# 公開存取封鎖
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side 加密 (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 僅允許 TLS 存取
data "aws_iam_policy_document" "ssl_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.ssl_only.json
}

# Lifecycle：清理 /tmp 與未完成上傳
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # 只清 tmp/，七天後刪除
  # rule {
  #   id     = "expire-tmp-7d"
  #   status = "Enabled"
  #   filter { prefix = "tmp/" }
  #   expiration { days = 7 }
  # }

  # 2) 中止未完成的分段上傳（避免產生碎片費用）
  rule {
    id     = "abort-multipart-uploads-7-days"
    status = "Enabled"

    filter {} # 全桶套用

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
