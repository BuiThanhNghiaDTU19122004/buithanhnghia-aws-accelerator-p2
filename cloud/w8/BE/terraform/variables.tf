variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "stack_name" {
  type    = string
  default = "ehr_annotation_be"
}

variable "documents_bucket_name" {
  type = string
}

variable "ehr_table_name" {
  type    = string
  default = "ehr_annotation"
}

variable "groq_api_key" {
  type      = string
  sensitive = true
}

variable "notification_email" {
  type = string
}

variable "ddos_request_threshold" {
  type    = number
  default = 5000
}
