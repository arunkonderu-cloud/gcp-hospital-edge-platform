variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "env" {
  type = string
}

variable "network_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

variable "authorized_networks" {
  type = list(object({
    name = string
    cidr = string
  }))
  description = "CIDRs allowed to reach the Kubernetes API (office VPN, CI runners)"
  default     = []
}

variable "kms_key_id" {
  type        = string
  description = "CMEK used for etcd secrets encryption and node boot disks"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 5
}

variable "deletion_protection" {
  type    = bool
  default = true
}
