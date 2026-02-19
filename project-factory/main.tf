# ============================================================================
# DEVELOPMENT PROJECT
# ============================================================================
# This project lives in the Development folder and hosts all dev workloads.
# It is a Shared VPC service project, meaning it uses the networking project's
# VPC rather than creating its own network infrastructure.
resource "google_project" "dev" {
  name            = "dev-workloads"
  project_id      = "dev-workloads-lz-001"
  folder_id       = "folders/946065792690"
  billing_account = var.billing_account
}

# Enable compute API so dev workloads can use networking resources
resource "google_project_service" "dev_compute" {
  project = google_project.dev.project_id
  service = "compute.googleapis.com"
}

# Attach dev project to the shared VPC host project
# This allows dev workloads to use subnets from the networking project
resource "google_compute_shared_vpc_service_project" "dev_attachment" {
  host_project    = "networking-host-lz-001"
  service_project = google_project.dev.project_id
  depends_on      = [google_project_service.dev_compute]
}

# ============================================================================
# PRODUCTION PROJECT
# ============================================================================
# Same pattern as dev but sits in the Production folder.
# Kept completely separate from dev for security and billing isolation.
resource "google_project" "prod" {
  name            = "prod-workloads"
  project_id      = "prod-workloads-lz-001"
  folder_id       = "folders/885620268842"
  billing_account = var.billing_account
}

# Enable compute API so prod workloads can use networking resources
resource "google_project_service" "prod_compute" {
  project = google_project.prod.project_id
  service = "compute.googleapis.com"
}

# Attach prod project to the shared VPC host project
resource "google_compute_shared_vpc_service_project" "prod_attachment" {
  host_project    = "networking-host-lz-001"
  service_project = google_project.prod.project_id
  depends_on      = [google_project_service.prod_compute]
}