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
  name     = "${var.bootstrap_project}-tf-state"  # Unique bucket name (must be globally unique)
  location = "EU"                                    # Store data in European region

  # Enforce uniform access control across all objects in this bucket
  uniform_bucket_level_access = true

  # Enable versioning to keep historical backups of state files
  # Useful if you need to recover from accidental changes
  versioning {
    enabled = true
  }
}


# ============================================================================
# TERRAFORM SERVICE ACCOUNT
# ============================================================================
# This is a special GCP account that Terraform will use to create and manage
# infrastructure. Think of it as a user account for automation/tools
resource "google_service_account" "terraform" {
  account_id   = "terraform-sa"                      # Unique ID for this service account
  display_name = "Terraform Automation"              # Human-readable name shown in GCP console
}

# Grant the Terraform service account full owner permissions
# WARNING: Owner role is powerful - it can create/delete almost anything
# In production, consider using more specific roles for security
resource "google_project_iam_member" "terraform_owner" {
  project = var.bootstrap_project
  role    = "roles/owner"                            # This is a very permissive role
  member  = "serviceAccount:${google_service_account.terraform.email}"
}


# ============================================================================
# GITHUB ACTIONS INTEGRATION (Workload Identity)
# ============================================================================
# This section sets up secure authentication between GitHub Actions CI/CD
# and Google Cloud. It uses OpenID Connect (OIDC) for credential-less auth.
# Instead of storing secrets in GitHub, we trust GitHub's identity directly.

# Step 1: Create a Workload Identity Pool
# A pool is a container for identity providers (GitHub, GitLab, etc.)
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  project                   = var.bootstrap_project
}

# Step 2: Configure the OIDC Provider
# This registers GitHub as a trusted identity provider
# Now GitHub Actions workflows can request temporary GCP credentials
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  project                            = var.bootstrap_project

  # Use GitHub's official OIDC endpoint
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Map GitHub token claims to GCP attributes
  # This tells GCP which information from GitHub tokens to trust
  attribute_mapping = {
    "google.subject"       = "assertion.sub"        # GitHub's unique subject identifier
    "attribute.actor"      = "assertion.actor"      # GitHub username
    "attribute.repository" = "assertion.repository" # Repository name
  }

  # Only allow your specific GitHub repository to authenticate
  # This prevents other repos from impersonating your infrastructure
  attribute_condition = "assertion.repository == '${var.github_repo}'"
}

# Step 3: Connect GitHub to the Terraform Service Account
# This allows GitHub Actions to impersonate the Terraform service account
# enabling it to create/manage GCP resources
resource "google_service_account_iam_member" "github_binding" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}


# ============================================================================
# ORGANIZATION-LEVEL PERMISSIONS
# ============================================================================
# These permissions allow Terraform to manage resources across the entire
# Google Cloud Organization (not just a single project)

# Permission 1: Allow Terraform to create new folders
# Folders help organize projects hierarchically within an organization
resource "google_organization_iam_member" "terraform_folder_creator" {
  org_id = var.org_id
  role   = "roles/resourcemanager.folderCreator"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# Permission 2: Allow Terraform to view organization structure
# Needed to discover existing folders and projects in the organization
resource "google_organization_iam_member" "terraform_org_viewer" {
  org_id = var.org_id
  role   = "roles/resourcemanager.organizationViewer"
  member = "serviceAccount:${google_service_account.terraform.email}"
}


# ============================================================================
# BILLING API & PERMISSIONS
# ============================================================================
# These resources enable Terraform to manage billing settings across projects

# Enable the Cloud Billing API on the bootstrap project
# APIs must be enabled before you can use them
resource "google_project_service" "billing_api" {
  project = var.bootstrap_project
  service = "cloudbilling.googleapis.com"  # The billing service
}

# Grant Terraform permission to manage billing accounts
# This allows linking projects to billing accounts and setting budgets
resource "google_billing_account_iam_member" "terraform_billing_user" {
  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.terraform.email}"
}