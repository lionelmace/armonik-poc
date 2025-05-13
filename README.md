# ArmoniK PoC

Terraform scripts to provision the infrastructure to host ArmoniK [solution](https://github.com/aneoconsulting/ArmoniK/) on IBM Cloud.

The scripts will provision

* IBM Cloud Kubernetes (IKS)
* MongoDB
* Cloud Logs
* Monitoring
* Cloud Object Storage

## Terraform Resources

* [IBM Cloud Kubernetes](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/container_vpc_cluster)
* [Cloud Logs and Monitoring](https://github.com/terraform-ibm-modules/terraform-ibm-observability-agents)
* [MongoDB](https://github.com/terraform-ibm-modules/terraform-ibm-icd-mongodb)
* [Cloud Object Storage](https://github.com/terraform-ibm-modules/terraform-ibm-cos)
* [RabbitMQ](https://github.com/terraform-ibm-modules/terraform-ibm-icd-rabbitmq)