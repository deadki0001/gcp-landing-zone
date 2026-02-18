provider "google" {
  project = var.bootstrap_project
}

resource "google_storage_bucket" "tf_state" {
  name     = "${var.bootstrap_project}-tf-state"
  location = "EU"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}


resource "google_service_account" "terraform" {
  account_id   = "terraform-sa"
  display_name = "Terraform Automation"
}

resource "google_project_iam_member" "terraform_owner" {
  project = var.bootstrap_project
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  project                   = var.bootstrap_project
}

# OIDC Provider inside the pool
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

  attribute_condition = "assertion.repository == '${var.github_repo}'"
}

# Bind GitHub repo to the Terraform service account
resource "google_service_account_iam_member" "github_binding" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}