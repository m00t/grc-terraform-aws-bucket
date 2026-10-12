# METADATA
# title: SC-28 - Encryption at Rest (AWS S3)
# description: Every aws_s3_bucket must have a matching server-side encryption configuration.
# custom:
#   control_id: SC-28
#   framework: nist-800-53
#   severity: high
#   remediation: Add aws_s3_bucket_server_side_encryption_configuration referencing the bucket.
package compliance.sc28_aws

import rego.v1

# Deny any aws_s3_bucket that has no matching
# aws_s3_bucket_server_side_encryption_configuration.
#
# Technique: at plan time the bucket name is unknown, so match by reference, not
# value. Bucket addresses live in input.configuration.root_module.resources[]
# (type == "aws_s3_bucket"). The encryption resource references its bucket in
# .expressions.bucket.references (strings like "aws_s3_bucket.primary.id").


# Deny every bucket that no encryption configuration points at.
deny contains msg if {
	some bucket in input.configuration.root_module.resources
	bucket.type == "aws_s3_bucket"
	address := sprintf("%s.%s", [bucket.type, bucket.name])
	not has_encryption(address)
	msg := sprintf(
		"SC-28: %s has no server-side encryption configuration. Remediation: add an aws_s3_bucket_server_side_encryption_configuration with bucket = %s.id.",
		[address, address],
	)
}

# True if any encryption config's `bucket` argument references this bucket. We compare references (ex. "aws_s3_bucket.primary.id"), not bucket names, because names are unknown at plan time.
has_encryption(address) if {
	some enc in input.configuration.root_module.resources
	enc.type == "aws_s3_bucket_server_side_encryption_configuration"
	some ref in enc.expressions.bucket.references
	refers_to(ref, address)
}

# "aws_s3_bucket.primary" or "aws_s3_bucket.primary.<attr>" both count.
refers_to(ref, address) if ref == address

refers_to(ref, address) if startswith(ref, concat("", [address, "."]))

