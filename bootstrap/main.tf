# Configure the Google Cloud Provider
# This tells Terraform which GCP project to use for all resources created in this file
provider "google" {
  project = var.bootstrap_project
}

# ============================================================================
# TERRAFORM STATE STORAGE
# ============================================================================
# This bucket stores the Terraform state file, which tracks all infrastructure
# State files are essential - they map your Terraform code to real GCP resources
# If lost, Terraform won't know what resources it created
resource "google_storage_bucket" "tf_state" {
  name                        = "${var.bootstrap_project}-tf-state"
  location                    = "EU"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# ============================================================================
# TERRAFORM SERVICE ACCOUNT
# ============================================================================
# This is the robot identity that Terraform uses to create and manage
# all infrastructure. Think of it as a dedicated automation user account.
resource "google_service_account" "terraform" {
  account_id   = "terraform-sa"
  display_name = "Terraform Automation"
}

# Grant owner at project level for bootstrap project management
# WARNING: In production this would be tightened to specific roles
resource "google_project_iam_member" "terraform_owner" {
  project = var.bootstrap_project
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# ============================================================================
# GITHUB ACTIONS INTEGRATION (Workload Identity Federation)
# ============================================================================
# Allows GitHub Actions to authenticate to GCP without storing any secret keys.
# GitHub sends a short-lived OIDC token, GCP verifies it and issues temporary
# credentials. This is the enterprise standard for CI/CD authentication.

# Step 1: Create a pool to hold trusted identity providers
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  project                   = var.bootstrap_project
}

# Step 2: Register GitHub as a trusted OIDC provider inside the pool
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  project                            = var.bootstrap_project

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Critical security control - only YOUR repo can authenticate
  # Prevents any other GitHub repo from impersonating your pipeline
  attribute_condition = "assertion.repository == '${var.github_repo}'"
}

# Step 3: Allow GitHub Actions from your repo to impersonate terraform-sa
resource "google_service_account_iam_member" "github_binding" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# ============================================================================
# APIS - ENABLE REQUIRED GOOGLE CLOUD APIS
# ============================================================================
# APIs are like switches - each GCP service must be explicitly enabled
# before Terraform can interact with it

# Billing API - required to link billing accounts to new projects
resource "google_project_service" "billing_api" {
  project = var.bootstrap_project
  service = "cloudbilling.googleapis.com"
}

# Cloud Resource Manager API - required to create and manage projects and folders
resource "google_project_service" "resource_manager_api" {
  project = var.bootstrap_project
  service = "cloudresourcemanager.googleapis.com"
}

# IAM API - required to manage service accounts and permissions
resource "google_project_service" "iam_api" {
  project = var.bootstrap_project
  service = "iam.googleapis.com"
}

# Compute API - required on bootstrap project for Workload Identity operations
resource "google_project_service" "compute_api" {
  project = var.bootstrap_project
  service = "compute.googleapis.com"
}

# ============================================================================
# ORGANIZATION-LEVEL PERMISSIONS
# ============================================================================
# These permissions allow terraform-sa to manage resources across the entire
# GCP organisation, not just within a single project.
# This is what separates bootstrap from all other stages - only bootstrap
# holds these elevated org-wide permissions.

# Create and manage folders (Security, Networking, Dev, Prod etc.)
resource "google_organization_iam_member" "terraform_folder_creator" {
  org_id = var.org_id
  role   = "roles/resourcemanager.folderCreator"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# View the org structure - needed to reference existing folders and projects
resource "google_organization_iam_member" "terraform_org_viewer" {
  org_id = var.org_id
  role   = "roles/resourcemanager.organizationViewer"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# Create new GCP projects - needed for networking, dev, prod projects
resource "google_organization_iam_member" "terraform_project_creator" {
  org_id = var.org_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# Enable Shared VPC host projects - needed to designate networking project
# as the hub that other projects connect their workloads to
resource "google_organization_iam_member" "terraform_xpn_admin" {
  org_id = var.org_id
  role   = "roles/compute.xpnAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# Allow terraform-sa to manage IAM policies on projects it creates
# Needed when attaching service projects to the Shared VPC host
resource "google_organization_iam_member" "terraform_project_iam_admin" {
  org_id = var.org_id
  role   = "roles/resourcemanager.projectIamAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# ============================================================================
# BILLING PERMISSIONS
# ============================================================================
# Allow terraform-sa to link billing accounts to newly created projects
# Without this, new projects cannot create any billable resources
resource "google_billing_account_iam_member" "terraform_billing_user" {
  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.terraform.email}"
}

# Org Policy API - required to create and manage organisation policies
resource "google_project_service" "orgpolicy_api" {
  project = var.bootstrap_project
  service = "orgpolicy.googleapis.com"
}

# Pub/Sub API - required for budget alert notifications
resource "google_project_service" "pubsub_api" {
  project = var.bootstrap_project
  service = "pubsub.googleapis.com"
}

# Billing Budget API - required to create budget alerts
resource "google_project_service" "billing_budget_api" {
  project = var.bootstrap_project
  service = "billingbudgets.googleapis.com"
}

# Allow terraform-sa to create and manage organisation policies
resource "google_organization_iam_member" "terraform_org_policy_admin" {
  org_id = var.org_id
  role   = "roles/orgpolicy.policyAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_organization_iam_member" "terraform_billing_budget_admin" {
  org_id = var.org_id
  role   = "roles/billing.costsManager"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_billing_account_iam_member" "terraform_billing_budget_creator" {
  billing_account_id = var.billing_account
  role               = "roles/billing.admin"
  member             = "serviceAccount:${google_service_account.terraform.email}"
}