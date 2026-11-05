resource "openstack_compute_keypair_v2" "key" {
  name       = "${var.prefix}-key"
  public_key = var.ssh_public_key
}

data "openstack_images_image_v2" "db" {
  name        = var.db_image_name
  most_recent = true
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.web_image_name
  most_recent = true
}

# ==================== Database (b3-8, SQL Server 2025 per Skript) ====================
resource "openstack_networking_port_v2" "db" {
  name               = "${var.prefix}-db-port"
  network_id         = openstack_networking_network_v2.private.id
  security_group_ids = [openstack_networking_secgroup_v2.db.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.private.id
    ip_address = var.db_ip
  }
}

resource "openstack_compute_instance_v2" "db" {
  name        = "${var.prefix}-db"
  flavor_name = var.db_flavor
  image_id    = data.openstack_images_image_v2.db.id
  key_pair    = openstack_compute_keypair_v2.key.name

  user_data = templatefile("${path.module}/scripts/db-init.sh.tftpl", {
    sa_password     = var.sa_password
    app_db_password = var.app_db_password
    mssql_pid       = var.mssql_pid
  })

  network {
    port = openstack_networking_port_v2.db.id
  }

  depends_on = [openstack_networking_router_interface_v2.gw]
}

# ==================== Webserver ====================
resource "openstack_networking_port_v2" "web" {
  name               = "${var.prefix}-web-port"
  network_id         = openstack_networking_network_v2.private.id
  security_group_ids = [openstack_networking_secgroup_v2.web.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.private.id
    ip_address = var.web_ip
  }
}

resource "openstack_compute_instance_v2" "web" {
  name        = "${var.prefix}-web"
  flavor_name = var.web_flavor
  image_id    = data.openstack_images_image_v2.ubuntu.id
  key_pair    = openstack_compute_keypair_v2.key.name

  user_data = templatefile("${path.module}/scripts/web-init.sh.tftpl", {
    db_host         = var.db_ip
    app_db_password = var.app_db_password
  })

  network {
    port = openstack_networking_port_v2.web.id
  }

  depends_on = [openstack_networking_router_interface_v2.gw]
}

# Optional public IP for webserver – just for SSH (enable_ssh = true)
resource "openstack_networking_floatingip_v2" "web" {
  count      = var.enable_ssh ? 1 : 0
  pool       = data.openstack_networking_network_v2.ext_net.name
  depends_on = [openstack_networking_router_interface_v2.gw]
}

resource "openstack_networking_floatingip_associate_v2" "web" {
  count       = var.enable_ssh ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.web[0].address
  port_id     = openstack_networking_port_v2.web.id
}
