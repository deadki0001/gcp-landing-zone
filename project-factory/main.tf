# ============================================================================
# WORKLOADS PROJECT (Learning Environment - Free Tier)
# ============================================================================
# In a production landing zone this would be two separate projects:
# one for dev (folders/946065792690) and one for prod (folders/885620268842)
# separated for security, billing isolation, and blast radius reduction.
#
# For free tier learning we combine into one project to stay within
# GCP's billing quota limit on free accounts.
# The architecture pattern is identical - only the project count differs.
resource "google_project" "workloads" {
  name            = "workloads"
  project_id      = "workloads-lz-001"
  folder_id       = "folders/946065792690"   # Sits inside the Development folder
  billing_account = var.billing_account
}

# ============================================================================
# COMPUTE API
# ============================================================================
# Must be enabled before the project can interact with any VPC or networking
# resources from the shared VPC host project
resource "google_project_service" "workloads_compute" {
  project = google_project.workloads.project_id
  service = "compute.googleapis.com"
}

# ============================================================================
# SHARED VPC ATTACHMENT
# ============================================================================
# Attaches this workloads project to the networking host project as a
# service project. Once attached, workloads deployed here can use the
# subnets defined in the networking module (dev-subnet, prod-subnet etc.)
# without owning or managing the network themselves.
#
# AWS equivalent: accepting a RAM share from the network account
resource "google_compute_shared_vpc_service_project" "workloads_attachment" {
  host_project    = "networking-host-lz-001"
  service_project = google_project.workloads.project_id
  depends_on      = [google_project_service.workloads_compute]
}