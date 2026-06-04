terraform {
  backend "s3" {
    bucket         = "nghia-tfstate-bucket-201023212626"
    key            = "project/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}