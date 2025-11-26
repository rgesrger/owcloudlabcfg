#!/bin/bash
set -euo pipefail

REPO="/local/repository"
LOG="/local/repository/startup.log"

echo "=== startup.sh: BEGIN ===" | tee -a "$LOG"

# Ensure scripts are executable
chmod +x "$REPO/kubernetes.sh" "$REPO/openwhisk.sh"

# Run Kubernetes control plane setup
echo "--- Running kubernetes.sh ---" | tee -a "$LOG"
sudo bash "$REPO/kubernetes.sh" 2>&1 | tee -a "$LOG"

# Wait for node to be Ready (kubelet/kubeadm set up kubeconfig for the current user in kubernetes.sh)
echo "--- Waiting for Kubernetes node to be Ready ---" | tee -a "$LOG"
# wait up to 10 minutes
kubectl wait --for=condition=Ready node --all --timeout=600s 2>&1 | tee -a "$LOG"

# Run OpenWhisk deployment
echo "--- Running openwhisk.sh ---" | tee -a "$LOG"
bash "$REPO/openwhisk.sh" 2>&1 | tee -a "$LOG"

echo "=== startup.sh: COMPLETE ===" | tee -a "$LOG"
