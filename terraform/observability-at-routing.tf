
# Activity Tracker Event Routing and Targets
##############################################################################

resource "ibm_atracker_route" "atracker_route_de" {
  name = format("%s-%s", local.basename, "at-route")
  rules {
    target_ids = [ibm_atracker_target.at_logs_target.id]
    locations  = [var.region, "global"]
  }
  lifecycle {
    # Recommended to ensure that if a target ID is removed here and destroyed in a plan, this is updated first
    create_before_destroy = true
  }
  depends_on = [ibm_iam_authorization_policy.iam-auth-atracker-2-logs]
}

resource "ibm_atracker_target" "at_logs_target" {
  cloudlogs_endpoint {
    target_crn = ibm_resource_instance.logs_instance.id
  }
  name        = format("%s-%s", local.basename, "at-target-logs")
  target_type = "cloud_logs"
  region      = var.region
  depends_on = [ibm_iam_authorization_policy.iam-auth-atracker-2-logs]
}

resource "ibm_atracker_settings" "atracker_settings" {
  default_targets           = [ibm_atracker_target.at_logs_target.id]
  metadata_region_primary   = var.region
  metadata_region_backup    = "eu-es"
  permitted_target_regions  = ["eu-de", "eu-es", "eu-gb"]
  private_api_endpoint_only = false
  # Optional but recommended lifecycle flag to ensure target delete order is correct
  lifecycle {
    create_before_destroy = true
  }
}
