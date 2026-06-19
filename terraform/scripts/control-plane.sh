#!/bin/bash
set -euo pipefail

kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=${control_plane_ip} \
  --node-name=$(hostname)

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

kubectl --kubeconfig=/root/.kube/config apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

kubeadm token create --print-join-command > /root/kubeadm-join-command.sh
chmod 600 /root/kubeadm-join-command.sh
