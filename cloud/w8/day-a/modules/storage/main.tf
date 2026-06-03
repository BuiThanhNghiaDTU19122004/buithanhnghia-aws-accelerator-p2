locals {
  documents_bucket_name   = trimspace(coalesce(var.documents_bucket_name, ""))
  documents_bucket_prefix = lower(replace("${var.project_name}-${var.environment}-documents-", "_", "-"))
  ehr_table_name          = trimspace(coalesce(var.ehr_table_name, "")) != "" ? trimspace(var.ehr_table_name) : "${var.project_name}-${var.environment}-ehr"
}

resource "aws_s3_bucket" "documents" {
  bucket        = local.documents_bucket_name != "" ? local.documents_bucket_name : null
  bucket_prefix = local.documents_bucket_name == "" ? local.documents_bucket_prefix : null

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "documents" {
  bucket      = aws_s3_bucket.documents.id
  eventbridge = true
}

resource "aws_dynamodb_table" "ehr" {
  name           = local.ehr_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = var.table_read_capacity
  write_capacity = var.table_write_capacity
  hash_key       = "PK"
  range_key      = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  global_secondary_index {
    name            = "SKIndex"
    projection_type = "ALL"
    read_capacity   = var.table_read_capacity
    write_capacity  = var.table_write_capacity

    key_schema {
      attribute_name = "SK"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "PK"
      key_type       = "RANGE"
    }
  }

  tags = var.tags
}
