variable "vpc_id" {}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ec2_security_group" {}

variable "db_name" {}

variable "db_username" {}

variable "db_password" {
  sensitive = true
}