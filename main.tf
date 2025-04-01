# Configure AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create S3 bucket for the data lake
resource "aws_s3_bucket" "data_lake" {
  bucket = "XXXXXXXXXXXXXXXXXXXXXXXXXX"  # Change this to a unique name
  
  tags = {
    Name        = "Data Lake Storage"
    Environment = "Production"
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "data_lake_access" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake_encryption" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create Lake Formation Admin
resource "aws_lakeformation_data_lake_settings" "data_lake_settings" {
  admins = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lake_formation_admin"]
}

# Create IAM role for Lake Formation
resource "aws_iam_role" "lake_formation_role" {
  name = "lake_formation_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lakeformation.amazonaws.com"
        }
      }
    ]
  })
}

# Create custom policy for Lake Formation
resource "aws_iam_policy" "lake_formation_policy" {
  name = "lake_formation_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      }
    ]
  })
}

# Attach policies to Lake Formation role
resource "aws_iam_role_policy_attachment" "lake_formation_policy_attach" {
  role       = aws_iam_role.lake_formation_role.name
  policy_arn = aws_iam_policy.lake_formation_policy.arn
}

# Register S3 bucket with Lake Formation
resource "aws_lakeformation_resource" "data_lake_location" {
  arn      = aws_s3_bucket.data_lake.arn
  role_arn = aws_iam_role.lake_formation_role.arn
}

# Create Glue Catalog Database
resource "aws_glue_catalog_database" "data_lake_catalog" {
  name = "data_lake_catalog"
}

# Create Glue Crawler Role
resource "aws_iam_role" "glue_crawler_role" {
  name = "glue_crawler_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWSGlueServiceRole policy
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
