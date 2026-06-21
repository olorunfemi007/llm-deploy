#!/bin/bash
set -euo pipefail

kubeadm reset -f 2>/dev/null || true
rm -rf /etc/kubernetes/pki

echo "Waiting for join command from control-plane..."

for i in $(seq 1 60); do
  if gsutil cp gs://${state_bucket}/k8s/join-command.sh /tmp/join-command.sh 2>/dev/null; then
    echo "Join command received. Joining cluster..."
    bash /tmp/join-command.sh
    rm -f /tmp/join-command.sh
    echo "Successfully joined the cluster."
    exit 0
  fi
  echo "Attempt $i/60: Join command not ready yet. Retrying in 30s..."
  sleep 30
done

echo "Timed out waiting for join command after 30 minutes."
exit 1
