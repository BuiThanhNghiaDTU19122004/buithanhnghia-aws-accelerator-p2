output "ec2_web_url" {
  value = module.web.public_url
}

output "s3_website_url" {
  value = module.s3.website_url
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "state_backend_bucket" {
  value = "nghia-tfstate-bucket-201023212626"
}

output "state_lock_table" {
  value = "terraform-locks"
}
