# GCP + Hospital Edge Platform

A reference platform for running healthcare microservices on **GKE** and on
**on-premise hospital servers** with one build, one Helm chart, and one security
baseline — built to be **HIPAA / SOC 2 audit-ready** from day one.

> Sample workload: `tray-tracker`, a small API that records surgical-tray scan
> events (expected vs. detected instruments). It accepts no patient identifiers.

## What's in here

| Area | What it shows | Where |
|---|---|---|
| **GCP foundation (Terraform)** | Private VPC, Cloud NAT, default-deny firewall, VPC flow logs | `terraform/modules/network` |
| **GKE** | Private nodes, Workload Identity, Shielded nodes, Dataplane V2, CMEK secrets encryption, Binary Authorization, Managed Prometheus | `terraform/modules/gke` |
| **Artifact Registry** | CMEK, immutable tags, cleanup policies, on-push scanning, read-only edge pull identity | `terraform/modules/artifact-registry` |
| **Load balancing** | Global external HTTPS LB via Gateway API, Certificate Manager, Cloud Armor (OWASP + rate limit) | `terraform/modules/lb`, `helm/.../gateway.yaml` |
| **Security & audit** | KMS (90-day rotation), Data Access audit logs, locked-retention audit bucket, BinAuthz attestor | `terraform/modules/security` |
| **Keyless CI auth** | GitHub OIDC → Workload Identity Federation, repo-pinned; zero JSON keys | `terraform/modules/github-wif` |
| **Container** | Multi-stage → distroless, non-root, read-only rootfs | `app/Dockerfile` |
| **CI** | Tests, Ruff, **Semgrep SAST**, **Trivy** (IaC config, dependencies), terraform validate, helm lint | `.github/workflows/ci.yml` |
| **CD** | Build → **Trivy image scan (gate)** → SBOM → push by digest → **KMS-signed attestation** → `helm --atomic` to GKE → GitOps PR to hospital canary | `.github/workflows/release.yml` |
| **Hospital edge** | Hardened k3s bootstrap, secrets encryption, API audit log, on-site registry mirror, ArgoCD pull-based GitOps, canary → general waves | `edge/` |
| **Edge observability** | Logs + audit shipped outbound, disk-buffered, PHI-pattern redaction | `edge/observability` |
| **Compliance** | Control-by-control HIPAA / SOC 2 mapping | `docs/compliance-controls.md` |

## Architecture

See [`docs/architecture.md`](docs/architecture.md).

```
 GitHub ──PR──► CI (test · Semgrep · Trivy config/deps · tf validate · helm lint)
   │
   └─main──► Release: build ─► Trivy image gate ─► SBOM ─► push (digest) ─► sign/attest
                 │                                                   │
                 ▼                                                   ▼
        GKE (private, BinAuthz enforced)                 GitOps PR: edge/sites/canary
        Gateway ─► Global HTTPS LB + Cloud Armor                    │ merge
                                                                    ▼
                                         Hospital k3s ── ArgoCD pulls (outbound only)
                                         registry mirror · audit log · promtail ─► central logs
```

## Run it

```bash
# 0. Local app
cd app && pip install -r requirements-dev.txt && pytest -q
docker build -t tray-tracker:local . && docker run -p 8080:8080 tray-tracker:local

# 1. GCP (needs a project with billing)
./terraform/bootstrap.sh <PROJECT_ID>
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars   # edit
terraform init -backend-config="bucket=<PROJECT_ID>-tfstate"
terraform plan && terraform apply

# 2. GitHub repo variables (from terraform output)
#    GCP_PROJECT_ID, WIF_PROVIDER, CI_SERVICE_ACCOUNT,
#    BINAUTHZ_ATTESTOR, BINAUTHZ_KEY_VERSION, APP_GSA

# 3. Hospital edge simulation (any Ubuntu VM / multipass)
sudo SITE_ID=hospital-canary ./edge/bootstrap/install-k3s.sh
kubectl apply -f edge/bootstrap/registry-mirror.yaml
kubectl apply -f edge/argocd/applicationset.yaml
```

**Cost note:** the dev env uses a small regional node pool (e2-standard-2, 1–3
nodes). Run `terraform destroy` when you're done.

## Design decisions (and trade-offs)

- **Pull, not push, to hospitals.** Hospital IT will rarely open inbound ports.
  ArgoCD on each site pulls from Git over outbound HTTPS, retries for 30 min on a
  flaky WAN, and self-heals drift. Trade-off: one ArgoCD per site to operate.
- **Deploy by digest + Binary Authorization.** A tag can be moved; a digest
  can't. GKE refuses any image CI didn't scan and sign. Edge sites enforce the
  same via the digest pinned in Git.
- **Same chart, two value files.** GKE and edge differ only in values (LB vs.
  Traefik, HPA vs. fixed replica, PodMonitoring vs. ServiceMonitor). Fewer
  snowflakes = fewer audit findings.
- **Canary hospital first.** One site bakes for 24h before the general wave;
  promotion is a reviewed PR, which doubles as SOC 2 change-management evidence.
- **Registry mirror on site.** If the WAN drops, pods can still restart.
- **GKE Standard over Autopilot** here to show node hardening (Shielded nodes,
  boot-disk CMEK). Autopilot is a valid choice for a small team.

## What I'd add next

Cloud SQL with private IP + CMEK, External Secrets / Secret Manager, Config
Connector or Policy Controller (Gatekeeper) constraints, cosign verification on
edge via Kyverno, SLO dashboards and burn-rate alerts, and a fleet view
(GKE Enterprise / Rancher) once site count grows past ~10.
