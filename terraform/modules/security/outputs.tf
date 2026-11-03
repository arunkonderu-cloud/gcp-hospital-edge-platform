output "kms_key_id" {
  value = google_kms_crypto_key.cmek.id
}

output "attestor_name" {
  value = google_binary_authorization_attestor.ci.name
}

output "attestor_key_version" {
  value = data.google_kms_crypto_key_version.attestor.id
}

output "audit_bucket" {
  value = google_storage_bucket.audit_logs.name
}
