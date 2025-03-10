variable "tenancy_ocid" {
  description = "OCI Tenancy where the template is currently running"
}

variable "expected_home_region" {
  description = "The Home Region that was specified when registering this OCI tenancy"
}

variable "user_name" {
  description = "Friendly name for the OCI IAM user"
}

variable "group_name" {
  description = "Friendly name for the OCI IAM group"
}

variable "policy_name" {
  description = "Friendly name for the OCI IAM policy"
}

variable "user_email_address" {
  description = "Email address for the IAM user"
  default     = ""
}

variable "api_public_key" {
  description = "Public key portion of an OCI User API Key"
}
