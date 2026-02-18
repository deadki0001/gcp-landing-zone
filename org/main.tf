resource "google_folder" "security" {
  display_name = "Security"
  parent       = "organizations/704683862745"
}

resource "google_folder" "networking" {
  display_name = "Networking"
  parent       = "organizations/704683862745"
}

resource "google_folder" "shared_services" {
  display_name = "Shared Services"
  parent       = "organizations/704683862745"
}

resource "google_folder" "dev" {
  display_name = "Development"
  parent       = "organizations/704683862745"
}

resource "google_folder" "prod" {
  display_name = "Production"
  parent       = "organizations/704683862745"
}