variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "bucket_name" {
  description = "S3 bucket name prefix"
  type        = string
  default     = "macie-sample-files"
}

variable "alert_email" {
  description = "Email address for receiving Macie alerts"
  type        = string
  sensitive   = true
}
