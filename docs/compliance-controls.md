# HIPAA / SOC 2 control mapping

How each control is implemented and where an auditor finds evidence.

| Requirement | HIPAA Security Rule | SOC 2 (TSC) | Implementation | Evidence |
|---|---|---|---|---|
| Unique identities, least privilege | §164.312(a)(1) Access control | CC6.1, CC6.3 | Per-workload GSAs via Workload Identity; node SA has 5 minimal roles; CI SA scoped to deploy + attest; edge SA read-only on one repo | `terraform/modules/*` IAM resources, `gcloud projects get-iam-policy` |
| No long-lived credentials | §164.312(d) Authentication | CC6.1 | GitHub OIDC → WIF, repo-pinned attribute condition | `terraform/modules/github-wif` |
| Encryption at rest | §164.312(a)(2)(iv) | CC6.1, C1.1 | CMEK on etcd secrets, node boot disks, Artifact Registry, audit bucket; key rotation 90 days; k3s `secrets-encryption` on edge | `terraform/modules/security`, `edge/bootstrap/install-k3s.sh` |
| Encryption in transit | §164.312(e)(1) | CC6.7 | Google-managed TLS on LB; edge egress HTTPS only | `terraform/modules/lb` |
| Audit logging | §164.312(b) Audit controls | CC7.2 | Admin + Data Access logs on all services; GKE API server logs; k3s API audit policy; VPC flow logs | `security/main.tf`, `network/main.tf`, edge audit policy |
| Log integrity & retention | §164.316(b)(2) (6 yrs) | CC7.2, CC7.3 | Sink → CMEK bucket with retention policy (lockable), versioning | `security/main.tf` |
| Vulnerability management | §164.308(a)(1)(ii)(A) Risk analysis | CC7.1 | Semgrep SAST + Trivy config/deps on every PR; Trivy image gate on release; Artifact Registry on-push scanning; GKE security posture; findings in GitHub Security tab until closed | `.github/workflows/*` |
| Change management | §164.308(a)(8) Evaluation | CC8.1 | All infra in Terraform; all deploys via PR; edge promotion is a reviewed PR; immutable tags + digest deploys | Git history, PR reviews |
| Software supply chain | — | CC8.1, CC7.1 | SBOM per release; KMS-signed BinAuthz attestations; enforced admission | `release.yml`, `security/main.tf` |
| Network segmentation | §164.312(e)(1) | CC6.6 | Private nodes, default-deny firewall, Kubernetes NetworkPolicy, Cloud Armor, hospital host firewall (ufw) | `network/main.tf`, `helm/.../policies.yaml` |
| Availability / contingency | §164.308(a)(7) Contingency plan | A1.2 | Regional GKE, PDB, HPA, atomic rollback; edge registry mirror + disk-buffered logs for WAN loss | `gke/main.tf`, `edge/` |
| Minimum necessary / PHI handling | §164.502(b) | C1.1 | API rejects free-text identifiers; no PHI in logs; promtail redaction stage on edge | `app/src/main.py`, `edge/observability` |

## Gaps I'd close before a real SOC 2 Type II
- Lock the audit bucket retention policy in prod (irreversible, needs sign-off).
- Org-level policy constraints (no external IPs, restrict CMEK-less resources).
- Quarterly access reviews and break-glass procedure documented.
- Backup + restore test evidence (Cloud SQL PITR, Velero for edge).
- Formal incident response runbook tied to Cloud Monitoring alert policies.
