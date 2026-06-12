output "instance_id" {
  description = "EC2 instance monitored by the CPU alarm."
  value       = aws_instance.monitored.id
}

output "sns_topic_arn" {
  description = "SNS topic used by the CloudWatch alarm."
  value       = aws_sns_topic.cpu_alarm.arn
}

output "subscription_status" {
  description = "Email subscriptions remain PendingConfirmation until the inbox owner confirms the AWS email."
  value       = "Check ${var.notification_email} and confirm the SNS subscription email."
}

output "alarm_name" {
  description = "CloudWatch alarm name."
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "manual_cpu_test_command" {
  description = "Optional command to run inside the instance through SSM Session Manager."
  value       = "sudo /home/ec2-user/cpu-burn.sh 8m"
}
