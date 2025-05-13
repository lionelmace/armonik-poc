
##############################################################################
# Cloud Logs Services
##############################################################################


# Cloud Logs Instance
##############################################################################

resource "ibm_resource_instance" "logs_instance" {
  resource_group_id = ibm_resource_group.group.id
  name              = format("%s-%s", local.basename, "cloud-logs")
  service           = "logs"
  plan              = "standard"
  location          = var.region
  tags              = var.tags
  service_endpoints = "private"

  parameters = {
    logs_bucket_crn         = ibm_cos_bucket.logs-bucket-data.crn
    logs_bucket_endpoint    = ibm_cos_bucket.logs-bucket-data.s3_endpoint_direct
    metrics_bucket_crn      = ibm_cos_bucket.logs-bucket-metrics.crn
    metrics_bucket_endpoint = ibm_cos_bucket.logs-bucket-metrics.s3_endpoint_direct
    retention_period        = 7
  }
  depends_on = [ibm_iam_authorization_policy.cloud-logs-cos]
}

# Cloud Logs Routing
# When you configure a target, you are defining the destination where you plan 
# to send platform metrics that are collected in a region in your account.
##############################################################################
resource "ibm_logs_router_tenant" "logs_router_tenant_instance" {
  name   = format("%s-%s", local.basename, "cloud-logs-router")
  region = var.region
  targets {
    log_sink_crn = ibm_resource_instance.logs_instance.id
    name         = "my-cloud-logs-target"
    parameters {
      # host = ibm_resource_instance.logs_instance.extensions.external_ingress
      # When connecting to a private endpoint using a VPE, use port 443.
      # When connecting to a private endpoint using a CSE, use port 3443.
      host = ibm_resource_instance.logs_instance.extensions.external_ingress_private
      port = 3443
    }
  }
}
