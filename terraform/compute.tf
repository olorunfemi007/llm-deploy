resource "google_compute_address" "control_plane_internal" {
  name         = "k8s-control-plane-internal"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id
  address_type = "INTERNAL"
  address      = "10.0.0.10"
  region       = var.region
}

resource "google_compute_instance" "control_plane" {
  name         = "k8s-control-plane"
  machine_type = var.machine_type
  zone         = var.zone

  tags   = ["k8s-node", "k8s-control-plane"]
  labels = { role = "control-plane" }

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = google_compute_address.control_plane_internal.address

    access_config {}
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = join("\n", [
    file("${path.module}/scripts/common.sh"),
    templatefile("${path.module}/scripts/control-plane.sh", {
      control_plane_ip = "10.0.0.10"
    })
  ])

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "worker" {
  count = 2

  name         = "k8s-worker-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  tags   = ["k8s-node", "k8s-worker"]
  labels = { role = "worker" }

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id

    access_config {}
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = file("${path.module}/scripts/common.sh")

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}


