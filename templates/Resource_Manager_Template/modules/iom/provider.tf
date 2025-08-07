# Providers

# OCI Provider set to home region
provider "oci" {
  alias  = "home_region"
  region = data.oci_identity_region_subscriptions.homeregion.region_subscriptions[0].region_name
}