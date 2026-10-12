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
* `policies/`: Rego policies and unit tests that enforce SC-28, AC-3 and CM-6 against the Terraform plan.

## Usage

1. Initialize the Terraform environment:
   ```bash
   terraform init
   ```

## Policy-as-Code Controls

Rego policies (Open Policy Agent) read the Terraform plan and deny any plan that violates a control.

| Control | Policy | Denies |
|---|---|---|
| **SC-28** Protection of Information at Rest | `policies/sc28_encryption_aws.rego` | Any bucket with no matching encryption configuration |
| **AC-3** Access Enforcement | `policies/ac3_no_public_aws.rego` | Any bucket whose public access block is missing or has any of its four flags not set to `true` |
| **CM-6** Configuration Settings | `policies/cm6_required_tags_aws.rego` | Any taggable resource missing one of the four required tags |

### Test Results

```
policies\sc28_encryption_aws_test.rego:24:
data.compliance.sc28_aws.test_unencrypted_bucket_denied: PASS (2.0935ms)

policies\cm6_required_tags_aws_test.rego:24:
data.compliance.cm6_aws.test_all_tags_present_passes: PASS (2.6631ms)
policies\cm6_required_tags_aws_test.rego:28:
data.compliance.cm6_aws.test_missing_tags_denied: PASS (2.6631ms)

policies\sc28_encryption_aws_test.rego:20:
data.compliance.sc28_aws.test_compliant_bucket_passes: PASS (2.0935ms)

policies\ac3_no_public_aws_test.rego:39:
data.compliance.ac3_aws.test_missing_pab_denied: PASS (2.6631ms)
policies\ac3_no_public_aws_test.rego:35:
data.compliance.ac3_aws.test_complete_pab_passes: PASS (3.1359ms)
--------------------------------------------------------------------------------
PASS: 6/6
```

### Design Note: Match by Reference

At plan time the bucket name is unknown, because its random suffix isn't generated until apply. So the
policies can't match an encryption configuration or public access block to its bucket by name.
Instead they match by reference: the plan JSON records that the encryption resource's `bucket`
argument points at `aws_s3_bucket.primary.id`, and the policy compares that reference to the bucket's
address.