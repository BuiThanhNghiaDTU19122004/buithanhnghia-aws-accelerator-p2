output "documents_bucket_name" {
  value = aws_s3_bucket.documents.bucket
}

output "ehr_table_name" {
  value = aws_dynamodb_table.ehr.name
}

output "ehr_table_arn" {
  value = aws_dynamodb_table.ehr.arn
}

output "sk_index_name" {
  value = "SKIndex"
}