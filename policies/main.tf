# ============================================================================
# ORGANISATION POLICIES
# ============================================================================
# Org policies are guardrails that enforce security rules across ALL folders
# and projects in your organisation. Even if someone has owner access to a
# project, these policies override them.
# AWS equivalent: Service Control Policies (SCPs) in AWS Organizations

# Policy 1: Block public IP addresses on virtual machines
# Prevents accidental exposure of VMs directly to the internet
# All traffic must flow through the shared VPC and firewall rules
resource "google_org_policy_policy" "no_public_ip" {
  name   = "organizations/704683862745/policies/compute.vmExternalIpAccess"
  parent = "organizations/704683862745"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Policy 2: Restrict which regions resources can be created in
# Enforces data residency - keeps all resources in Europe
# Prevents accidental deployment to regions outside your compliance boundary
resource "google_org_policy_policy" "restrict_regions" {
  name   = "organizations/704683862745/policies/gcp.resourceLocations"
  parent = "organizations/704683862745"

  spec {
    rules {
      values {
        allowed_values = [
          "in:europe-locations"
        ]
      }
    }
  }
}

# Policy 3: Disable service account key creation org-wide
# You already saw this policy in action during bootstrap - it blocked key creation
# This is correct behaviour - forces use of Workload Identity Federation instead
# AWS equivalent: SCP blocking IAM access key creation
resource "google_org_policy_policy" "disable_sa_key_creation" {
  name   = "organizations/704683862745/policies/iam.disableServiceAccountKeyCreation"
  parent = "organizations/704683862745"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Policy 4: Require uniform bucket level access on all GCS buckets
# You also saw this policy enforced during bootstrap on your state bucket
# Ensures all storage uses IAM-only access control, no legacy ACLs
resource "google_org_policy_policy" "uniform_bucket_access" {
  name   = "organizations/704683862745/policies/storage.uniformBucketLevelAccess"
  parent = "organizations/704683862745"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}