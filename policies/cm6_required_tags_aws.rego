# METADATA
# title: CM-6 - Configuration Settings (AWS required tags)
# description: Taggable resources must carry the four required compliance tags.
# custom:
#   control_id: CM-6
#   framework: nist-800-53
#   severity: medium
#   remediation: Add the missing tags or rely on provider default_tags.
package compliance.cm6_aws

import rego.v1

required := {"Project", "Environment", "ManagedBy", "ComplianceScope"}

# The four tags every taggable resource must have (set in main.tf default_tags).
required_tags := {"Project", "Environment", "ManagedBy", "ComplianceScope"}

# Deny any taggable resource (like primary and log) missing a required tag.
deny contains msg if {
	some r in input.planned_values.root_module.resources
	tags := r.values.tags_all
	missing := {t | some t in required_tags; not tags[t]}
	count(missing) > 0
	msg := sprintf(
		"CM-6: %s is missing required tag(s): %s. Remediation: add them to the provider default_tags block in main.tf.",
		[r.address, concat(", ", sort(missing))],
	)
}