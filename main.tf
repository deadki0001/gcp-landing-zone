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

# Disabled on free tier - requires additional billing quota
# Uncomment when running on a paid account or after quota increase
# module "security" {
#   source          = "./security"
#   billing_account = var.billing_account
# }