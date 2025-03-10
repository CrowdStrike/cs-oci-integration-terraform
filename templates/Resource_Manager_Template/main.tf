# ---------------------------------------------------------------------------------------------------------------------
# PLEASE NOTE
# The following template is designed to be run in OCI Resource Manager. It is not intended to be run using Terraform.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.2.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 4.0"
    }
  }
}

module "iom" {
  source = "./modules/iom"

  tenancy_ocid         = var.tenancy_ocid
  expected_home_region = var.expected_home_region
  user_name           = var.user_name
  group_name          = var.group_name
  policy_name         = var.policy_name
  user_email_address  = var.user_email_address
  api_public_key      = var.api_public_key
}
