locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_name    = var.app_name
    db_host     = var.db_host
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
  })
}

resource "aws_instance" "web" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.web_security_group_id]
  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = {
    Name = "web-server"
  }
}
