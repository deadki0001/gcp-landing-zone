variable "bootstrap_project" {}

variable "github_repo" {
  description = "GitHub repo in format deadki0001/gcp-landing-zone"
  type        = string
}

variable "org_id" {
  description = "GCP Organisation ID"
  type        = string
}

variable "billing_account" {
  description = "GCP Billing Account ID"
  type        = string
}