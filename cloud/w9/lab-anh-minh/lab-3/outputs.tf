output "cloudtrail_name" {
  description = "CloudTrail trail that records management events."
  value       = aws_cloudtrail.root_login.name
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket where CloudTrail also stores event history."
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logs group receiving CloudTrail events."
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "metric_filter_name" {
  description = "CloudWatch Logs metric filter that counts root account login events."
  value       = aws_cloudwatch_log_metric_filter.root_login.name
}

output "alarm_name" {
  description = "CloudWatch alarm name."
  value       = aws_cloudwatch_metric_alarm.root_login.alarm_name
}

output "alarm_url" {
  description = "Direct AWS Console URL for the root account login alarm."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:alarm/${aws_cloudwatch_metric_alarm.root_login.alarm_name}"
}

output "sns_topic_arn" {
  description = "SNS topic used by the root account login alarm."
  value       = aws_sns_topic.root_login_alert.arn
}

output "subscription_status" {
  description = "Email subscriptions remain PendingConfirmation until the inbox owner confirms the AWS email."
  value       = "Check ${var.notification_email} and confirm the SNS subscription email."
}
