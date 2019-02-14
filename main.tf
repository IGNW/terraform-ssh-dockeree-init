resource "random_id" "consul_secret" {
  byte_length = 16
}

data "template_file" "consul_init" {
  template = "${file("${path.module}/scripts/consul_init.tpl.sh")}"

  vars {
    node_count          = "${var.node_count}"
    node_ips            = "${join(" ",var.node_ips)}"
    consul_url          = "${var.ucp_url}"
    consul_secret       = "${var.consul_secret}"
  }
}

data "template_file" "docker_init" {
  template = "${file("${path.module}/scripts/docker_init.tpl.sh")}"

  vars {
    ucp_admin_username  = "${var.ucp_admin_username}"
    ucp_admin_password  = "${var.ucp_admin_password}"
    ucp_url             = "${var.ucp_url}"
    ucp_version         = "${var.ucp_version}"
  }
}

data "template_file" "config_dtr_minio" {
  template = "${file("${path.module}/scripts/config_dtr_minio.tpl.py")}"

  vars {
    ucp_admin_username  = "${var.ucp_admin_username}"
    ucp_admin_password  = "${var.ucp_admin_password}"
    minio_endpoint      = "${var.minio_endpoint}"
    minio_access_key    = "${var.minio_access_key}"
    minio_secret_key    = "${var.minio_secret_key}"
  }
}

resource "null_resource" "dockeree_init"
{
  triggers {
    resource_id = "${join(",",var.resource_ids)}"
  }

  count = "${var.node_count}"

  provisioner "file" {
    connection = {
      type          = "ssh"
      host          = "${element (var.node_ips, count.index)}"
      user          = "${var.ssh_username}"
      password      = "${var.ssh_password}"
    }
    source      = "${path.module}/scripts/swarm_init.sh"
    destination = "/tmp/swarm_init.sh"
  }

  provisioner "file" {
    connection = {
      type          = "ssh"
      host          = "${element (var.node_ips, count.index)}"
      user          = "${var.ssh_username}"
      password      = "${var.ssh_password}"
    }
    content     = "${data.template_file.consul_init.rendered}"
    destination = "/tmp/consul_init.sh"
  }

  provisioner "file" {
    connection = {
      type          = "ssh"
      host          = "${element (var.node_ips, count.index)}"
      user          = "${var.ssh_username}"
      password      = "${var.ssh_password}"
    }
    content     = "${data.template_file.docker_init.rendered}"
    destination = "/tmp/docker_init.sh"
  }

  provisioner "file" {
    connection = {
      type          = "ssh"
      host          = "${element (var.node_ips, count.index)}"
      user          = "${var.ssh_username}"
      password      = "${var.ssh_password}"
    }
    source      = "${path.module}/scripts/shared.sh"
    destination = "/tmp/shared.sh"
  }


  provisioner "file" {
    connection = {
      type     = "ssh"
      host     = "${element (var.node_ips, count.index)}"
      user     = "${var.ssh_username}"
      password = "${var.ssh_password}"
    }
    content     = "${data.template_file.config_dtr_minio.rendered}"
    destination = "/tmp/config_dtr_minio.sh"
  }

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      host = "${element (var.node_ips, count.index)}"
      user = "${var.ssh_username}"
      password = "${var.ssh_password}"
    }
    inline = [
      <<EOT
chmod +x /tmp/swarm_init.sh /tmp/config_dtr_minio.sh
sudo /tmp/swarm_init.sh | tee /tmp/swarm_init.log
EOT
    ]
  }

}
