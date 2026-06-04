provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
}

module "s3" {
  source      = "./modules/s3"
  bucket_name = var.static_bucket_name
}

module "ec2" {
  source            = "./modules/ec2"
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_id
  allowed_http_cidr = "0.0.0.0/0"
}

module "rds" {
  source             = "./modules/rds"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = [module.vpc.private_subnet_id]
  ec2_security_group = module.ec2.ec2_security_group_id

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}
