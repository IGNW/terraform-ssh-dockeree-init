resource "random_id" "consul_secret" {
  byte_length = 16
}

data "template_file" "swarm_init" {
  template = "${file("${path.module}/scripts/swarm_init.tpl.sh")}"

  vars {
    node_type           = "${var.node_type}"
    ucp_ip              = "${var.ucp_ip}"
    ucp_fqdn            = "${var.ucp_fqdn}"
    dtr_ip              = "${var.dtr_ip}"
    dtr_fqdn            = "${var.dtr_fqdn}"
  }
}

data "template_file" "consul_init" {
  template = "${file("${path.module}/scripts/consul_init.tpl.sh")}"

  vars {
    node_count          = "${var.node_count}"
    node_ips            = "${join(" ",var.private_ips)}"
    consul_version      = "${var.consul_version}"
    consul_server       = "${var.consul_server}"
    consul_secret       = "${var.consul_secret}"
  }
}

data "template_file" "shared" {
  template = "${file("${path.module}/scripts/shared.tpl.sh")}"

  vars {
    debug_output        = "${var.debug_output}"
    verbose_output      = "${var.verbose_output}"
  }
}

data "template_file" "docker_init" {
  template = "${file("${path.module}/scripts/docker_init.tpl.sh")}"

  vars {
    node_type           = "${var.node_type}"
    ucp_admin_username  = "${var.ucp_admin_username}"
    ucp_admin_password  = "${var.ucp_admin_password}"
    ucp_version         = "${var.ucp_version}"
    dtr_version         = "${var.dtr_version}"
    dockeree_license    = "${var.dockeree_license}"
    dtr_storage_tye     = "${var.dtr_storage_type}"
    dtr_nfs_url         = "${var.dtr_nfs_url}"
    dtr_s3_bucket       = "${var.dtr_s3_bucket}"
    dtr_s3_region       = "${var.dtr_s3_region}"
    use_custom_ssl      = "${var.use_custom_ssl}"
    dtr_s3_access_key   = "${var.dtr_s3_access_key}"
    dtr_s3_secret_key   = "${var.dtr_s3_secret_key}"
    ucp_ip              = "${var.ucp_ip}"
    ucp_fqdn            = "${var.ucp_fqdn}"
    dtr_fqdn            = "${var.dtr_fqdn}"
  }
}

resource "null_resource" "upload_ssl_cert_files"
{
  triggers {
   resource_id = "${join(",",var.resource_ids)}"
  }

  count = "${var.node_count * var.use_custom_ssl}"

  connection = {
    type          = "ssh"
    host          = "${element (var.public_ips, count.index)}"
    user          = "${var.ssh_username}"
    password      = "${var.ssh_password}"
    private_key   = "${var.private_key}"
    bastion_host  = "${var.bastion_host}"
  }

  provisioner "file" {
    source      = "${var.ssl_ca_file}"
    destination = "${var.script_path}/ca.pem"
  }

  provisioner "file" {
    source      = "${var.ssl_cert_file}"
    destination = "${var.script_path}/cert.pem"
  }

  provisioner "file" {
    source      = "${var.ssl_key_file}"
    destination = "${var.script_path}/key.pem"
  }

}

resource "null_resource" "dockeree_upload_scripts"
{
  triggers {
    resource_id = "${join(",",var.resource_ids)}"
  }

  count = "${var.node_count}"

  connection = {
    type          = "ssh"
    host          = "${element (var.public_ips, count.index)}"
    user          = "${var.ssh_username}"
    password      = "${var.ssh_password}"
    private_key   = "${var.private_key}"
    bastion_host  = "${var.bastion_host}"
  }

  provisioner "file" {
    content     = "${data.template_file.swarm_init.rendered}"
    destination = "${var.script_path}/swarm_init.sh"
  }

  provisioner "file" {
    content     = "${data.template_file.consul_init.rendered}"
    destination = "${var.script_path}/consul_init.sh"
  }

  provisioner "file" {
    content     = "${data.template_file.docker_init.rendered}"
    destination = "${var.script_path}/docker_init.sh"
  }

  provisioner "file" {
    content     = "${data.template_file.shared.rendered}"
    destination = "${var.script_path}/shared.sh"
  }

  provisioner "file" {
    source      = "${path.module}/test"
    destination = "${var.script_path}/test"
  }
}

resource "null_resource" "dockeree_run_init"
{
  triggers {
    resource_id = "${join(",",var.resource_ids)}"
  }

  depends_on = ["null_resource.dockeree_upload_scripts", "null_resource.upload_ssl_cert_files"]
  count = "${var.node_count * var.run_init}"

  connection = {
    type          = "ssh"
    host          = "${element (var.public_ips, count.index)}"
    user          = "${var.ssh_username}"
    password      = "${var.ssh_password}"
    private_key   = "${var.private_key}"
    bastion_host  = "${var.bastion_host}"
    script_path   = "${var.script_path}/terraform_exec"
  }
  provisioner "remote-exec" {
    inline = [
      <<EOT
echo "CERT: ${var.ssl_cert_file}, CA: ${var.ssl_ca_file}, KEY: ${var.ssl_key_File}" | tee ${var.script_path}/cert_paths.log
chmod +x ${var.script_path}/swarm_init.sh
echo "${var.ssh_password}" | sudo -E -S ${var.script_path}/swarm_init.sh | tee ${var.script_path}/swarm_init.log
EOT
    ]
  }

}
