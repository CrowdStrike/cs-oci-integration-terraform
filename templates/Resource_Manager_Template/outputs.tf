output "user_ocid" {
  value = oci_identity_user.fcs_inventory_user.id
  description = "OCID of user created for use by CrowdStrike. Copy this OCID and paste into last step of OCI tenancy registration wizard in CrowdStrike to finish tenancy registration process."
}

output "template_version" {
  value = "v0.3.2"
  description = "The version of CrowdStrike's OCI integration supported by this template."
}

