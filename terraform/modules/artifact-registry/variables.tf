variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "repository_id" {
  type    = string
  default = "services"
}

variable "kms_key_id" {
  type = string
}

variable "keep_versions" {
  type    = number
  default = 20
}

variable "ci_service_account_email" {
  type        = string
  description = "CI identity (from the WIF module) allowed to push images"
}
