#!/bin/bash
set -euo pipefail

# Single-file Kubernetes control-plane provisioning script.
# Designed for Ubuntu 22.04-ish images (CloudLab).
# It installs containerd, installs kubeadm/kubelet/kubectl, initializes a single-node cluster,
# installs Flannel, sets kubeconfig for the unprivileged user, and allows scheduling pods on the control plane.

POD_CIDR="10.244.0.0/16"
K8S_APT_REPO="https://apt.kubernetes.io/"

# Helper for logging
log() { echo "$(date -Iseconds) $*"; }

log "1) apt update and essential packages"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

log "2) Install containerd"
sudo apt-get install -y containerd

log "3) Configure containerd to use systemd as cgroup driver"
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

log "4) Disable swap (required by kubeadm)"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab || true

log "5) Load kernel modules and sysctl for networking"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay || true
sudo modprobe br_netfilter || true

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

log "6) Install Kubernetes packages (kubeadm, kubelet, kubectl)"
# Add the Kubernetes apt repository
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmour -o /usr/share/keyrings/k8s-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/k8s-archive-keyring.gpg] ${K8S_APT_REPO} kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
# Prevent them from being automatically updated (optional but recommended for kubeadm)
sudo apt-mark hold kubelet kubeadm kubectl

log "7) Initialize Kubernetes control plane with kubeadm"
# kubeadm init will generate admin.conf for root; we copy to the default user below.
sudo kubeadm init --pod-network-cidr="${POD_CIDR}"

log "8) Set up kubeconfig for current (non-root) user"
# kubeadm writes admin.conf to /etc/kubernetes/admin.conf. Copy for the user invoking this script.
USER_HOME="${HOME}"
mkdir -p "${USER_HOME}/.kube"
sudo cp -i /etc/kubernetes/admin.conf "${USER_HOME}/.kube/config"
sudo chown "$(id -u)":"$(id -g)" "${USER_HOME}/.kube/config"

log "9) Install Flannel CNI"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

log "10) Make control-plane schedulable (allow pods to run on single-node cluster)"
# Remove the taint that prevents scheduling on control-plane nodes (k8s v1.24+ uses control-plane taint)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

log "11) Print join command for workers (for reference)"
kubeadm token create --print-join-command || true

log "Kubernetes control-plane initialization finished."
