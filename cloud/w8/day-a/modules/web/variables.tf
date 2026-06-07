variable "ami_id" {
  default = "ami-047126e50991d067b"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "public_subnet_id" {}

variable "web_security_group_id" {}

variable "app_name" {}

variable "db_host" {}

variable "db_name" {}

variable "db_username" {}

variable "db_password" {
  sensitive = true
}
