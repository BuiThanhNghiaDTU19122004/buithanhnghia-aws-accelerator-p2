variable "project_name" {
  type        = string
  description = "Short project name used in storage resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "documents_bucket_name" {
  type        = string
  description = "Optional globally unique S3 bucket name."
  default     = null
}

variable "ehr_table_name" {
  type        = string
  description = "Optional DynamoDB table name."
  default     = null
}

variable "table_read_capacity" {
  type        = number
  description = "Provisioned read capacity units for the table and SKIndex."
}

variable "table_write_capacity" {
  type        = number
  description = "Provisioned write capacity units for the table and SKIndex."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to storage resources."
  default     = {}
}
