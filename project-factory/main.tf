# ============================================================================
# PROJECT FACTORY
# ============================================================================
# These projects reflect the current state in GCP.
# Billing quota increase requested - pending Google approval.
# Once approved, logging and shared services projects will be added.
# Dev and prod projects exist but billing quota prevents additional projects.

# Development workloads project - sits in Development folder
resource "google_project" "dev" {
  name       = "dev-workloads"
  project_id = "dev-workloads-lz-001"
  folder_id  = "folders/946065792690"
  # billing_account omitted - quota exhausted on free tier
}

# resource "google_project_service" "dev_compute" {
#   project = google_project.dev.project_id
#   service = "compute.googleapis.com"
# }

# Production workloads project - sits in Production folder
resource "google_project" "prod" {
  name            = "prod-workloads"
  project_id      = "prod-workloads-lz-001"
  folder_id       = "folders/885620268842"
  billing_account = var.billing_account
}

resource "google_project_service" "prod_compute" {
  project = google_project.prod.project_id
  service = "compute.googleapis.com"
}

# Attach prod to shared VPC
# Dev attachment pending - billing quota exceeded during initial deployment
resource "google_compute_shared_vpc_service_project" "prod_attachment" {
  host_project    = "networking-host-lz-001"
  service_project = google_project.prod.project_id
  depends_on      = [google_project_service.prod_compute]
}