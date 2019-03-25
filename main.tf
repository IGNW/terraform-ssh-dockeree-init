resource "random_id" "consul_secret" {
  byte_length = 16
}

data "template_file" "swarm_init" {
  template = "${file("${path.module}/scripts/swarm_init.tpl.sh")}"

  vars {
    node_type           = "${var.node_type}"
  }
}

data "template_file" "consul_init" {
  template = "${file("${path.module}/scripts/consul_init.tpl.sh")}"

  vars {
    node_count          = "${var.node_count}"
    node_ips            = "${join(" ",var.private_ips)}"
    consul_version      = "${var.consul_version}"
    manager_ip          = "${var.manager_ip}"
    consul_secret       = "${var.consul_secret}"
  }
}

data "template_file" "docker_init" {
  template = "${file("${path.module}/scripts/docker_init.tpl.sh")}"

  vars {
    ucp_admin_username  = "${var.ucp_admin_username}"
    ucp_admin_password  = "${var.ucp_admin_password}"
    manager_ip          = "${var.manager_ip}"
    ucp_url             = "${var.ucp_url}"
    dtr_url             = "${var.dtr_url}"
    ucp_version         = "${var.ucp_version}"
    dtr_version         = "${var.dtr_version}"
    dockeree_license    = "${var.dockeree_license}"
    dtr_storage_tye     = "${var.dtr_storage_type}"
    dtr_nfs_url         = "${var.dtr_nfs_url}"
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
    source      = "${path.module}/scripts/shared.sh"
    destination = "${var.script_path}/shared.sh"
  }

}

resource "null_resource" "dockeree_run_init"
{
  triggers {
    resource_id = "${join(",",var.resource_ids)}"
  }

  depends_on = ["null_resource.dockeree_upload_scripts"]
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
chmod +x ${var.script_path}/swarm_init.sh
echo "${var.ssh_password}" | sudo -E -S ${var.script_path}/swarm_init.sh | tee ${var.script_path}/swarm_init.log
EOT
    ]
  }

}
