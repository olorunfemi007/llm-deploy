#!/bin/bash
set -euo pipefail

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
