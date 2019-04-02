variable "node_count" {
  description = "Number of nodes on which to run the init script"
}

variable "public_ips" {
  type = "list"
  description = "List of public IPs to use for SSH"
}

variable "private_ips" {
  type = "list"
  description = "List of IPs nodes should use to talk to one another"
}

variable "resource_ids" {
  type = "list"
  description = "Array of resource IDs of the nodes to be initialized"
}

variable "node_type" {
  description = "One of: mgr, wrk, dtr"
}

variable "ucp_url" {
  description = "URL where we can reach the UCP"
}

variable "dtr_url" {
  description = "URL where we can reach the DTR"
}

variable "ssh_username" {
  description = "Username for connecting via ssh"
}

variable "ssh_password" {
  description = "Password for connecting via ssh (leave blank if using a private key)"
  default = ""
}

variable "private_key" {
  description = "Private key for connecting via ssh (leave blank if using a password)"
  default = ""
}

variable "bastion_host" {
  description = "Host to use as a bastion host for SSH connection - for when target host has no public IP"
  default = ""
}

variable "ucp_admin_username" {
  description = "User to configure as an admin on ucp"
  default = "ucpadmin"
}

variable "ucp_admin_password" {
  description = "Password to configure for ucp administrator account"
  default = "upcw123!"
}

variable "ucp_version" {
  description = "Version of UCP to install"
  default = "3.0.3"
}

variable "dtr_version" {
  description = "Version of DTR to install"
  default = "2.6.2"
}

variable "consul_version" {
  description = "Version of Consul to install"
  default = "1.4.2"
}

variable manager_ip {
  description = "IP address of a manager node for cluster join operations"
}

variable consul_secret {
  description = "Secret key for encrypting consul communications"
}

variable run_init {
  description = "Optional argument - set to 0 to upload but not run init scripts"
  default = "1"
}

variable dockeree_license {
  description = "Docker Enterprise Edition license"
  default = ""
}

variable script_path {
  description = "Path on VM where we will upload and execute inline exec scripts"
  default = "/tmp"
}

variable "dtr_nfs_url" {
  description = "URL of a nfs share to use for DTR storage"
  default = ""
}

variable "dtr_storage_type" {
  description = "Type of DTR storage - one of nfs, s3"
  default = "volume"
}

variable "dtr_s3_bucket" {
  description = "Name of the S3 bucket to use for DTR storage"
  default = ""
}

variable "dtr_s3_region" {
  description = "Region in which S3 bucket is located"
  default = ""
}
