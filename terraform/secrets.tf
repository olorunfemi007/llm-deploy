resource "google_secret_manager_secret" "k8s_deployer_kubeconfig" {
  secret_id = "k8s-deployer-kubeconfig"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager]
}
