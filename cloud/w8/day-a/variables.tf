variable "aws_region" {
  type        = string
  description = "AWS region used for the learning deployment."
  default     = "ap-southeast-1"
}

variable "project_name" {
  type        = string
  description = "Short project name used in resource names and tags."
  default     = "ehr-annotation"
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
  default     = "dev"
}

variable "documents_bucket_name" {
  type        = string
  description = "Optional globally unique S3 bucket name for clinical documents. Leave null to let Terraform generate one from a prefix."
  default     = null
}

variable "ehr_table_name" {
  type        = string
  description = "Optional DynamoDB table name. Leave null to use project/environment naming."
  default     = null
}

variable "table_read_capacity" {
  type        = number
  description = "Provisioned DynamoDB read capacity units for the table and SKIndex."
  default     = 5
}

variable "table_write_capacity" {
  type        = number
  description = "Provisioned DynamoDB write capacity units for the table and SKIndex."
  default     = 5
}

variable "default_tags" {
  type        = map(string)
  description = "Additional tags added to all supported AWS resources."
  default     = {}
}
