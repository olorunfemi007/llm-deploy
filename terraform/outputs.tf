output "control_plane_external_ip" {
  description = "External IP of the control-plane node"
  value       = google_compute_instance.control_plane.network_interface[0].access_config[0].nat_ip
}

output "control_plane_internal_ip" {
  description = "Internal IP of the control-plane node"
  value       = google_compute_instance.control_plane.network_interface[0].network_ip
}

output "worker_external_ips" {
  description = "External IPs of the worker nodes"
  value       = [for w in google_compute_instance.worker : w.network_interface[0].access_config[0].nat_ip]
}

output "worker_internal_ips" {
  description = "Internal IPs of the worker nodes"
  value       = [for w in google_compute_instance.worker : w.network_interface[0].network_ip]
}

output "ssh_control_plane" {
  description = "SSH command for the control-plane node"
  value       = "ssh ${var.ssh_user}@${google_compute_instance.control_plane.network_interface[0].access_config[0].nat_ip}"
}

output "ssh_workers" {
  description = "SSH commands for the worker nodes"
  value       = [for w in google_compute_instance.worker : "ssh ${var.ssh_user}@${w.network_interface[0].access_config[0].nat_ip}"]
}

output "post_deploy_instructions" {
  description = "Steps to complete the cluster setup"
  value       = <<-EOT
    1. SSH into the control-plane: ssh ${var.ssh_user}@<control-plane-ip>
    2. Wait for setup: sudo cloud-init status --wait
    3. Get the join command: sudo cat /root/kubeadm-join-command.sh
    4. SSH into each worker and run the join command as root
    5. Back on control-plane: kubectl get nodes
  EOT
}
