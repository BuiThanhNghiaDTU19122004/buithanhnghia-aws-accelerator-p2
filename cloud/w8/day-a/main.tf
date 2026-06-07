provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
}

module "security_groups" {
  source            = "./modules/security_groups"
  allowed_http_cidr = "0.0.0.0/0"
  allowed_ssh_cidr  = var.allowed_ssh_cidr
  vpc_id            = module.vpc.vpc_id
}

module "rds" {
  source             = "./modules/rds"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_security_group = module.security_groups.rds_sg_id

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

module "web" {
  source                = "./modules/web"
  public_subnet_id      = module.vpc.public_subnet_id
  web_security_group_id = module.security_groups.web_sg_id

  app_name    = var.app_name
  db_host     = module.rds.db_address
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

module "s3" {
  source       = "./modules/s3"
  bucket_name  = var.static_bucket_name
  api_base_url = module.web.public_url
}
