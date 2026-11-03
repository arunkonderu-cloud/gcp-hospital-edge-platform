#!/usr/bin/env bash
# Bootstrap a hardened single-node k3s cluster on a hospital edge server.
# Assumptions: Ubuntu 22.04/24.04, outbound HTTPS only (no inbound from internet),
# hospital IT has allowed egress to *.pkg.dev, github.com, and the VPN endpoint.
#
# usage: sudo SITE_ID=hospital-a ./install-k3s.sh
set -euo pipefail

SITE_ID="${SITE_ID:?set SITE_ID, e.g. hospital-a}"
K3S_VERSION="${K3S_VERSION:-v1.30.6+k3s1}"   # pin; upgraded via system-upgrade-controller

echo "[1/6] OS hardening"
apt-get update -y && apt-get install -y unattended-upgrades auditd ufw curl
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now auditd
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.0.0.0/8 to any port 443 proto tcp   # hospital LAN -> Traefik
ufw --force enable

echo "[2/6] k3s config (CIS-aligned: secrets encryption, audit log, protect kernel defaults)"
mkdir -p /etc/rancher/k3s /var/lib/rancher/k3s/server/logs
cat >/etc/rancher/k3s/config.yaml <<EOF
node-label:
  - "site=${SITE_ID}"
secrets-encryption: true
protect-kernel-defaults: true
write-kubeconfig-mode: "0600"
kube-apiserver-arg:
  - "audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log"
  - "audit-policy-file=/etc/rancher/k3s/audit-policy.yaml"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"
EOF

cat >/etc/rancher/k3s/audit-policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
  - level: None
    verbs: ["get", "list", "watch"]
EOF

cat >/etc/sysctl.d/90-kubelet.conf <<'EOF'
vm.panic_on_oom=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1
EOF
sysctl --system >/dev/null

echo "[3/6] Local registry mirror config (sites keep running if the WAN drops)"
cat >/etc/rancher/k3s/registries.yaml <<'EOF'
mirrors:
  "us-east1-docker.pkg.dev":
    endpoint:
      - "http://127.0.0.1:30500"   # edge/bootstrap/registry-mirror.yaml
      - "https://us-east1-docker.pkg.dev"
EOF

echo "[4/6] Install k3s ${K3S_VERSION}"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server

echo "[5/6] Install ArgoCD (pull-based GitOps: site reaches out, nothing reaches in)"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml

echo "[6/6] Register this site"
kubectl -n argocd create configmap site-identity \
  --from-literal=siteId="${SITE_ID}" --dry-run=client -o yaml | kubectl apply -f -

echo "Done. Next:"
echo "  kubectl apply -f edge/bootstrap/registry-mirror.yaml"
echo "  kubectl apply -f edge/argocd/applicationset.yaml"
