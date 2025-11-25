#!/bin/bash
set -e

# --- Configuration Variables ---
K8S_VERSION="1.30.0-1"
POD_CIDR="10.244.0.0/16"

echo "--- STARTING KUBERNETES CONTROL PLANE SETUP ---"
echo "--- 1. Configuring Containerd and Services ---"
# 1.1 Generate default containerd config and set cgroup driver to systemd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 1.2 Enable and start services
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl enable --now kubelet

echo "--- 2. System Preparation (Kernel/Swap) ---"
# 2.1 Disable swap permanently (Required by kubeadm)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 2.2 Load kernel modules for networking
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# 2.3 Configure netfilter settings (Allows bridge traffic to be processed by iptables)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "--- 3. Initializing Kubernetes Cluster (kubeadm init) ---"
# This step may take 1-3 minutes
sudo kubeadm init --pod-network-cidr="$POD_CIDR"

echo "--- 4. Setting up Kubectl Access and Installing CNI ---"
# 4.1 Set up local kubectl configuration for the current user
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"

# 4.2 Install the Flannel CNI network plugin
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo ""
echo "========================================================"
echo "    KUBERNETES CONTROL PLANE SETUP COMPLETE"
echo "========================================================"
echo "Run 'kubectl get nodes' in a few minutes to see your node."
echo ""
echo "--- WORKER NODE JOIN COMMAND (SAVE THIS!) ---"
# Print the join command for use on worker nodes
kubeadm token create --print-join-command