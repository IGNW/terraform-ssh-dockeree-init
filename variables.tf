variable "node_count" {
  description = "Number of nodes on which to run the init script"
}

variable "node_ips" {
  type = "list"
  description = "List of IPs of hosts to be initialized"
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

variable "ucp_admin_username" {
  description = "User to configure as an admin on ucp"
  default = "ucpadmin"
}

variable "ucp_admin_password" {
  description = "Password to configure for ucp administrator account"
  default = "changeme1"
}

variable "ucp_version" {
  description = "Version of UCP to install"
  default = "3.0.3"
}

variable "minio_endpoint" {
  description = "Required for DTR nodes only"
  default = ""
}

variable "minio_access_key" {
  description = "Required for DTR nodes only"
  default = ""
}

variable minio_secret_key {
  description = "Required for DTR nodes only"
  default = ""
}

variable consul_secret {
  description = "Secret key for encrypting consul communications"
}
