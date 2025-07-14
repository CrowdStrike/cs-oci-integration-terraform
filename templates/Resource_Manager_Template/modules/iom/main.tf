terraform {
  required_version = ">= 1.2.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 4.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
#LOCALS
# ---------------------------------------------------------------------------------------------------------------------


locals {
  email         = data.oci_identity_domains.default_domain.domains == null ? "" : var.user_email_address
  idcs_endpoint = data.oci_identity_domains.default_domain.domains == null ? "" : data.oci_identity_domains.default_domain.domains[0].url

  #The following locals are used to ensure that the provided OCI User API public key is formatted correctly

  # --------------------------------------------------------------
  # START OF OCI USER API PUBLIC KEY FORMATING
  # --------------------------------------------------------------

  # Remove all whitespace and newline characters
  cleaned_key = replace(var.api_public_key, "/\\s+/", "")

  # Extract the key content (remove BEGIN and END labels if present)
  key_content = replace(
    replace(local.cleaned_key, "-----BEGINPUBLICKEY-----", ""),
    "-----ENDPUBLICKEY-----",
    ""
  )

  # Break public key string into a list, with each element consisting of 64 characters
  api_public_key_list = [
    for i in range(0, length(local.key_content), 64) : substr(local.key_content, i, 64)
  ]

  # Reformat public key to have lines of 64 characters each
  api_public_key_lines = join("\n", local.api_public_key_list)

  # Add labels, making key match standards defined by RFC7468
  reformatted_api_public_key = trimspace("-----BEGIN PUBLIC KEY-----\n${local.api_public_key_lines}\n-----END PUBLIC KEY-----")

  # --------------------------------------------------------------
  # END OF OCI USER API PUBLIC KEY FORMATING
  # --------------------------------------------------------------
}


# ---------------------------------------------------------------------------------------------------------------------
#VALIDATION CHECKS AND DATA RETRIEVAL
# ---------------------------------------------------------------------------------------------------------------------


# This will see if a the Default Identity Domain exists in the tenancy, to determine if tenancy uses Identity Domains or not (the resources that get deployed change depending on if a tenancy is using Identity Domains and data from the default domain is needed to configure some of the resources).
data "oci_identity_domains" "default_domain" {
  compartment_id = var.tenancy_ocid
  display_name   = "Default"
}

# Determines the home region for the Tenancy where this template is being deployed
data "oci_identity_region_subscriptions" "homeregion" {
  tenancy_id = var.tenancy_ocid
  filter {
    name   = "is_home_region"
    values = ["true"]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
#DEPLOY RESOURCES
# ---------------------------------------------------------------------------------------------------------------------


# Creates new IAM user that will be used by Falcon Cloud Security to access tenancy
resource "oci_identity_user" "fcs_inventory_user" {
  compartment_id = var.tenancy_ocid
  name           = var.user_name
  description    = "DO NOT TOUCH. Service account used by CrowdStrike to inventory resources in tenancy"
  email          = local.email

  # Checks that the tenancy's home region matches the value that was provided in the first step of the Falcon Cloud Security registration wizard
  lifecycle {
    precondition {
      condition     = var.expected_home_region == data.oci_identity_region_subscriptions.homeregion.region_subscriptions[0].region_name
      error_message = "This tenancy has been configured in Falcon Cloud Security with a home region of ${var.expected_home_region}. It appears that the actual home region is ${data.oci_identity_region_subscriptions.homeregion.region_subscriptions[0].region_name}. To fix this:\n1. Delete this stack in OCI Resource Manager. \n2. Go to the Falcon Cloud Security console and open the registration wizard for this tenancy.\n3. Go to Step 1 in the wizard and change the Home Region dropdown from ${var.expected_home_region} to ${data.oci_identity_region_subscriptions.homeregion.region_subscriptions[0].region_name}.\n4. Download the updated template.\n5. Return to OCI Resource Manager and run the new template."
    }
  }
}


# Creates group to house the IAM user defined by "fcs_inventory_user"
resource "oci_identity_group" "fcs_inventory_group" {
  compartment_id = var.tenancy_ocid
  name           = var.group_name
  description    = "DO NOT TOUCH. Group for CrowdStrike Falcon Cloud Security (FCS) service account. Used by FCS to generate inventory of all supported resources in the tenancy"
}

# Add "fcs_inventory_user" to "fcs_inventory_group"
resource "oci_identity_user_group_membership" "fcs_user_into_group" {
  group_id = oci_identity_group.fcs_inventory_group.id
  user_id  = oci_identity_user.fcs_inventory_user.id
}

# Creates new policy with permissions Falcon Cloud Security needs to monitor supported resources in the tenancy. Policy's permissions get applied to users in "fcs_inventory_group"
# This resource will get created if domain is not enabled
resource "oci_identity_policy" "fcs_inventory_policy_without_domains" {
  count          = data.oci_identity_domains.default_domain.domains == null ? 1 : 0
  name           = var.policy_name
  description    = "DO NOT TOUCH. This policy allows CrowdStrike Falcon Cloud Security to create an inventory of all supported resources in the tenancy"
  compartment_id = var.tenancy_ocid
  statements = [
    "Allow group ${var.group_name} to read policies in tenancy",
    "Allow group ${var.group_name} to inspect compartments in tenancy",
    "Allow group ${var.group_name} to inspect users in tenancy",
    "Allow group ${var.group_name} to inspect groups in tenancy",
    "Allow group ${var.group_name} to inspect domains in tenancy",
    "Allow group ${var.group_name} to inspect orm-stacks in tenancy",
    "Allow group ${var.group_name} to read orm-jobs in tenancy",
    "Allow group ${var.group_name} to read instances in tenancy",
    "Allow group ${var.group_name} to read buckets in tenancy",
    "Allow group ${var.group_name} to read virtual-network-family in tenancy",
    "Allow group ${var.group_name} to inspect autonomous-database-family in tenancy",
    "Allow group ${var.group_name} to read vaults in tenancy",
    "Allow group ${var.group_name} to read keys in tenancy",
    "Allow group ${var.group_name} to read file-family in tenancy",
    "Allow group ${var.group_name} to read cluster-family in tenancy",
    "Allow group ${var.group_name} to read cloudevents-rules in tenancy",
    "Allow group ${var.group_name} to read volume-family in tenancy",
    "Allow group ${var.group_name} to read load-balancers in tenancy"

  ]
}

# Creates new policy with permissions Falcon Cloud Security needs to monitor supported resources in the tenancy. Policy's permissions get applied to users in "fcs_inventory_group"
# This resource will get created if domain enabled
resource "oci_identity_policy" "fcs_inventory_policy_with_domains" {
  count          = data.oci_identity_domains.default_domain.domains != null ? 1 : 0
  name           = var.policy_name
  description    = "DO NOT TOUCH. This policy allows CrowdStrike Falcon Cloud Security to create an inventory of all supported resources in the tenancy"
  compartment_id = var.tenancy_ocid
  statements = [
    "Allow group 'Default'/'${var.group_name}' to read policies in tenancy",
    "Allow group 'Default'/'${var.group_name}' to inspect compartments in tenancy",
    "Allow group 'Default'/'${var.group_name}' to inspect users in tenancy",
    "Allow group 'Default'/'${var.group_name}' to inspect groups in tenancy",
    "Allow group 'Default'/'${var.group_name}' to inspect domains in tenancy",
    "Allow group 'Default'/'${var.group_name}' to inspect orm-stacks in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read orm-jobs in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read instances in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read buckets in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read virtual-network-family in tenancy",
    "Allow group 'Default'/'${var.group_name}' to inspect autonomous-database-family in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read vaults in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read keys in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read file-family in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read cluster-family in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read cloudevents-rules in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read volume-family in tenancy",
    "Allow group 'Default'/'${var.group_name}' to read load-balancers in tenancy"
  ]
}

# Associates the public key portion of an API key with the IAM user defined by "fcs_inventory_user". Falcon Cloud Security will use this API key to authenticate into tenancy as the associated IAM user.
# This resource is only created if tenancy uses Identity Domains.
resource "oci_identity_domains_api_key" "fcs_inventory_user_api_key" {
  count         = data.oci_identity_domains.default_domain.domains != null ? 1 : 0
  idcs_endpoint = local.idcs_endpoint
  key           = local.reformatted_api_public_key
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:apikey"]

  user {
    ocid = oci_identity_user.fcs_inventory_user.id
  }

  lifecycle {
    ignore_changes = [
      # Ignore fields that will never be returned
      urnietfparamsscimschemasoracleidcsextensionself_change_user
    ]
  }
}

# Associates the public key portion of an API key with the IAM user defined by "fcs_inventory_user". Falcon Cloud Security will use this API key to authenticate into tenancy as the associated IAM user.
# This resource is only created if tenancy does not use Identity Domains.
resource "oci_identity_api_key" "fcs_inventory_user_api_key" {
  count     = data.oci_identity_domains.default_domain.domains == null ? 1 : 0
  key_value = local.reformatted_api_public_key
  user_id   = oci_identity_user.fcs_inventory_user.id
}
