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

resource "google_compute_region_health_check" "llm_health" {
  name               = "llm-health-check"
  region             = var.region
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
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.llm_health.id]

  backend {
    group           = google_compute_instance_group.llm_workers.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "llm_url_map" {
  name            = "llm-url-map"
  region          = var.region
  default_service = google_compute_region_backend_service.llm_backend.id
}

resource "google_compute_region_target_http_proxy" "llm_proxy" {
  name    = "llm-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.llm_url_map.id
}

resource "google_compute_forwarding_rule" "llm_http" {
  name                  = "llm-forwarding-http"
  region                = var.region
  ip_address            = google_compute_address.llm_lb_ip.address
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.llm_proxy.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "STANDARD"
  network               = google_compute_network.k8s_vpc.id

  depends_on = [google_compute_subnetwork.proxy_only]
}
