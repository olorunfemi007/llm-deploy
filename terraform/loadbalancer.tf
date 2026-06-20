resource "google_compute_global_address" "llm_lb_ip" {
  name = "llm-lb-ip"
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
    group           = google_compute_instance_group_manager.workers.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "llm_url_map" {
  name            = "llm-url-map"
  default_service = google_compute_backend_service.llm_backend.id
}

# --- HTTP-only (when TLS is disabled) ---

resource "google_compute_target_http_proxy" "llm_http_direct" {
  count   = var.enable_tls ? 0 : 1
  name    = "llm-http-proxy"
  url_map = google_compute_url_map.llm_url_map.id
}

resource "google_compute_global_forwarding_rule" "llm_http_direct" {
  count                 = var.enable_tls ? 0 : 1
  name                  = "llm-forwarding-http"
  ip_address            = google_compute_global_address.llm_lb_ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.llm_http_direct[0].id
  load_balancing_scheme = "EXTERNAL"
}

# --- HTTPS + redirect (when TLS is enabled) ---

resource "google_compute_managed_ssl_certificate" "llm_cert" {
  count = var.enable_tls ? 1 : 0
  name  = "llm-cert"

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "llm_https_proxy" {
  count            = var.enable_tls ? 1 : 0
  name             = "llm-https-proxy"
  url_map          = google_compute_url_map.llm_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.llm_cert[0].id]
}

resource "google_compute_global_forwarding_rule" "llm_https" {
  count                 = var.enable_tls ? 1 : 0
  name                  = "llm-forwarding-https"
  ip_address            = google_compute_global_address.llm_lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.llm_https_proxy[0].id
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_url_map" "llm_redirect" {
  count = var.enable_tls ? 1 : 0
  name  = "llm-http-redirect"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "llm_http_redirect" {
  count   = var.enable_tls ? 1 : 0
  name    = "llm-http-redirect-proxy"
  url_map = google_compute_url_map.llm_redirect[0].id
}

resource "google_compute_global_forwarding_rule" "llm_http_redirect" {
  count                 = var.enable_tls ? 1 : 0
  name                  = "llm-forwarding-http"
  ip_address            = google_compute_global_address.llm_lb_ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.llm_http_redirect[0].id
  load_balancing_scheme = "EXTERNAL"
}
