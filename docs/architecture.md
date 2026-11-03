# Architecture

```mermaid
flowchart LR
  dev[Engineer] -->|PR| gh[GitHub]
  gh -->|ci.yml| ci[Tests · Semgrep · Trivy config/deps · tf validate · helm lint]
  gh -->|release.yml on main| rel[Build → Trivy image gate → SBOM]
  rel -->|OIDC / WIF| ar[(Artifact Registry\nCMEK · immutable tags)]
  rel -->|KMS sign| att[BinAuthz attestation]

  subgraph GCP["GCP project (Terraform)"]
    ar
    att
    lb[Global HTTPS LB\nCloud Armor · Cert Manager] --> gke
    gke[Private GKE\nWorkload Identity · Dataplane V2\nBinAuthz ENFORCED]
    kms[Cloud KMS\n90-day rotation]
    logs[(Audit bucket\nlocked retention)]
  end

  rel -->|helm --atomic| gke
  rel -->|GitOps PR| repo[edge/sites/canary]

  subgraph H1["Hospital site (on-prem)"]
    k3s[k3s · secrets encryption · API audit]
    argo[ArgoCD] --> k3s
    mirror[Registry mirror]
    pt[Promtail]
  end

  repo -.->|outbound pull| argo
  ar -.->|outbound pull| mirror
  pt -.->|outbound push| logs
  gke --> logs
```

## Request path (cloud)
Client → Global external HTTPS LB (Cloud Armor WAF + rate limit, Google-managed
cert) → NEG → tray-tracker pods (non-root, read-only FS, NetworkPolicy).

## Request path (hospital)
Hospital LAN device → Traefik (k3s) → tray-tracker pod. No public exposure.

## Failure modes I designed for

| Failure | Behavior |
|---|---|
| Hospital WAN down | Pods keep running; restarts pull from local mirror; ArgoCD retries with backoff; logs buffer on disk |
| Bad release | `helm --atomic` rolls back on GKE; canary hospital catches it before the general wave; revert PR rolls edge back |
| Unscanned / unsigned image | Binary Authorization blocks it at admission on GKE |
| Leaked CI credential | No long-lived keys exist; WIF token is short-lived and pinned to one repo |
| Node compromise | Shielded VM + secure boot, no legacy metadata, Workload Identity limits blast radius |
