##############################################################################
# COS Instance with 1 bucket to store your SCC evaluation results
##############################################################################


# COS Variables
##############################################################################
variable "cos_plan" {
  description = "COS plan type"
  type        = string
  default     = "standard"
}

variable "cos_region" {
  description = "Enter Region for provisioning"
  type        = string
  default     = "global"
}

# COS Service for OpenShift Internal Registry
##############################################################################

resource "ibm_resource_instance" "cos-scc" {
  name              = format("%s-%s", local.basename, "cos-scc")
  service           = "cloud-object-storage"
  plan              = var.cos_plan
  location          = var.cos_region
  resource_group_id = ibm_resource_group.group.id
  tags              = var.tags

  parameters = {
    service-endpoints = "private"
  }
}

## COS Bucket
##############################################################################
resource "ibm_cos_bucket" "scc-bucket" {
  bucket_name          = format("%s-%s-%s", local.basename, "scc-bucket", random_string.random.result)
  resource_instance_id = ibm_resource_instance.cos-scc.id
  storage_class        = "smart"

  # SCC Control 2.1.1.2
  # Ensure Cloud Object Storage encryption is enabled with BYOK
  # Key management services can only be added during bucket creation.
  depends_on  = [ibm_iam_authorization_policy.iam-auth-kms-cos]
  kms_key_crn = ibm_kms_key.key.id

  # SCC requires Cross-Region bucket for resiliency
  cross_region_location = "eu"
  # region_location      = "eu-de"

  # Activity Tracked is Deprecated
  # activity_tracking {
  #   read_data_events     = true
  #   write_data_events    = true
  #   activity_tracker_crn = local.activity_tracker_id
  # }
  metrics_monitoring {
    usage_metrics_enabled   = true
    request_metrics_enabled = true
    metrics_monitoring_crn  = module.cloud_monitoring.crn
  }
  endpoint_type = "public"
}


## IAM
##############################################################################

resource "ibm_iam_access_group_policy" "policy-cos" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles           = ["Viewer"]

  resources {
    service           = "cloud-object-storage"
    resource_group_id = ibm_resource_group.group.id
  }
}
