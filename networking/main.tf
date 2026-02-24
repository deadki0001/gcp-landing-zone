# ============================================================================
# NETWORKING HOST PROJECT
# ============================================================================
# This project acts as the central networking hub for the entire landing zone.
# All shared network resources (VPC, subnets, firewall rules) live here.
# Other projects (dev, prod, shared services) connect TO this project's network
# rather than creating their own. This is the GCP Shared VPC pattern.
# It sits inside the Networking folder created by the org module.
resource "google_project" "networking" {
  name            = "networking-host"
  project_id      = "networking-host-lz-001"
  folder_id       = "folders/454974647484"
  billing_account = var.billing_account
}

# ============================================================================
# COMPUTE API
# ============================================================================
resource "google_project_service" "networking_compute" {
  project = google_project.networking.project_id
  service = "compute.googleapis.com"
}

# ============================================================================
# SHARED VPC - HUB NETWORK
# ============================================================================
resource "google_compute_network" "shared_vpc" {
  name                    = "shared-vpc"
  auto_create_subnetworks = false
  project                 = google_project.networking.project_id
  depends_on              = [google_project_service.networking_compute]
}

# ============================================================================
# SUBNETS
# ============================================================================
resource "google_compute_subnetwork" "dev_subnet" {
  name          = "dev-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

resource "google_compute_subnetwork" "prod_subnet" {
  name          = "prod-subnet"
  ip_cidr_range = "10.20.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

resource "google_compute_subnetwork" "shared_subnet" {
  name          = "shared-services-subnet"
  ip_cidr_range = "10.30.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

# ============================================================================
# SHARED VPC HOST PROJECT DESIGNATION
# ============================================================================
resource "google_compute_shared_vpc_host_project" "host" {
  project    = google_project.networking.project_id
  depends_on = [google_project_service.networking_compute]
}

# ============================================================================
# SERVICE NETWORKING API
# ============================================================================
# Required for Cloud SQL private IP peering against the shared VPC
resource "google_project_service" "networking_service_networking" {
  project            = "networking-host-lz-001"
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# ============================================================================
# GKE SHARED VPC PERMISSIONS
# ============================================================================
# When GKE clusters are created in a shared VPC service project, Google's
# GKE robot service account needs permission to configure networking
# on the host project. Without this, cluster creation fails with 403.
#
# service-{PROD_PROJECT_NUMBER}@container-engine-robot.iam.gserviceaccount.com
# is automatically created by GCP when the Container API is enabled.

# Allows the GKE service account to act as a host service agent
# This is the primary permission needed for shared VPC GKE
resource "google_project_iam_member" "gke_host_service_agent" {
  project = google_project.networking.project_id
  role    = "roles/compute.hostServiceAgentUser"
  member  = "serviceAccount:service-973898437899@container-engine-robot.iam.gserviceaccount.com"
}

# Allows the GKE service account to use the shared VPC network and subnets
resource "google_project_iam_member" "gke_network_user" {
  project = google_project.networking.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-973898437899@container-engine-robot.iam.gserviceaccount.com"
}