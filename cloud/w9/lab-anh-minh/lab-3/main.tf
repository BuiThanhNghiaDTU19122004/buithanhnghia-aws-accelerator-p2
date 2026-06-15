data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Lab       = "root-account-login-alert"
  }

  cloudtrail_name        = "${var.project_name}-trail"
  cloudtrail_bucket_name = substr(lower(replace("${var.project_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-cloudtrail", "/[^a-z0-9-]/", "-")), 0, 63)
  cloudtrail_arn         = "arn:${data.aws_partition.current.partition}:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.cloudtrail_name}"
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_bucket_name

  force_destroy = true

  tags = merge(local.common_tags, {
    Name = local.cloudtrail_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.cloudtrail_arn
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.cloudtrail_arn
            "s3:x-amz-acl"  = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}/root-login"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:log-stream:${data.aws_caller_identity.current.account_id}_CloudTrail_${var.aws_region}*"
      }
    ]
  })
}

resource "aws_cloudtrail" "root_login" {
  name                          = local.cloudtrail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy.cloudtrail_cloudwatch,
    aws_s3_bucket_policy.cloudtrail
  ]
}

resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "${var.project_name}-root-login-filter"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.userIdentity.type = \"Root\") && ($.eventType != \"AwsServiceEvent\") }"

  metric_transformation {
    name          = var.metric_name
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_sns_topic" "root_login_alert" {
  name = "${var.project_name}-root-login-alert-topic"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.root_login_alert.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "sms" {
  count = trimspace(var.notification_phone_number) == "" ? 0 : 1

  topic_arn = aws_sns_topic.root_login_alert.arn
  protocol  = "sms"
  endpoint  = var.notification_phone_number
}

resource "aws_cloudwatch_metric_alarm" "root_login" {
  alarm_name          = "${var.project_name}-root-account-login"
  alarm_description   = "Alert when the AWS root account is used for any non-service event."
  namespace           = var.metric_namespace
  metric_name         = var.metric_name
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.root_login_alert.arn]
  ok_actions    = [aws_sns_topic.root_login_alert.arn]

  tags = local.common_tags

  depends_on = [aws_cloudwatch_log_metric_filter.root_login]
}
