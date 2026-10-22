terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project         = "compliance-lab"
      Environment     = "dev"
      ManagedBy       = "Terraform"
      ComplianceScope = "NIST"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  primary_name = "${var.project_name}-${var.environment}-data-${random_id.suffix.hex}"
  log_name     = "${var.project_name}-${var.environment}-logs-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "primary" {
  bucket = local.primary_name
}

resource "aws_s3_bucket" "log" {
  bucket = local.log_name
}



# SC-28: Encrypt log bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "log_encryption" {
  bucket = aws_s3_bucket.log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#  CM-6   turn on versioning for the primary bucket
resource "aws_s3_bucket_versioning" "primary_versioning" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

#AC-3   block public access on primary bucket
resource "aws_s3_bucket_public_access_block" "primary_public_access" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#AC-3   block public access on log bucket
resource "aws_s3_bucket_public_access_block" "log_public_access" {
  bucket                  = aws_s3_bucket.log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#AU-3 Log bucket ownership control 
resource "aws_s3_bucket_ownership_controls" "log_ownership" {
  bucket = aws_s3_bucket.log.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#AU-3 Log bucket ACL for log delivery
resource "aws_s3_bucket_acl" "log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.log_ownership]

  bucket = aws_s3_bucket.log.id
  acl    = "log-delivery-write"
}

#AU-3 Point primary bucket logging to the log bucket
resource "aws_s3_bucket_logging" "primary_logging" {
  bucket = aws_s3_bucket.primary.id

  target_bucket = aws_s3_bucket.log.bucket
  target_prefix = "log/"
}

