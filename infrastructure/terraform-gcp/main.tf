provider "google" {
  credentials = file("account.json")
  project = var.project
  region = var.region
}

resource "google_container_cluster" "cluster" {
  name = "car-demo-cluster"
  location = var.region
  remove_default_node_pool = true
  initial_node_count = 1
  #min_master_version = "latest"
  maintenance_policy {
    daily_maintenance_window {
      start_time = "${var.daily_maintenance_window_start_time}"
    }
  }
  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  /* Calico might be an option for improved ingress performance if we connect MQTT clients from the edge, currently not the case

  network_policy {
    enabled = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }*/
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "car-demo-node-pool"
  location   = var.region
  cluster    = google_container_cluster.cluster.name
  node_count = var.node_count
  #version = "latest"
  node_config {
    // We use preemptible nodes because they're cheap (for testing purposes). Set this to false if you want consistent performance.
    preemptible  = var.preemptible_nodes
    machine_type = "n1-standard-4"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "null_resource" "setup-cluster" {
  depends_on = [
    google_container_cluster.cluster,
    google_container_node_pool.primary_preemptible_nodes
  ]
  triggers = {
    id = google_container_cluster.cluster.id
    reg = var.region
    prj = var.project
    // Re-run script on deployment script changes
    script = sha1(file("00_setup_GKE.sh")) 
  }

  provisioner "local-exec" {
    command = "./00_setup_GKE.sh ${google_container_cluster.cluster.name} ${var.region} ${var.project}"
  }
}