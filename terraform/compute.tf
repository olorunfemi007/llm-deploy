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
      size  = 50
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
      state_bucket     = var.state_bucket
    })
  ])

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance_template" "worker" {
  name_prefix  = "k8s-worker-"
  machine_type = var.machine_type
  region       = var.region

  tags   = ["k8s-node", "k8s-worker"]
  labels = { role = "worker" }

  disk {
    source_image = var.os_image
    disk_size_gb = 20
    disk_type    = "pd-standard"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id

    access_config {}
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = join("\n", [
    file("${path.module}/scripts/common.sh"),
    templatefile("${path.module}/scripts/worker.sh", {
      state_bucket = var.state_bucket
    })
  ])

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "workers" {
  name               = "k8s-workers"
  base_instance_name = "k8s-worker"
  zone               = var.zone

  version {
    instance_template = google_compute_instance_template.worker.id
  }

  named_port {
    name = "http"
    port = 31508
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }
}

resource "google_compute_autoscaler" "workers" {
  name   = "k8s-worker-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.workers.id

  autoscaling_policy {
    min_replicas    = 2
    max_replicas    = 5
    cooldown_period = 120

    metric {
      name   = "compute.googleapis.com/instance/memory/utilization"
      target = 0.5
      type   = "GAUGE"
    }
  }
}


