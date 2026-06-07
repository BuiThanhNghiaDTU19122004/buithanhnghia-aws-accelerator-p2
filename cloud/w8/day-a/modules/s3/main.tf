resource "aws_s3_bucket" "static" {
  bucket = var.bucket_name

  tags = {
    Name = "static-assets"
  }
}

resource "aws_s3_bucket_ownership_controls" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_policy" "static_public_read" {
  bucket = aws_s3_bucket.static.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadStaticWebsite"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.static]
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.static.id
  key          = "index.html"
  content_type = "text/html"
  content = templatefile("${path.module}/site/index.html.tftpl", {
    api_base_url = var.api_base_url
  })

  depends_on = [aws_s3_bucket_ownership_controls.static]
}

resource "aws_s3_object" "app_js" {
  bucket       = aws_s3_bucket.static.id
  key          = "app.js"
  content_type = "application/javascript"
  content = templatefile("${path.module}/site/app.js.tftpl", {
    api_base_url = var.api_base_url
  })

  depends_on = [aws_s3_bucket_ownership_controls.static]
}
