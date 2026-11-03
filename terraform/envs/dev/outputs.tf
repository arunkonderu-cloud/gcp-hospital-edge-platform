output "repository_url" {
  value = module.artifact_registry.repository_url
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "ci_service_account" {
  value = module.github_wif.ci_service_account_email
}

output "workload_identity_provider" {
  value = module.github_wif.workload_identity_provider
}

output "attestor" {
  value = module.security.attestor_name
}

output "attestor_key_version" {
  value = module.security.attestor_key_version
}

output "ingress_ip" {
  value = module.lb.ingress_ip
}

output "edge_puller_sa" {
  value = module.artifact_registry.edge_puller_email
}
