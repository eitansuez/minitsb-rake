terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.69.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_filename)

  project = var.gcp_project_name
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "google_compute_instance" "tsb_vm" {
  name         = "tsb-vm"
  machine_type = "e2-standard-16"

  tags         = ["http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2304-amd64"
      size = 25
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    user-data = file("${path.module}/vm-userdata.tftpl")
  }
}
