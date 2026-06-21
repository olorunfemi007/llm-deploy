#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
KUBE_VERSION="1.29"

swapoff -a
sed -i '/\sswap\s/d' /etc/fstab

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

curl -fsSL https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.1.22/docker-credential-gcr_linux_amd64-2.1.22.tar.gz | tar xz -C /usr/local/bin/
cat >> /etc/containerd/config.toml << 'CREDEOF'

[plugins."io.containerd.grpc.v1.cri".registry.configs."us-central1-docker.pkg.dev".auth]
  username = "_dcgcr"
  password_command = "/usr/local/bin/docker-credential-gcr get"
CREDEOF

systemctl restart containerd
systemctl enable containerd

curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

apt-get update
apt-get install -y kubelet kubeadm kubectl nfs-common
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
