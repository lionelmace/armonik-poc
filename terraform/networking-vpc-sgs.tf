# Security Groups
##############################################################################

# Allow incoming ICMP packets (Ping)
##############################################################################
resource "ibm_is_security_group_rule" "sg-rule-inbound-icmp" {
  group     = ibm_is_vpc.vpc.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"

  icmp {
    type = 8
  }
}

# Rules required to allow necessary inbound traffic to your cluster (IKS/OCP)
##############################################################################
# To expose apps by using load balancers or Ingress, allow traffic through VPC 
# load balancers. For example, for Ingress listening on TCP/443
resource "ibm_is_security_group_rule" "sg-rule-inbound-https" {
  group     = ibm_is_vpc.vpc.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

# SSH Inbound Rule
##############################################################################
resource "ibm_is_security_group_rule" "sg-rule-inbound-ssh" {
  group     = ibm_is_vpc.vpc.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# CIS Cloudflare IPs
# Source: # https://api.cis.cloud.ibm.com/v1/ips
# variable "cis_ipv4_cidrs" {
#   description = "List of CIS Cloudflare IPv4 IPs"
#   default = [
#     "173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22",
#     "103.31.4.0/22", "141.101.64.0/18", "108.162.192.0/18",
#     "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22",
#     "198.41.128.0/17", "162.158.0.0/15", "104.16.0.0/13",
#   "104.24.0.0/14", "172.64.0.0/13", "131.0.72.0/22"]
# }
# Use of this datasource to dynamically retrieve the IP above.
##############################################################################
data "ibm_cis_ip_addresses" "ip_addresses" {
}

resource "ibm_is_security_group" "sg-cis-cloudflare" {
  name           = format("%s-%s", local.basename, "sg-cis-ips")
  vpc            = ibm_is_vpc.vpc.id
  resource_group = ibm_resource_group.group.id
  tags           = var.tags
}

resource "ibm_is_security_group_rule" "sg-rule-inbound-cloudflare-ipv4" {
  group     = ibm_is_security_group.sg-cis-cloudflare.id
  count     = length(data.ibm_cis_ip_addresses.ip_addresses.ipv4_cidrs)
  direction = "inbound"
  remote    = element(data.ibm_cis_ip_addresses.ip_addresses.ipv4_cidrs, count.index)
  # remote    = data.ibm_cis_ip_addresses.ip_addresses.ipv4_cidrs[count.index]
  tcp {
    port_min = 443
    port_max = 443
  }
}

##############################################################################

resource "ibm_is_security_group" "kube-master-outbound" {
  name           = format("%s-%s", local.basename, "kube-master-outbound")
  vpc            = ibm_is_vpc.vpc.id
  resource_group = ibm_resource_group.group.id
  tags           = var.tags
}

resource "ibm_is_security_group_rule" "sg-rule-kube-master-tcp-outbound" {
  group     = ibm_is_security_group.kube-master-outbound.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 30000
    port_max = 32767
  }
}
resource "ibm_is_security_group_rule" "sg-rule-kube-master-udp-outbound" {
  group     = ibm_is_security_group.kube-master-outbound.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  udp {
    port_min = 30000
    port_max = 32767
  }
}

##############################################################################
# New Outbound security group rules to add for version 4.14 or later
# Source: https://cloud.ibm.com/docs/openshift?topic=openshift-vpc-security-group&interface=ui#rules-sg-128
resource "ibm_is_security_group" "sg-cluster-outbound" {
  name           = format("%s-%s", local.basename, "kube-outbound-sg")
  vpc            = ibm_is_vpc.vpc.id
  resource_group = ibm_resource_group.group.id
  tags           = var.tags
}

resource "ibm_is_security_group_rule" "sg-rule-outbound-addprefix-443" {
  group     = ibm_is_security_group.sg-cluster-outbound.id
  count     = length(var.vpc_cidr_blocks)
  direction = "outbound"
  remote    = element(var.vpc_cidr_blocks, count.index)
  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "sg-rule-outbound-addprefix-4443" {
  group     = ibm_is_security_group.sg-cluster-outbound.id
  count     = length(var.vpc_cidr_blocks)
  direction = "outbound"
  remote    = element(var.vpc_cidr_blocks, count.index)
  tcp {
    port_min = 4443
    port_max = 4443
  }
}

# New custom Security Group for VPC LB
# Usecase: allow IP filtering
##############################################################################
resource "ibm_is_security_group" "custom-sg-for-lb" {
  name           = format("%s-%s", local.basename, "custom-sg-for-lb")
  vpc            = ibm_is_vpc.vpc.id
  resource_group = ibm_resource_group.group.id
  tags           = var.tags
}

resource "ibm_is_security_group_rule" "sg-rule-inbound-home" {
  group     = ibm_is_security_group.custom-sg-for-lb.id
  direction = "inbound"
  remote    = "2.15.18.161"
}