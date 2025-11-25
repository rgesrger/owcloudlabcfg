#!/bin/bash
# This script is designed to run automatically upon node provisioning in CloudLab
# or a similar environment. It ensures all dependencies and components are set up.
set -e

# --- 0. Install Prerequisite: Helm ---
# Helm is mandatory for deploying OpenWhisk via its charts.
echo "--- INSTALLING HELM (Kubernetes Package Manager) ---"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- 1. Run Kubernetes Control Plane Setup ---
echo "--- RUNNING KUBERNETES CONTROL PLANE SETUP (kubernetes.sh) ---"
# This script handles all system configuration, Kubeadm init, and CNI installation.
/bin/bash kubernetes.sh

# A short delay is added to ensure the CNI is initialized before we try to deploy apps.
echo "--- WAITING 60 SECONDS FOR CNI (Flannel) TO INITIALIZE ---"
sleep 60

# --- 2. Run OpenWhisk Deployment ---
echo "--- RUNNING OPENWHISK DEPLOYMENT (openwhisk.sh) ---"
# This script adds the repository, creates the configuration file, and deploys OpenWhisk.
/bin/bash openwhisk.sh

echo "--- PROFILE SETUP COMPLETE. CLUSTER AND OPENWHISK DEPLOYMENT STARTED. ---"
echo "Check progress with 'kubectl get pods -A' and 'kubectl get pods -n openwhisk'."