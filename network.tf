data "openstack_networking_network_v2" "ext_net" {
  name     = "Ext-Net"
  external = true
}

# Privates Netz für Webserver, Datenbank und Load Balancer
resource "openstack_networking_network_v2" "private" {
  name           = "${var.prefix}-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "private" {
  name            = "${var.prefix}-subnet"
  network_id      = openstack_networking_network_v2.private.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = ["213.186.33.99", "1.1.1.1"]

  allocation_pool {
    start = cidrhost(var.subnet_cidr, 100)
    end   = cidrhost(var.subnet_cidr, 200)
  }
}

# Router/Gateway: Internetzugang (apt, npm) und Floating IPs
resource "openstack_networking_router_v2" "gw" {
  name                = "${var.prefix}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net.id
}

resource "openstack_networking_router_interface_v2" "gw" {
  router_id = openstack_networking_router_v2.gw.id
  subnet_id = openstack_networking_subnet_v2.private.id
}
