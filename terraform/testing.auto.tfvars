##############################################################################
## Global Variables
##############################################################################

#region     = "eu-de"     # eu-de for Frankfurt MZR
#icr_region = "de.icr.io"
prefix = "armonik"

##############################################################################
## VPC
##############################################################################
vpc_address_prefix_management = "manual"
vpc_enable_public_gateway     = true


##############################################################################
## Cluster IKS
##############################################################################
# iks_version               = "1.31.1"
iks_worker_nodes_per_zone = 1
iks_machine_flavor        = "bx2.4x16"

# Scale up   by adding a worker pool
# Scale down by setting the number of worker to Zero
create_secondary_iks_pool = false
# Uncomment to create worker pool
iks_worker_pools = [
  {
    pool_name        = "secondary"
    machine_type     = "bx2.4x16"
    workers_per_zone = 0
  }
]

# Possible values: MasterNodeReady, OneWorkerNodeReady, or IngressReady
iks_wait_till          = "IngressReady"
iks_update_all_workers = true
# iks_worker_nodes_per_zone = 2


##############################################################################
## Secrets Manager
##############################################################################
existing_secrets_manager_name = "secrets-manager"

##############################################################################
## COS
##############################################################################
cos_plan   = "standard"
cos_region = "global"


##############################################################################
## Observability: Log Analysis (Mezmo) & Monitoring (Sysdig)
##############################################################################

sysdig_plan                    = "graduated-tier"
sysdig_enable_platform_metrics = true


##############################################################################
## ICD Mongo
##############################################################################
# Available Plans: standard, enterprise
icd_mongo_plan = "standard"
# expected length in the range (10 - 32) - must not contain special characters
icd_mongo_adminpassword     = "AdministratorPassw0rd01"
icd_mongo_db_version        = "6.0"
icd_mongo_service_endpoints = "private"
icd_mongo_use_vpe           = true

# Minimum parameter for Enterprise Edition
# icd_mongo_ram_allocation = 14336
# icd_mongo_disk_allocation = 20480
# icd_mongo_core_allocation = 6

# Minimum parameter for Standard Edition
icd_mongo_ram_allocation  = 4096 # old value: 1024
icd_mongo_disk_allocation = 20480
icd_mongo_core_allocation = 0

icd_mongo_users = [{
  name     = "user123"
  password = "Password12"
}]
