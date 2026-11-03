variable "project_id" {
  type = string
}

variable "name" {
  type = string
}

variable "domain" {
  type        = string
  description = "Public hostname for the API, e.g. api.dev.example.com"
}
