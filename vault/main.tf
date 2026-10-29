# Evidence vault: write-once storage for signed grc-gate evidence (S3 Object Lock).
# Applied locally with admin credentials, separate from the gated module in the repo root.
# Short-lived by design: apply, push one run's evidence, verify retention, then destroy.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project         = "compliance-lab"
      Environment     = "dev"
      ManagedBy       = "Terraform"
      ComplianceScope = "NIST"
    }
  }
}

variable "gate_role_name" {
  type        = string
  description = "Name of the existing IAM role the grc-gate workflow assumes via OIDC."
  default     = "grc-gate-plan-readonly"
}

variable "retention_days" {
  type        = number
  description = "Default Object Lock retention for each evidence object."
  default     = 1
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Object Lock can only be enabled when the bucket is created.
resource "aws_s3_bucket" "vault" {
  bucket              = "grc-evidence-vault-${random_id.suffix.hex}"
  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "vault" {
  bucket = aws_s3_bucket.vault.id
  versioning_configuration {
    status = "Enabled"
  }
}

# GOVERNANCE mode: nobody can overwrite or delete a locked version unless they hold
# s3:BypassGovernanceRetention (the pipeline role does not). This allows same-day teardown
# by an admin. COMPLIANCE mode would block deletion by everyone, including root.
resource "aws_s3_bucket_object_lock_configuration" "vault" {
  bucket = aws_s3_bucket.vault.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.retention_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.vault]
}

# SC-28: encrypt at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "vault" {
  bucket = aws_s3_bucket.vault.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# AC-3: block all public access.
resource "aws_s3_bucket_public_access_block" "vault" {
  bucket                  = aws_s3_bucket.vault.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Least privilege for the pipeline: it may only ADD objects under evidence/.
# No read, no delete, no retention changes, no governance bypass.
resource "aws_iam_role_policy" "gate_vault_write" {
  name = "grc-gate-vault-write"
  role = var.gate_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PutEvidenceOnly"
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.vault.arn}/evidence/*"
    }]
  })
}

output "vault_bucket" {
  description = "Set this as the VAULT_BUCKET repository variable in GitHub."
  value       = aws_s3_bucket.vault.id
}