resource "google_compute_address" "llm_lb_ip" {
  name   = "llm-lb-ip"
  region = var.region
}

resource "google_compute_http_health_check" "llm_health" {
  name               = "llm-health-check"
  port               = 30552
  request_path       = "/health"
  check_interval_sec = 10
  timeout_sec        = 5
}

resource "google_compute_target_pool" "llm_pool" {
  name          = "llm-target-pool"
  region        = var.region
  instances     = [for w in google_compute_instance.worker : w.self_link]
  health_checks = [google_compute_http_health_check.llm_health.self_link]
}

resource "google_compute_forwarding_rule" "llm_http" {
  name                  = "llm-forwarding-http"
  region                = var.region
  ip_address            = google_compute_address.llm_lb_ip.address
  port_range            = "80"
  target                = google_compute_target_pool.llm_pool.self_link
  load_balancing_scheme = "EXTERNAL"
}
