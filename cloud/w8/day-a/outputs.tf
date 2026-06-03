output "documents_bucket_name" {
  description = "S3 bucket that stores source clinical documents."
  value       = module.storage.documents_bucket_name
}

output "ehr_table_name" {
  description = "DynamoDB single-table name used by the backend."
  value       = module.storage.ehr_table_name
}

output "ehr_table_arn" {
  description = "DynamoDB table ARN for later Lambda IAM policies."
  value       = module.storage.ehr_table_arn
}

output "sk_index_name" {
  description = "DynamoDB GSI used to find annotations by SK."
  value       = module.storage.sk_index_name
}
