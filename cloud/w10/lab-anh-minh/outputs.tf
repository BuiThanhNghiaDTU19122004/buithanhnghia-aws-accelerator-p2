output "s3_bucket_name" {
  description = "Name of the S3 bucket for sample files"
  value       = aws_s3_bucket.sample_files.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.sample_files.arn
}

output "macie_job_id" {
  description = "ID of the Macie classification job"
  value       = aws_macie2_classification_job.s3_scan.id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.macie_alerts.arn
}

output "event_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.macie_findings.name
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS Region"
  value       = data.aws_region.current.region
}
