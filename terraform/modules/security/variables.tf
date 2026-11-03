variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "audit_retention_seconds" {
  type        = number
  description = "Audit log retention. Default ~6 years."
  default     = 189216000
}

variable "lock_retention" {
  type        = bool
  description = "Lock the retention policy (irreversible). Keep false in dev."
  default     = false
}
