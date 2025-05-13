##############################################################################
# IBM Cloud Provider
##############################################################################

terraform {
  required_version = ">=1.10"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.78.2"
    }
    http-full = {
      source  = "salrashid123/http-full"
      version = "1.3.1"
    }
  }
}

provider "http-full" {}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.iks_cluster_config.host
  token                  = data.ibm_container_cluster_config.iks_cluster_config.token
  cluster_ca_certificate = base64decode(data.ibm_container_cluster_config.iks_cluster_config.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.ibm_container_cluster_config.iks_cluster_config.host
    token                  = data.ibm_container_cluster_config.iks_cluster_config.token
    cluster_ca_certificate = base64decode(data.ibm_container_cluster_config.iks_cluster_config.ca_certificate)
  }
}

# Init cluster config for helm and kubernetes providers
############################################################################
data "ibm_container_cluster_config" "iks_cluster_config" {
  cluster_name_id   = ibm_container_vpc_cluster.iks_cluster.id
  resource_group_id = ibm_resource_group.group.id
  endpoint_type     = "private"
}
