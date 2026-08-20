# Terraform AWS GRC-Compliant Storage Bucket

This Terraform module provisions an AWS S3 storage bucket engineered to meet rigorous Governance, Risk, and Compliance (GRC) standards. It enforces specific **NIST SP 800-53** security controls and automatically generates JSON compliance evidence for auditing.

## Enforced NIST SP 800-53 Controls

* **SC-28 (Protection of Information at Rest):** Enforces mandatory server-side encryption configuration across storage buckets.
* **AC-3 (Access Enforcement):** Blocks all public access via strict S3 Public Access Block configurations.
* **CM-6 (Configuration Settings):** Enforces bucket versioning and standardized resource tagging to maintain configuration baselines.
* **AU-3 (Content of Audit Records):** Configures dedicated access logging and audit trails.

## Repository Structure

* `main.tf`: Core resource definitions, encryption, access controls, and logging configurations.
* `variables.tf`: Input variables for customization.
* `outputs.tf`: Module outputs including encryption details.
* `verify.sh`: Post-apply validation script for control verification.
* `evidence/`: Contains JSON proof artifacts generated from Terraform execution plans.

## Usage

1. Initialize the Terraform environment:
   ```bash
   terraform init