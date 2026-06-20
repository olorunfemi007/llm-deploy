resource "google_compute_address" "llm_lb_ip" {
  name   = "llm-lb-ip"
  region = var.region
}

resource "google_compute_instance_group" "llm_workers" {
  name    = "llm-worker-group"
  zone    = var.zone
  network = google_compute_network.k8s_vpc.id

  instances = [for w in google_compute_instance.worker : w.self_link]

  named_port {
    name = "http"
    port = 30552
  }
}

resource "google_compute_health_check" "llm_health" {
  name               = "llm-health-check"
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = 30552
    request_path = "/health"
  }
}

resource "google_compute_region_backend_service" "llm_backend" {
  name                  = "llm-backend-service"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.llm_health.id]

  backend {
    group          = google_compute_instance_group.llm_workers.self_link
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_forwarding_rule" "llm_http" {
  name                  = "llm-forwarding-http"
  region                = var.region
  ip_address            = google_compute_address.llm_lb_ip.address
  port_range            = "80"
  backend_service       = google_compute_region_backend_service.llm_backend.id
  load_balancing_scheme = "EXTERNAL"
}
