# Networking host project inside the Networking folder
resource "google_project" "networking" {
  name            = "networking-host"
  project_id      = "networking-host-lz-001"
  folder_id       = "folders/454974647484"
  billing_account = var.billing_account
}

# Enable compute API on the networking project
resource "google_project_service" "networking_compute" {
  project = google_project.networking.project_id
  service = "compute.googleapis.com"
}

# Shared VPC - Hub network
resource "google_compute_network" "shared_vpc" {
  name                    = "shared-vpc"
  auto_create_subnetworks = false
  project                 = google_project.networking.project_id
  depends_on              = [google_project_service.networking_compute]
}

# Dev subnet
resource "google_compute_subnetwork" "dev_subnet" {
  name          = "dev-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

# Production subnet
resource "google_compute_subnetwork" "prod_subnet" {
  name          = "prod-subnet"
  ip_cidr_range = "10.20.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

# Shared services subnet
resource "google_compute_subnetwork" "shared_subnet" {
  name          = "shared-services-subnet"
  ip_cidr_range = "10.30.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

# Make this project the Shared VPC host
resource "google_compute_shared_vpc_host_project" "host" {
  project    = google_project.networking.project_id
  depends_on = [google_project_service.networking_compute]
}