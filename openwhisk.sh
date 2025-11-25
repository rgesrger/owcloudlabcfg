#!/bin/bash
set -e

echo "--- STARTING APACHE OPENWHISK DEPLOYMENT ---"

# 1. Check for Helm (Required for OpenWhisk installation)
if ! command -v helm &> /dev/null
then
    echo "Helm is not installed. Please install Helm before proceeding."
    echo "Example: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    exit 1
fi

# 2. Add the OpenWhisk Helm chart repository
echo "--- 2. Adding OpenWhisk Helm repository ---"
helm repo add openwhisk https://openwhisk.apache.org/charts
helm repo update

# 3. Create a Kubernetes namespace for the OpenWhisk installation
OW_NAMESPACE="openwhisk"
kubectl create namespace $OW_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 4. Create a custom configuration file (mycluster.yaml)
# This file defines the components (e.g., uses Kubernetes for persistence)
echo "--- 4. Creating Helm configuration file (mycluster.yaml) ---"
cat <<EOF > mycluster.yaml
# Customize configuration here.
# Basic setup using default internal services.
apiHost:
  host: 127.0.0.1
  protocol: http
  port: 31001
whisk:
  ingress:
    type: NodePort # Use NodePort for easy external access from the Control Plane
    apiHostPort: 31001
    port: 31001
  limits:
    actions: 100
    triggers: 100
    rules: 100
    packages: 100
  containerFactory:
    impl: "kubernetes"
db:
  provider: "CouchDB"
invoker:
  options: "-Dopenwhisk.container.factory.impl=kubernetes"
EOF

# 5. Install OpenWhisk using the Helm chart and the custom config
echo "--- 5. Deploying OpenWhisk via Helm (This will take a few minutes) ---"
helm install owdev openwhisk/openwhisk --namespace $OW_NAMESPACE -f mycluster.yaml

echo "--- DEPLOYMENT COMMAND SENT ---"
echo "Run 'kubectl get pods -n $OW_NAMESPACE' to monitor progress."
echo "You must wait until all pods are 'Running' before using OpenWhisk."