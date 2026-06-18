# ---------------------------------------------------------------------------------------------------------------------
# PLEASE NOTE
# The following template is designed to be run in OCI Resource Manager. It is not intended to be run using Terraform.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}

# Determines the home region for the tenancy. Region subscriptions are global,
# so this works correctly regardless of which region the stack is deployed in.
data "oci_identity_region_subscriptions" "homeregion" {
  tenancy_id = var.tenancy_ocid
  filter {
    name   = "is_home_region"
    values = ["true"]
  }
}

provider "oci" {
  alias  = "home_region"
  region = data.oci_identity_region_subscriptions.homeregion.region_subscriptions[0].region_name
}

module "iom" {
  source = "./modules/iom"

  providers = {
    oci.home_region = oci.home_region
  }

  tenancy_ocid         = var.tenancy_ocid
  expected_home_region = var.expected_home_region
  home_region_name     = data.oci_identity_region_subscriptions.homeregion.region_subscriptions[0].region_name
  user_name            = var.user_name
  group_name           = var.group_name
  policy_name          = var.policy_name
  user_email_address   = var.user_email_address
  api_public_key       = var.api_public_key
}
