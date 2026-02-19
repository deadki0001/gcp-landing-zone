# ============================================================================
# BUDGET ALERTS
# ============================================================================
# Sends email notifications when spending approaches or exceeds thresholds.
# This is critical on a free tier account to avoid unexpected charges.
# AWS equivalent: AWS Budgets with SNS notifications

resource "google_billing_budget" "org_budget" {
  billing_account = var.billing_account
  display_name    = "Landing Zone Monthly Budget"

  # Watch all projects linked to this billing account
  budget_filter {
    projects = []
  }

  # Set monthly limit at $50
  amount {
    specified_amount {
      currency_code = "USD"
      units         = "50"
    }
  }

  # Alert at 50% ($25), 90% ($45), and 100% ($50) of budget
  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  # Notify billing account administrators automatically
  # No additional configuration needed - GCP handles recipient lookup
  all_updates_rule {
    disable_default_iam_recipients = false
  }
}