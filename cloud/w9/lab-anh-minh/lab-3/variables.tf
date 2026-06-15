variable "aws_region" {
  description = "AWS Region used for this lab."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix for resource names."
  type        = string
  default     = "anh-minh-lab-3"
}

variable "notification_email" {
  description = "Email address that will receive SNS alarm notifications. Replace the placeholder before applying."
  type        = string
  default     = "your-email@example.com"
}

variable "notification_phone_number" {
  description = "Optional SMS phone number in E.164 format, for example +84123456789. Leave empty to skip SMS."
  type        = string
  default     = ""
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to keep CloudTrail events in CloudWatch Logs."
  type        = number
  default     = 14
}

variable "metric_namespace" {
  description = "CloudWatch metric namespace for the root account login metric."
  type        = string
  default     = "Security"
}

variable "metric_name" {
  description = "CloudWatch metric name emitted by the root account login metric filter."
  type        = string
  default     = "RootAccountLoginCount"
}
