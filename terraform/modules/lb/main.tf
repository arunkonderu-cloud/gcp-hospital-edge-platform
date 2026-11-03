# Global external HTTPS load balancer in front of GKE (via Gateway API / NEGs).
# This module owns the parts that should not live in Kubernetes manifests:
# static IP, Google-managed TLS cert, and a Cloud Armor policy.

resource "google_compute_global_address" "ingress" {
  name    = "${var.name}-ingress-ip"
  project = var.project_id
}

resource "google_certificate_manager_certificate" "api" {
  name    = "${var.name}-api-cert"
  project = var.project_id

  managed {
    domains = [var.domain]
  }
}

resource "google_certificate_manager_certificate_map" "this" {
  name    = "${var.name}-cert-map"
  project = var.project_id
}

resource "google_certificate_manager_certificate_map_entry" "api" {
  name         = "${var.name}-api-entry"
  project      = var.project_id
  map          = google_certificate_manager_certificate_map.this.name
  certificates = [google_certificate_manager_certificate.api.id]
  hostname     = var.domain
}

# WAF: OWASP preconfigured rules + per-client rate limiting.
resource "google_compute_security_policy" "armor" {
  name    = "${var.name}-armor"
  project = var.project_id

  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable') || evaluatePreconfiguredWaf('xss-v33-stable')"
      }
    }
    description = "OWASP SQLi/XSS"
  }

  rule {
    action   = "throttle"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 600
        interval_sec = 60
      }
    }
    description = "Rate limit per IP"
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default allow"
  }
}
