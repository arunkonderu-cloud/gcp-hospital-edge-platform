output "ingress_ip_name" {
  value = google_compute_global_address.ingress.name
}

output "ingress_ip" {
  value = google_compute_global_address.ingress.address
}

output "certificate_map" {
  value = google_certificate_manager_certificate_map.this.name
}

output "security_policy" {
  value = google_compute_security_policy.armor.name
}
