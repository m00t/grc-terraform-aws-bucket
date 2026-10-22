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
* `.github/workflows/grc-gate.yml`: CI policy gate that runs the policies on every pull request to `main`.

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

## CI Policy Gate

Every pull request to `main` runs `.github/workflows/grc-gate.yml`. Nobody reviews a change for
encryption, public access or tagging by hand: the pipeline does it in seconds.

**What the gate does:**

1. Installs Conftest at a pinned version (`0.62.0`).
2. Runs the SC-28, AC-3 and CM-6 policies against the committed Terraform plan (`plan.json`).
3. Fails the job if any policy reports a violation (fail closed).
4. Uploads the results (`evidence/conftest-results.json`) as a build artifact on every run, pass or fail.

**What happens when a control breaks:** the matching policy fails, the `grc-gate` check goes red,
and branch protection on `main` requires that check to pass, so the pull request cannot be merged
by anyone until the violation is fixed. The failure message names the resource and the remediation,
and the evidence artifact keeps a record of the failure.

| Pull request | Change | Result |
|---|---|---|
| [#1](https://github.com/m00t/grc-terraform-aws-bucket/pull/1) | Compliant plan | ✅ `grc-gate` passed, merged |
| [#2](https://github.com/m00t/grc-terraform-aws-bucket/pull/2) | Plan with the primary bucket's encryption removed | ❌ SC-28 failed, merge blocked |

Example failure from #2:

```
SC-28: aws_s3_bucket.primary has no server-side encryption configuration.
Remediation: add an aws_s3_bucket_server_side_encryption_configuration with bucket = aws_s3_bucket.primary.id.
```