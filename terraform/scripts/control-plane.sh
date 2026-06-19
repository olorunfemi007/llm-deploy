#!/bin/bash
set -euo pipefail

apt-get install -y nfs-kernel-server

mkdir -p /srv/nfs/k8s
chown nobody:nogroup /srv/nfs/k8s
chmod 777 /srv/nfs/k8s

echo '/srv/nfs/k8s 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports
exportfs -ra
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=${control_plane_ip} \
  --node-name=$(hostname)

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config


kubectl --kubeconfig=/root/.kube/config apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

JOIN_CMD=$(kubeadm token create --print-join-command)
echo "$JOIN_CMD" > /root/kubeadm-join-command.sh
chmod 600 /root/kubeadm-join-command.sh

gsutil cp /root/kubeadm-join-command.sh gs://${state_bucket}/k8s/join-command.sh
