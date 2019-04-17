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

variable "ucp_ip" {
  description = "IP address of the UCP's load balancer (if omitted we rely on DNS)"
  default = ""
}

variable "ucp_fqdn" {
  description = "Fully qualified domain name for the UCP's load balancer "
}

variable "dtr_ip" {
  description = "IP address of the DTR's load balancer (if omitted we rely on DNS)"
  default = ""
}

variable "dtr_fqdn" {
  description = "Fully qualified domain name to use for the DTR's load balancer"
}

variable "consul_server" {
  description = "Address of a consul server"
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

variable "dtr_s3_access_key" {
  description = "AWS access key for IAM account to use with S3 bucket for DTR storage"
  default = ""
}

variable "dtr_s3_secret_key" {
  description = "AWS secret key for IAM account to use with S3 bucket for DTR storage"
  default = ""
}

variable "use_custom_ssl" {
  description = "1 if using custom SSL certs, 0 if using self-signed certs"
  default = "0"
}

variable "ssl_ca_file" {
  description = "CA PEM"
  default = ""
}

variable "ssl_cert_file" {
  description = "SSL Cert"
  default = ""
}

variable "ssl_key_file" {
  description = "SSL Key"
  default = ""
}

variable "debug_output" {
  description = "Set to 1 to enable debug output, 0 to disable"
  default = "1"
}

variable "verbose_output" {
  description = "Set to 1 to enable verbose output, 0 to disable"
  default = "0"
}
