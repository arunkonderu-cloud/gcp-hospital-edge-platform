terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }

  # Remote state in a versioned GCS bucket (create once with bootstrap.sh).
  backend "gcs" {
    prefix = "envs/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  name = "hep-${var.env}"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudkms.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "certificatemanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "security" {
  source     = "../../modules/security"
  project_id = var.project_id
  region     = var.region
  name       = local.name

  depends_on = [google_project_service.apis]
}

module "network" {
  source     = "../../modules/network"
  project_id = var.project_id
  region     = var.region
  name       = local.name

  depends_on = [google_project_service.apis]
}

module "github_wif" {
  source            = "../../modules/github-wif"
  project_id        = var.project_id
  github_repository = var.github_repository

  depends_on = [google_project_service.apis]
}

module "artifact_registry" {
  source                   = "../../modules/artifact-registry"
  project_id               = var.project_id
  region                   = var.region
  kms_key_id               = module.security.kms_key_id
  ci_service_account_email = module.github_wif.ci_service_account_email
}

module "gke" {
  source              = "../../modules/gke"
  project_id          = var.project_id
  region              = var.region
  name                = local.name
  env                 = var.env
  network_name        = module.network.network_name
  subnet_name         = module.network.subnet_name
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  kms_key_id          = module.security.kms_key_id
  authorized_networks = var.authorized_networks
  machine_type        = "e2-standard-2"
  min_nodes           = 1
  max_nodes           = 3
  deletion_protection = false # dev only
}

module "lb" {
  source     = "../../modules/lb"
  project_id = var.project_id
  name       = local.name
  domain     = var.domain

  depends_on = [google_project_service.apis]
}
