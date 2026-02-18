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