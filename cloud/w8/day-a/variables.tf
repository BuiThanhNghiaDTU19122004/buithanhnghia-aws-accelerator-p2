variable "aws_region" {
  default = "ap-southeast-1"
}

variable "static_bucket_name" {
  type = string
}

variable "db_name" {
  default = "appdb"
}

variable "db_username" {
  default = "nghia"
}

variable "db_password" {
  sensitive = true
}

