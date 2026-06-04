locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket" "documents" {
  bucket = var.documents_bucket_name

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "documents" {
  bucket      = aws_s3_bucket.documents.id
  eventbridge = true
}

resource "aws_dynamodb_table" "ehr" {
  name           = var.ehr_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "PK"
  range_key = "SK"

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
    read_capacity   = 5
    write_capacity  = 5

    key_schema {
      attribute_name = "SK"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "PK"
      key_type       = "RANGE"
    }
  }

  tags = local.common_tags
}

resource "aws_sqs_queue" "annotation_dlq" {
  name = "${var.project_name}-${var.environment}-annotation-dlq"
  tags = local.common_tags
}

resource "aws_sqs_queue" "annotation" {
  name                       = "${var.project_name}-${var.environment}-annotation-queue"
  visibility_timeout_seconds = 180

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.annotation_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.project_name}-${var.environment}-documents-created"
  description = "Route S3 ObjectCreated documents/* events to SQS"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [aws_s3_bucket.documents.bucket] }
      object = { key = [{ prefix = "documents/" }] }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "annotation_queue" {
  rule = aws_cloudwatch_event_rule.s3_object_created.name
  arn  = aws_sqs_queue.annotation.arn
}

resource "aws_sqs_queue_policy" "annotation_events" {
  queue_url = aws_sqs_queue.annotation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.annotation.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.s3_object_created.arn
        }
      }
    }]
  })
}