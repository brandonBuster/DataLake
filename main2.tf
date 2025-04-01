# Configure AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create IAM Role for Lake Formation
resource "aws_iam_role" "lakeformation_role" {
  name = "lakeformation_service_role"

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

# Create S3 bucket for data lake
resource "aws_s3_bucket" "data_lake_bucket" {
  bucket = "my-data-lake-bucket-${random_string.suffix.result}"
  force_destroy = true
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake_encryption" {
  bucket = aws_s3_bucket.data_lake_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Random string for unique bucket naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Register the S3 bucket as a Lake Formation data lake location
resource "aws_lakeformation_resource" "data_lake_resource" {
  arn = aws_s3_bucket.data_lake_bucket.arn
}

# Create AWS Glue Database
resource "aws_glue_catalog_database" "data_lake_catalog" {
  name = "data_lake_catalog"
}

# Create IAM policy for Lake Formation administrator
resource "aws_iam_policy" "lakeformation_admin_policy" {
  name = "lakeformation_admin_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lakeformation:*",
          "glue:*",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create Lake Formation admin IAM user
resource "aws_iam_user" "lakeformation_admin" {
  name = "lakeformation_admin"
}

# Attach Lake Formation admin policy to user
resource "aws_iam_user_policy_attachment" "lakeformation_admin_attach" {
  user       = aws_iam_user.lakeformation_admin.name
  policy_arn = aws_iam_policy.lakeformation_admin_policy.arn
}

# Grant Lake Formation administrator permissions
resource "aws_lakeformation_data_lake_settings" "data_lake_settings" {
  admins = [aws_iam_user.lakeformation_admin.arn]
}
