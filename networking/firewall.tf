# ============================================================================
# FIREWALL RULES
# ============================================================================
# Firewall rules control what traffic is allowed in and out of the shared VPC.
# These apply at the network level, protecting all projects attached as
# service projects regardless of what they deploy.
# AWS equivalent: Security Groups and Network ACLs on a shared VPC

# Block all ingress traffic by default
# Everything is denied unless explicitly allowed below
# This is a zero-trust starting position
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "deny-all-ingress"
  network  = google_compute_network.shared_vpc.id
  project  = google_project.networking.project_id
  priority = 65534    # Lower priority than specific allow rules

  direction = "INGRESS"

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow internal traffic between subnets within the shared VPC
# Dev, prod, and shared services can communicate with each other
# In a stricter setup you would block dev-to-prod traffic here
resource "google_compute_firewall" "allow_internal" {
  name     = "allow-internal"
  network  = google_compute_network.shared_vpc.id
  project  = google_project.networking.project_id
  priority = 1000

  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"   # Allows ping between internal resources
  }

  # Only allow traffic from within the RFC1918 private IP ranges
  # These are the CIDR ranges used by your subnets (10.10, 10.20, 10.30)
  source_ranges = ["10.0.0.0/8"]
}

# Allow SSH from within the internal network only
# Prevents direct SSH from the internet while allowing internal access
resource "google_compute_firewall" "allow_ssh_internal" {
  name     = "allow-ssh-internal"
  network  = google_compute_network.shared_vpc.id
  project  = google_project.networking.project_id
  priority = 1000

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.0.0.0/8"]
}