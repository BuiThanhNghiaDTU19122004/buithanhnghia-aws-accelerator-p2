variable "aws_region" {
  description = "AWS Region used for this lab."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix for resource names."
  type        = string
  default     = "anh-minh-lab-1"
}

variable "notification_email" {
  description = "Email address that will receive SNS alarm notifications. Replace the placeholder before applying."
  type        = string
  default     = "your-email@example.com"
}

variable "instance_type" {
  description = "Free-tier friendly EC2 instance type. Change only if your Region/account uses another free-tier micro type."
  type        = string
  default     = "t2.micro"
}

variable "alarm_threshold" {
  description = "CPUUtilization percentage that triggers the alarm."
  type        = number
  default     = 80
}

variable "enable_cpu_test" {
  description = "When true, user_data starts a short CPU loop to help trigger the alarm for demonstration."
  type        = bool
  default     = false
}
