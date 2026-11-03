variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "github_repository" {
  type        = string
  description = "owner/repo, e.g. arun-konderu/gcp-hospital-edge-platform"
}

variable "domain" {
  type = string
}

variable "authorized_networks" {
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}
