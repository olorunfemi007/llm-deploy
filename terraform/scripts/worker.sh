#!/bin/bash
# Worker nodes require the join command from the control-plane.
# After deployment:
#   1. SSH to control-plane: sudo cat /root/kubeadm-join-command.sh
#   2. SSH to this worker and run that command as root
echo "Worker node ready. Waiting for kubeadm join command from control-plane."
