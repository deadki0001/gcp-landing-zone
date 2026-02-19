# ============================================================================
# PUB/SUB TOPIC FOR BUDGET NOTIFICATIONS
# ============================================================================
# Budget alerts need somewhere to send notifications.
# Pub/Sub is GCP's messaging service - think of it like SNS in AWS.
# The budget publishes a message here when thresholds are hit.
# You can subscribe to this topic via email, webhook, or Cloud Function.
resource "google_pubsub_topic" "budget_alerts" {
  name    = "billing-budget-alerts"
  project = var.bootstrap_project
}

# ============================================================================
# BUDGET ALERTS
# ============================================================================
# Sends notifications to Pub/Sub when spending approaches thresholds.
# AWS equivalent: AWS Budgets with SNS notifications
resource "google_billing_budget" "org_budget" {
  billing_account = var.billing_account
  display_name    = "Landing Zone Monthly Budget"

  # Watch all projects linked to this billing account
  budget_filter {
    projects = []
  }

  # Monthly limit of $50
  amount {
    specified_amount {
      currency_code = "USD"
      units         = "50"
    }
  }

  # Alert at 50%, 90%, and 100% of budget
  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  # Send alerts to the Pub/Sub topic above
  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    disable_default_iam_recipients   = false
  }
}