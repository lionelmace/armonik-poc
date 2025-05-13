
##############################################################################
# Monitoring Services
##############################################################################


# Monitoring Variables
##############################################################################
variable "sysdig_plan" {
  description = "plan type"
  type        = string
  default     = "graduated-tier"
  # default     = "graduated-tier-sysdig-secure-plus-monitor"
}

variable "sysdig_service_endpoints" {
  description = "Only allow the value public-and-private. Previously it incorrectly allowed values of public and private however it is not possible to create public only or private only Cloud Monitoring instances."
  type        = string
  default     = "public-and-private"
}

variable "sysdig_private_endpoint" {
  description = "Add this option to connect to your Sysdig service instance through the private service endpoint"
  type        = bool
  default     = true
}

variable "sysdig_enable_platform_metrics" {
  type        = bool
  description = "Receive platform metrics in Sysdig"
  default     = false
}

variable "sysdig_use_vpe" {
  default = true
}


# Monitoring Resource
##############################################################################

module "cloud_monitoring" {
  source = "terraform-ibm-modules/observability-instances/ibm//modules/cloud_monitoring"
  # version = "latest" # Replace "latest" with a release version to lock into a specific release

  resource_group_id       = ibm_resource_group.group.id
  instance_name           = format("%s-%s", local.basename, "monitoring")
  plan                    = var.sysdig_plan
  service_endpoints       = var.sysdig_service_endpoints
  enable_platform_metrics = var.sysdig_enable_platform_metrics
  region                  = var.region
  tags                    = var.tags
  manager_key_tags        = var.tags
}

output "cloud_monitoring_crn" {
  description = "The CRN of the Cloud Monitoring instance"
  value       = module.cloud_monitoring.crn
}

########################################################################################################################
# SCC WP (Workload Protection)
########################################################################################################################

# Create SCC Workload Protection instance
module "scc_wp" {
  source                        = "terraform-ibm-modules/scc-workload-protection/ibm"
  # version = "latest" # Replace "latest" with a release version to lock into a specific release
  name                          = format("%s-%s", local.basename, "workload-protection")
  region                        = var.region
  resource_group_id             = ibm_resource_group.group.id
  resource_tags                 = var.tags
  cloud_monitoring_instance_crn = module.cloud_monitoring.crn
  scc_wp_service_plan           = var.sysdig_plan
}

# Create Trusted profile for SCC Workload Protection instance
module "trusted_profile_scc_wp" {
  source                      = "terraform-ibm-modules/trusted-profile/ibm"
  version                     = "2.1.0"
  trusted_profile_name        = "${var.prefix}-scc-wp-profile"
  trusted_profile_description = "Trusted Profile for SCC-WP to access App Config and enterprise"

  trusted_profile_identity = {
    identifier    = module.scc_wp.crn
    identity_type = "crn"
    type          = "crn"
  }

  trusted_profile_policies = [
    {
      roles = ["Viewer", "Service Configuration Reader", "Manager"]
      resources = [{
        service = "apprapp"
      }]
      description = "App Config access"
    }
    # ,
    # {
    #   roles = ["Viewer", "Usage Report Viewer"]
    #   resources = [{
    #     service = "enterprise"
    #   }]
    #   description = "Enterprise access"
    # }
  ]

  trusted_profile_links = [{
    cr_type = "VSI"
    links = [{
      crn = module.scc_wp.crn
    }]
  }]
}

########################################################################################################################
# SCC WP (Workload Protection) agents
########################################################################################################################

# Deploy SCC Workload Protection agent to the cluster
module "scc_wp_agent" {
  source             = "terraform-ibm-modules/scc-workload-protection-agent/ibm"
  # version = "latest" # Replace "latest" with a release version to lock into a specific release
  access_key         = module.scc_wp.access_key
  cluster_name       = ibm_container_vpc_cluster.iks_cluster.name
  region             = var.region
  endpoint_type      = "private"
  name               = format("%s-%s", local.basename, "wp-agent")
}

########################################################################################################################
# App Configuration
########################################################################################################################

# Create App Config instance
# BUG: does not support region eu-de
# module "app_config" {
#   source            = "terraform-ibm-modules/app-configuration/ibm"
#   version           = "1.3.0"
#   region            = var.region
#   resource_group_id = ibm_resource_group.group.id
#   app_config_name   = format("%s-%s", local.basename, "app-configuration")
#   app_config_tags   = var.tags
# }

resource "ibm_resource_instance" "app_config" {
  resource_group_id = ibm_resource_group.group.id
  name              = format("%s-%s", local.basename, "app-configuration")
  service           = "apprapp"
  plan              = "standardv2"
  location          = var.region
  tags              = var.tags
}

# Create trusted profile for App Config instance
module "trusted_profile_app_config_general" {
  source                      = "terraform-ibm-modules/trusted-profile/ibm"
  version                     = "2.1.0"
  trusted_profile_name        = "${var.prefix}-app-config-general-profile"
  trusted_profile_description = "Trusted Profile for App Config general permissions"

  trusted_profile_identity = {
    # identifier    = module.app_config.app_config_crn
    identifier    = ibm_resource_instance.app_config.crn
    identity_type = "crn"
    type          = "crn"
  }

  trusted_profile_policies = [
    {
      roles              = ["Viewer", "Service Configuration Reader"]
      account_management = true
      description        = "All Account Management Services"
    },
    {
      roles = ["Viewer", "Service Configuration Reader", "Reader"]
      resource_attributes = [{
        name     = "serviceType"
        value    = "service"
        operator = "stringEquals"
      }]
      description = "All Identity and Access enabled services"
    }
  ]

  trusted_profile_links = [{
    cr_type = "VSI"
    links = [{
      # crn = module.app_config.app_config_crn
      crn = ibm_resource_instance.app_config.crn
    }]
  }]
}

# Enable the config aggregator
resource "ibm_config_aggregator_settings" "scc_wp_aggregator" {
  # instance_id                 = module.app_config.app_config_guid
  instance_id                 = ibm_resource_instance.app_config.guid
  region                      = var.region
  resource_collection_enabled = true
  resource_collection_regions = ["all"]
  trusted_profile_id          = module.trusted_profile_app_config_general.profile_id

  # Enables resource collection for Enterprise acccounts
  # additional_scope {
  #   type          = "Enterprise"
  #   enterprise_id = var.enterprise_id

  #   profile_template {
  #     id                 = module.trusted_profile_template.trusted_profile_template_id
  #     trusted_profile_id = module.trusted_profile_app_config_enterprise.profile_id
  #   }
  # }
}

# VPE (Virtual Private Endpoint) for Monitoring
##############################################################################
# resource "ibm_is_virtual_endpoint_gateway" "vpe_monitoring" {
#   for_each = { for target in local.endpoints : target.name => target if tobool(var.sysdig_use_vpe) }

#   name           = "${local.basename}-monitoring-vpe"
#   resource_group = ibm_resource_group.group.id
#   vpc            = ibm_is_vpc.vpc.id

#   target {
#     crn           = module.cloud_monitoring.crn
#     resource_type = "provider_cloud_service"
#   }

#   # one Reserved IP for per zone in the VPC
#   dynamic "ips" {
#     for_each = { for subnet in ibm_is_subnet.subnet : subnet.id => subnet }
#     content {
#       subnet = ips.key
#       name   = "${ips.value.name}-ip-monitoring"
#     }
#   }
#   tags = var.tags
# }

# Metrics Target
# A route defines the rules that indicate what metrics are routed in a region 
# and where to store them
##############################################################################
resource "ibm_metrics_router_target" "metrics_router_target" {
  destination_crn = module.cloud_monitoring.crn
  name            = format("%s-%s", local.basename, "metric-target")
  region          = var.region
}

# Set the default target for the metrics router
resource "ibm_metrics_router_settings" "metrics_router_settings_instance" {
  default_targets {
    id = ibm_metrics_router_target.metrics_router_target.id
  }
  permitted_target_regions  = [var.region]
  primary_metadata_region   = var.region
  backup_metadata_region    = "eu-es"
  private_api_endpoint_only = false
}

# Metrics Route
# A route defines the rules that indicate what metrics are routed in a region 
# and where to store them
##############################################################################
resource "ibm_metrics_router_route" "metrics_route_eu_de" {
  name = format("%s-%s", local.basename, "route-to-de")
  rules {
    action = "send"
    targets {
      id = ibm_metrics_router_target.metrics_router_target.id
    }
    inclusion_filters {
      operand  = "location"
      operator = "is"
      values   = [var.region]
    }
  }
}

## IAM
##############################################################################

resource "ibm_iam_access_group_policy" "iam-sysdig" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles           = ["Writer", "Editor"]

  resources {
    service           = "sysdig-monitor"
    resource_group_id = ibm_resource_group.group.id
  }
}
