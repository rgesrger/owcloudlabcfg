#!/bin/bash
set -euo pipefail

REPO="/local/repository"
VALUES="${REPO}/openwhisk-values.yaml"
NAMESPACE="openwhisk"
HELM_RELEASE="owdev"

log() { echo "$(date -Iseconds) $*"; }

log "1) Ensure Helm is installed"
if ! command -v helm &> /dev/null; then
  log "Helm not found — installing Helm (official script)"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

log "2) Ensure kubectl can talk to the cluster"
kubectl version --client
kubectl get nodes --no-headers || true

log "3) Create OpenWhisk namespace"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

log "4) Ensure helm repo for OpenWhisk exists and is up to date"
helm repo add openwhisk https://openwhisk.apache.org/charts || true
helm repo update

log "5) Write recommended values to $VALUES (if not present); this file can be edited)"
cat > "$VALUES" <<'EOF'
# openwhisk-values.yaml - recommended overrides for a single-node test/dev cluster
# Keep secrets short/simple for test environments; use a secret manager for production.

apiHost:
  protocol: http
  # Host is left empty so chart will configure service/ingress. For NodePort we've set nodePort below.
  # If you want to set an external host, replace below with that IP or hostname.
  host: ""
  port: 31001

whisk:
  ingress:
    type: NodePort
    # Controller NodePort settings
    apiHostPort: 31001
    port: 31001
  limits:
    # These are sample soft limits for a small dev cluster
    actions: 1000
    triggers: 1000
    rules: 1000
    packages: 100
  containerFactory:
    impl: "kubernetes"

controller:
  # small resources suited for single-node test cluster; increase for production
  resources:
    limits:
      cpu: "2"
      memory: "3Gi"
    requests:
      cpu: "1"
      memory: "2Gi"
  instances: 1
  env:
    CONFIG_whisk_couchdb_username: whisk_admin
    CONFIG_whisk_couchdb_password: mysecretpassword
    CONFIG_whisk_couchdb_protocol: http
    CONFIG_whisk_couchdb_host: owdev-couchdb.openwhisk.svc.cluster.local
    CONFIG_whisk_couchdb_port: "5984"
    CONFIG_whisk_couchdb_database: whisk

couchdb:
  image:
    repository: couchdb
    tag: "3.2.2"
  replicas: 1
  cluster: false
  username: whisk_admin
  password: mysecretpassword

kafka:
  enabled: false
EOF

log "6) Wait until all core system pods are running before installing OpenWhisk"
# Wait for kube-system pods (like kube-proxy, flannel) to be ready
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s || {
  log "Some kube-system pods not Ready after 300s; continuing but OpenWhisk may fail until cluster stabilizes."
}

log "7) Install (or upgrade) OpenWhisk via Helm using our values file"
if helm status "$HELM_RELEASE" -n "$NAMESPACE" &> /dev/null; then
  log "Release $HELM_RELEASE already exists: performing helm upgrade"
  helm upgrade "$HELM_RELEASE" openwhisk/openwhisk -n "$NAMESPACE" -f "$VALUES"
else
  log "Installing $HELM_RELEASE..."
  helm install "$HELM_RELEASE" openwhisk/openwhisk -n "$NAMESPACE" -f "$VALUES"
fi

log "8) Wait for OpenWhisk controller and couchdb pods to become ready (timeout 10m)"
kubectl wait --for=condition=Ready pods -l "app.kubernetes.io/name=controller" -n "$NAMESPACE" --timeout=600s || true
kubectl wait --for=condition=Ready pods -l "app.kubernetes.io/name=couchdb" -n "$NAMESPACE" --timeout=600s || true

log "OpenWhisk helm deployment command sent. Monitor with: kubectl get pods -n $NAMESPACE"
