output "repository_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "edge_puller_email" {
  value = google_service_account.edge_puller.email
}
