variable "aws_region" {
  default = "ap-southeast-1"
}

variable "static_bucket_name" {
  type = string
}

variable "app_name" {
  default = "nghia-simple-webapp"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the EC2 instance. Replace the default with your public IP /32 before applying in a real account."
  default     = "0.0.0.0/0"
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

