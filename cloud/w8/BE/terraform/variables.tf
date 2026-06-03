variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "floci_endpoint" {
  type    = string
  default = "http://localhost:4566"
}

variable "project_name" {
  type    = string
  default = "ehr-annotation"
}

variable "environment" {
  type    = string
  default = "local"
}

variable "documents_bucket_name" {
  type    = string
  default = "ehr-annotation-local-documents"
}

variable "ehr_table_name" {
  type    = string
  default = "ehr-annotation-local-table"
}