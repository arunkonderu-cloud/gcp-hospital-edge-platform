variable "project_id" {
  type = string
}

variable "github_repository" {
  type        = string
  description = "owner/repo allowed to assume the CI identity"
}
