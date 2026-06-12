variable "aws_region" {
  description = "AWS Region used for this lab."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix for resource names."
  type        = string
  default     = "anh-minh-lab-2"
}

variable "notification_email" {
  description = "Optional email address for the instance status alarm. Replace the placeholder before applying."
  type        = string
  default     = "your-email@example.com"
}

variable "instance_type" {
  description = "Free-tier friendly EC2 instance type. Change only if your Region/account uses another free-tier micro type."
  type        = string
  default     = "t2.micro"
}

variable "cloudwatch_agent_metrics_interval" {
  description = "Metric collection interval in seconds. Keep 60 or higher to avoid high-resolution custom metric charges."
  type        = number
  default     = 60

  validation {
    condition     = var.cloudwatch_agent_metrics_interval >= 60
    error_message = "Keep cloudwatch_agent_metrics_interval at 60 seconds or higher to avoid high-resolution custom metrics."
  }
}
