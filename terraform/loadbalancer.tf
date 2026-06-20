resource "google_compute_global_address" "llm_lb_ip" {
  name = "llm-lb-ip"
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

resource "google_compute_backend_service" "llm_backend" {
  name                  = "llm-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.llm_health.id]

  backend {
    group           = google_compute_instance_group.llm_workers.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "llm_url_map" {
  name            = "llm-url-map"
  default_service = google_compute_backend_service.llm_backend.id
}

resource "google_compute_managed_ssl_certificate" "llm_cert" {
  name = "llm-cert"

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "llm_https_proxy" {
  name             = "llm-https-proxy"
  url_map          = google_compute_url_map.llm_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.llm_cert.id]
}

resource "google_compute_global_forwarding_rule" "llm_https" {
  name                  = "llm-forwarding-https"
  ip_address            = google_compute_global_address.llm_lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.llm_https_proxy.id
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_url_map" "llm_redirect" {
  name = "llm-http-redirect"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "llm_http_proxy" {
  name    = "llm-http-redirect-proxy"
  url_map = google_compute_url_map.llm_redirect.id
}

resource "google_compute_global_forwarding_rule" "llm_http" {
  name                  = "llm-forwarding-http"
  ip_address            = google_compute_global_address.llm_lb_ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.llm_http_proxy.id
  load_balancing_scheme = "EXTERNAL"
}
