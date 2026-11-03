# HIPAA / SOC 2 baseline for the project:
# - KMS keyring + CMEK key with 90-day rotation
# - Data Access audit logs on for all services
# - Org-independent log sink to a locked (retention-policy) bucket: tamper-evident audit trail
# - Binary Authorization policy: only images attested by CI can run on GKE

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_kms_key_ring" "this" {
  name     = "${var.name}-keyring"
  project  = var.project_id
  location = var.region
}

resource "google_kms_crypto_key" "cmek" {
  name            = "${var.name}-cmek"
  key_ring        = google_kms_key_ring.this.id
  rotation_period = "7776000s" # 90 days
  purpose         = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

# Google-managed service agents that need to use the CMEK.
locals {
  cmek_users = [
    "serviceAccount:service-${data.google_project.this.number}@container-engine-robot.iam.gserviceaccount.com",
    "serviceAccount:service-${data.google_project.this.number}@compute-system.iam.gserviceaccount.com",
    "serviceAccount:service-${data.google_project.this.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com",
    "serviceAccount:service-${data.google_project.this.number}@gs-project-accounts.iam.gserviceaccount.com",
  ]
}

resource "google_kms_crypto_key_iam_member" "cmek_users" {
  for_each      = toset(local.cmek_users)
  crypto_key_id = google_kms_crypto_key.cmek.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value
}

# Data Access logs (who read PHI-bearing resources) — HIPAA §164.312(b)
resource "google_project_iam_audit_config" "all_services" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_storage_bucket" "audit_logs" {
  name                        = "${var.project_id}-audit-logs"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  storage_class               = "STANDARD"

  encryption {
    default_kms_key_name = google_kms_crypto_key.cmek.id
  }

  versioning {
    enabled = true
  }

  # 6-year retention (HIPAA documentation retention). Lock in prod after review.
  retention_policy {
    retention_period = var.audit_retention_seconds
    is_locked        = var.lock_retention
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.cmek_users]
}

resource "google_logging_project_sink" "audit" {
  name                   = "${var.name}-audit-sink"
  project                = var.project_id
  destination            = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"
  filter                 = "logName:\"cloudaudit.googleapis.com\""
  unique_writer_identity = true
}

resource "google_storage_bucket_iam_member" "sink_writer" {
  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.audit.writer_identity
}

# --- Binary Authorization -------------------------------------------------

resource "google_container_analysis_note" "ci_attestor" {
  name    = "${var.name}-ci-attestor-note"
  project = var.project_id

  attestation_authority {
    hint {
      human_readable_name = "Built and scanned by CI"
    }
  }
}

resource "google_kms_crypto_key" "attestor" {
  name     = "${var.name}-attestor"
  key_ring = google_kms_key_ring.this.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "EC_SIGN_P256_SHA256"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key_version" "attestor" {
  crypto_key = google_kms_crypto_key.attestor.id
}

resource "google_binary_authorization_attestor" "ci" {
  name    = "${var.name}-ci-attestor"
  project = var.project_id

  attestation_authority_note {
    note_reference = google_container_analysis_note.ci_attestor.name

    public_keys {
      id = data.google_kms_crypto_key_version.attestor.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.attestor.public_key[0].algorithm
      }
    }
  }
}

resource "google_binary_authorization_policy" "this" {
  project = var.project_id

  global_policy_evaluation_mode = "ENABLE"

  # Allow GKE system images.
  admission_whitelist_patterns {
    name_pattern = "gcr.io/gke-release/*"
  }

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.ci.name]
  }
}
