output "control_plane_external_ip" {
  description = "External IP of the control-plane node"
  value       = google_compute_instance.control_plane.network_interface[0].access_config[0].nat_ip
}

output "control_plane_internal_ip" {
  description = "Internal IP of the control-plane node"
  value       = google_compute_instance.control_plane.network_interface[0].network_ip
}

output "worker_instance_group" {
  description = "Worker managed instance group"
  value       = google_compute_instance_group_manager.workers.instance_group
}

output "ssh_control_plane" {
  description = "SSH command for the control-plane node"
  value       = "gcloud compute ssh k8s-control-plane --zone ${var.zone}"
}

output "ssh_workers" {
  description = "SSH into a worker node"
  value       = "gcloud compute instance-groups managed list-instances k8s-workers --zone ${var.zone}"
}

output "llm_lb_ip" {
  description = "Static IP of the LLM load balancer"
  value       = google_compute_global_address.llm_lb_ip.address
}

output "llm_endpoint" {
  description = "LLM API endpoint URL"
  value       = var.enable_tls ? "https://${var.domain}" : "http://${google_compute_global_address.llm_lb_ip.address}"
}

output "dns_record" {
  description = "DNS A record to create for your domain"
  value       = var.enable_tls ? "${var.domain} → ${google_compute_global_address.llm_lb_ip.address}" : "TLS disabled — point DNS when ready and set enable_tls=true"
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
