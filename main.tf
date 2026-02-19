provider "google" {
  project = "project-5a757d72-eb26-477c-bd9"
  region  = "europe-west1"
}

module "org" {
  source = "./org"
}

module "networking" {
  source          = "./networking"
  billing_account = var.billing_account
}

module "project_factory" {
  source          = "./project-factory"
  billing_account = var.billing_account
}

module "policies" {
  source          = "./policies"
  billing_account = var.billing_account
}

# Disabled pending billing quota increase
# module "security" {
#   source          = "./security"
#   billing_account = var.billing_account
# }

module "policies" {
  source            = "./policies"
  billing_account   = var.billing_account
  bootstrap_project = "project-5a757d72-eb26-477c-bd9"
}