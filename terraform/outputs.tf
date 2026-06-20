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
  value       = "gcloud compute ssh k8s-control-plane --zone ${var.zone}"
}

output "ssh_workers" {
  description = "SSH commands for the worker nodes"
  value       = [for i in range(2) : "gcloud compute ssh k8s-worker-${i + 1} --zone ${var.zone}"]
}

output "llm_lb_ip" {
  description = "Static IP of the LLM load balancer"
  value       = google_compute_global_address.llm_lb_ip.address
}

output "llm_endpoint" {
  description = "LLM API endpoint URL"
  value       = "https://${var.domain}"
}

output "dns_record" {
  description = "DNS A record to create for your domain"
  value       = "${var.domain} → ${google_compute_global_address.llm_lb_ip.address}"
}

output "post_deploy_instructions" {
  description = "Steps to complete the cluster setup"
  value       = <<-EOT
    1. SSH into the control-plane: gcloud compute ssh k8s-control-plane --zone ${var.zone}
    2. Wait for setup: sudo cloud-init status --wait
    3. Get the join command: sudo cat /root/kubeadm-join-command.sh
    4. SSH into each worker and run the join command as root
    5. Back on control-plane: kubectl get nodes
  EOT
}
