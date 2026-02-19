# ============================================================================
# CENTRALISED LOGGING PROJECT
# ============================================================================
# All audit logs from all projects flow into this single project.
# This means security teams have one place to look for all activity
# across the entire organisation.
# AWS equivalent: CloudTrail logs centralised into a security account S3 bucket
resource "google_project" "logging" {
  name            = "logging-central"
  project_id      = "logging-central-lz-001"
  folder_id       = "folders/641374221790"   # Sits inside Security folder
  billing_account = var.billing_account
}

# Enable logging API on the logging project
resource "google_project_service" "logging_api" {
  project = google_project.logging.project_id
  service = "logging.googleapis.com"
}

# Enable bigquery API - audit logs will be exported here for analysis
resource "google_project_service" "bigquery_api" {
  project = google_project.logging.project_id
  service = "bigquery.googleapis.com"
}

# ============================================================================
# ORGANISATION-WIDE AUDIT LOG SINK
# ============================================================================
# This captures ALL admin activity across every project in the organisation
# and routes it to the centralised logging project.
# Once set up, even if someone deletes logs in their own project,
# the org-level sink already captured them here.
resource "google_logging_organization_sink" "audit_logs" {
  name             = "org-audit-log-sink"
  org_id           = "704683862745"
  include_children = true   # Captures logs from ALL child projects and folders

  # Send logs to a BigQuery dataset for querying and analysis
  destination = "bigquery.googleapis.com/projects/${google_project.logging.project_id}/datasets/audit_logs"

  # Only capture admin activity and data access logs
  # These are the security-relevant events - who did what, when, from where
  filter = "logName:(activity OR data_access)"

  depends_on = [google_project_service.bigquery_api]
}

# BigQuery dataset to receive the audit logs
resource "google_bigquery_dataset" "audit_logs" {
  dataset_id = "audit_logs"
  project    = google_project.logging.project_id
  location   = "EU"

  # Only the log sink service account can write to this dataset
  # Prevents tampering with audit records
  access {
    role          = "WRITER"
    user_by_email = google_logging_organization_sink.audit_logs.writer_identity
  }
}