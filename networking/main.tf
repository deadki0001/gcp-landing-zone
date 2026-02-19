# ============================================================================
# NETWORKING HOST PROJECT
# ============================================================================
# This project acts as the central networking hub for the entire landing zone.
# All shared network resources (VPC, subnets, firewall rules) live here.
# Other projects (dev, prod, shared services) connect TO this project's network
# rather than creating their own. This is the GCP Shared VPC pattern.
# It sits inside the Networking folder created by the org module.
resource "google_project" "networking" {
  name            = "networking-host"           # Human-readable name in GCP console
  project_id      = "networking-host-lz-001"    # Globally unique project identifier
  folder_id       = "folders/454974647484"      # Places this inside the Networking folder
  billing_account = var.billing_account         # Links to billing so resources can be created
}

# ============================================================================
# COMPUTE API
# ============================================================================
# Before you can create any networking resources (VPCs, subnets, firewalls),
# the Compute Engine API must be enabled on the project.
# Think of APIs like switches - they must be turned on before the service works.
# All subsequent network resources depend on this being enabled first.
resource "google_project_service" "networking_compute" {
  project = google_project.networking.project_id
  service = "compute.googleapis.com"
}

# ============================================================================
# SHARED VPC - HUB NETWORK
# ============================================================================
# This is the central hub network that all environments connect to.
# auto_create_subnetworks = false means we manually define all subnets below,
# giving us full control over IP ranges and region placement.
# The depends_on ensures the Compute API is enabled before we try to create
# any network resources, avoiding timing errors.
resource "google_compute_network" "shared_vpc" {
  name                    = "shared-vpc"
  auto_create_subnetworks = false
  project                 = google_project.networking.project_id
  depends_on              = [google_project_service.networking_compute]
}

# ============================================================================
# SUBNETS
# ============================================================================
# Each environment gets its own subnet within the shared VPC.
# Using separate IP ranges (10.10, 10.20, 10.30) prevents overlap and makes
# firewall rules and routing easier to manage.
# All subnets are in europe-west1 to keep traffic within the same region.

# Development subnet - used by workloads in the Development folder
# IP range 10.10.0.0/24 gives 254 usable addresses for dev workloads
resource "google_compute_subnetwork" "dev_subnet" {
  name          = "dev-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

# Production subnet - used by workloads in the Production folder
# IP range 10.20.0.0/24 keeps prod traffic isolated from dev
resource "google_compute_subnetwork" "prod_subnet" {
  name          = "prod-subnet"
  ip_cidr_range = "10.20.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.shared_vpc.id
  project       = google_project.networking.project_id
}

# Shared services subnet - used by central tools like logging, monitoring,
# CI/CD agents, and other platform services used across all environments
# IP range 10.30.0.0/24 keeps shared tooling on its own segment
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
# This resource promotes the networking project to a Shared VPC Host Project.
# Once designated as a host, other projects (service projects) can attach to
# this project's VPC and use its subnets without owning the network themselves.
# This is the core of the hub-and-spoke networking model in GCP.
# Example: the dev project will attach here and use dev-subnet above.
resource "google_compute_shared_vpc_host_project" "host" {
  project    = google_project.networking.project_id
  depends_on = [google_project_service.networking_compute]
}