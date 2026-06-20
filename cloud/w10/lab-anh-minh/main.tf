terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Lab         = "Macie-S3-Detection"
      Owner       = "nghia"
    }
  }
}

# ===== S3 BUCKET FOR SAMPLE FILES =====
resource "aws_s3_bucket" "sample_files" {
  bucket = "${var.bucket_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "sample_files" {
  bucket = aws_s3_bucket.sample_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sample_files" {
  bucket = aws_s3_bucket.sample_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "sample_files" {
  bucket = aws_s3_bucket.sample_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===== MACIE SETUP =====
resource "aws_macie2_account" "main" {
  status = "ENABLED"

  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Create Macie Classification Job
resource "aws_macie2_classification_job" "s3_scan" {
  depends_on = [aws_macie2_account.main]

  job_type    = "ONE_TIME"
  name_prefix = "${var.environment}-s3-classification-job-"
  description = "Scan S3 bucket for sensitive data"

  sampling_percentage = 100


  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.sample_files.id]
    }
  }
}

# ===== SNS TOPIC FOR ALERTS =====
resource "aws_sns_topic" "macie_alerts" {
  name = "${var.environment}-macie-alerts"

  tags = {
    Name = "${var.environment}-macie-alerts"
  }
}

resource "aws_sns_topic_policy" "macie_alerts" {
  arn = aws_sns_topic.macie_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.macie_alerts.arn
        # HARDENING: Chi cho phep rule EventBridge cu the nay duoc publish,
        # tuan thu nguyen tac least-privilege (Security Pillar).
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.macie_findings.arn
          }
        }
      }
    ]
  })
}

# Subscribe email to SNS topic (manual confirmation required)
resource "aws_sns_topic_subscription" "macie_alerts_email" {
  topic_arn = aws_sns_topic.macie_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ===== EVENT BRIDGE RULE =====
resource "aws_cloudwatch_event_rule" "macie_findings" {
  name        = "${var.environment}-macie-findings-rule"
  description = "Capture Macie findings and send to SNS"

  # FIX: Schema thuc te cua event "Macie Finding" la:
  #   detail.severity = { "score": 1-3, "description": "Low"|"Medium"|"High" }
  # Macie KHONG co muc "CRITICAL". Cu phap { value = "HIGH" } cung khong
  # ton tai trong EventBridge content-filtering - phai dua thang gia tri
  # vao array de match chinh xac.
  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
    detail = {
      severity = {
        description = ["Medium", "High"]
      }
    }
  })

  tags = {
    Name = "${var.environment}-macie-findings-rule"
  }
}

resource "aws_cloudwatch_event_target" "macie_to_sns" {
  rule      = aws_cloudwatch_event_rule.macie_findings.name
  target_id = "MacieToSNS"
  arn       = aws_sns_topic.macie_alerts.arn

  input_transformer {
    input_paths = {
      # FIX: phai lay .description de ra chuoi "High"/"Medium", neu khong
      # se chen nguyen object JSON {score, description} vao template.
      severity = "$.detail.severity.description"
      title    = "$.detail.title"
      resource = "$.detail.resourcesAffected.s3Object.key"
      bucket   = "$.detail.resourcesAffected.s3Bucket.name"
    }
    input_template = jsonencode({
      "severity"    = "<severity>"
      "title"       = "<title>"
      "bucket"      = "<bucket>"
      "resource"    = "<resource>"
      "account_id"  = data.aws_caller_identity.current.account_id
      "region"      = var.aws_region
      "timestamp"   = "$.detail.createdAt"
      "description" = "Sensitive data detected in S3"
    })
  }
}

# ===== DATA SOURCES =====
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
