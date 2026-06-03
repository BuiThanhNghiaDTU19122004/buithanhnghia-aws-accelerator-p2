
module "storage" {
  source = "./modules/storage"

  project_name          = var.project_name
  environment           = var.environment
  documents_bucket_name = var.documents_bucket_name
  ehr_table_name        = var.ehr_table_name
  table_read_capacity   = var.table_read_capacity
  table_write_capacity  = var.table_write_capacity

  tags = {
    Component = "storage"
  }
}
