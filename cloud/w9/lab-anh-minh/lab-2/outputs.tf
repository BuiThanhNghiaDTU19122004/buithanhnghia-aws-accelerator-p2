output "instance_id" {
  description = "EC2 instance running the CloudWatch Agent."
  value       = aws_instance.monitored.id
}

output "dashboard_name" {
  description = "CloudWatch dashboard created for EC2 monitoring."
  value       = aws_cloudwatch_dashboard.ec2_monitoring.dashboard_name
}

output "dashboard_url" {
  description = "Direct AWS Console URL for the dashboard."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.ec2_monitoring.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS topic used by the optional EC2 status alarm."
  value       = aws_sns_topic.status_alarm.arn
}

output "subscription_status" {
  description = "Email subscriptions remain PendingConfirmation until the inbox owner confirms the AWS email."
  value       = "Check ${var.notification_email} and confirm the SNS subscription email."
}

output "agent_status_command" {
  description = "Command to run inside the instance through SSM Session Manager."
  value       = "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status"
}
