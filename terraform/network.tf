resource "google_compute_network" "k8s_vpc" {
  name                    = "k8s-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "k8s_subnet" {
  name          = "k8s-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.k8s_vpc.id
}

resource "google_compute_firewall" "k8s_allow_internal" {
  name    = "k8s-allow-internal"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24", "10.244.0.0/16"]
  target_tags   = ["k8s-node"]
}

resource "google_compute_firewall" "k8s_allow_ssh" {
  name    = "k8s-allow-ssh"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-node"]
}

resource "google_compute_firewall" "k8s_allow_api" {
  name    = "k8s-allow-api"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-control-plane"]
}

resource "google_compute_firewall" "k8s_allow_nodeport" {
  name    = "k8s-allow-nodeport"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["30666"]
  }

  source_ranges = ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  target_tags   = ["k8s-node"]
}

