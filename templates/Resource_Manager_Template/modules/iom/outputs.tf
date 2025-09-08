output "user_ocid" {
  value       = oci_identity_user.fcs_inventory_user.id
  description = "OCID of user created for use by CrowdStrike"
}

output "template_version" {
  value       = "v0.3.22"
  description = "The version of CrowdStrike's OCI integration supported by this template"
}
