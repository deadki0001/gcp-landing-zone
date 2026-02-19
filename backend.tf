terraform {
  backend "gcs" {
    bucket = "project-5a757d72-eb26-477c-bd9-tf-state"
    prefix = "landing-zone"
  }
}