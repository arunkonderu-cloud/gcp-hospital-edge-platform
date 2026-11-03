# Docker repo in Artifact Registry:
# - CMEK encrypted
# - immutable tags (a version can never be silently overwritten — audit traceability)
# - cleanup policy keeps the last N versions, deletes untagged images after 14 days
# - on-push vulnerability scanning via Container Analysis

resource "google_project_service" "scanning" {
  project            = var.project_id
  service            = "containerscanning.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "docker" {
  provider = google-beta

  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Service images for GKE and hospital edge sites"
  format        = "DOCKER"
  kms_key_name  = var.kms_key_id

  docker_config {
    immutable_tags = true
  }

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent-releases"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_versions
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "1209600s" # 14 days
    }
  }
}

# Edge sites pull with a dedicated read-only identity.
resource "google_service_account" "edge_puller" {
  account_id   = "${var.repository_id}-edge-pull"
  project      = var.project_id
  display_name = "Hospital edge sites: read-only image pull"
}

resource "google_artifact_registry_repository_iam_member" "edge_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.edge_puller.email}"
}

resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.ci_service_account_email}"
}
