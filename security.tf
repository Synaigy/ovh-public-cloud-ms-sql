# ---------- Webserver ----------
resource "openstack_networking_secgroup_v2" "web" {
  name        = "${var.prefix}-web-sg"
  description = "HTTP from the load balancer, optional SSH from outside"
}

resource "openstack_networking_secgroup_rule_v2" "web_http" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.subnet_cidr # Load balancer sits in the private subnet
}

resource "openstack_networking_secgroup_rule_v2" "web_ssh" {
  count             = var.enable_ssh ? 1 : 0
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_allowed_cidr
}

# ---------- Database ----------
resource "openstack_networking_secgroup_v2" "db" {
  name        = "${var.prefix}-db-sg"
  description = "MSSQL only from the web server, SSH only from the private network"
}

resource "openstack_networking_secgroup_rule_v2" "db_mssql" {
  security_group_id = openstack_networking_secgroup_v2.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1433
  port_range_max    = 1433
  remote_ip_prefix  = "${var.web_ip}/32"
}

resource "openstack_networking_secgroup_rule_v2" "db_ssh" {
  security_group_id = openstack_networking_secgroup_v2.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.subnet_cidr
}
