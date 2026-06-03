output "documents_bucket_name" {
  description = "Name of the S3 documents bucket."
  value       = aws_s3_bucket.documents.bucket
}

output "ehr_table_name" {
  description = "Name of the DynamoDB EHR table."
  value       = aws_dynamodb_table.ehr.name
}

output "ehr_table_arn" {
  description = "ARN of the DynamoDB EHR table."
  value       = aws_dynamodb_table.ehr.arn
}

output "sk_index_name" {
  description = "Name of the inverted SK index."
  value       = "SKIndex"
}
