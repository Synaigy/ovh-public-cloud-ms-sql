data "openstack_lb_flavor_v2" "small" {
  name = "small"
}

resource "openstack_lb_loadbalancer_v2" "lb" {
  name          = "${var.prefix}-lb"
  vip_subnet_id = openstack_networking_subnet_v2.private.id
  flavor_id     = data.openstack_lb_flavor_v2.small.id

  depends_on = [openstack_networking_router_interface_v2.gw]
}

resource "openstack_lb_listener_v2" "http" {
  name            = "${var.prefix}-http"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb.id
}

resource "openstack_lb_pool_v2" "web" {
  name        = "${var.prefix}-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.http.id
}

resource "openstack_lb_monitor_v2" "web" {
  pool_id     = openstack_lb_pool_v2.web.id
  type        = "HTTP"
  url_path    = "/"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

resource "openstack_lb_member_v2" "web" {
  pool_id       = openstack_lb_pool_v2.web.id
  address       = var.web_ip
  protocol_port = 80
  subnet_id     = openstack_networking_subnet_v2.private.id

  depends_on = [openstack_compute_instance_v2.web]
}

# Public IP for the load balancer
resource "openstack_networking_floatingip_v2" "lb" {
  pool       = data.openstack_networking_network_v2.ext_net.name
  depends_on = [openstack_networking_router_interface_v2.gw]
}

resource "openstack_networking_floatingip_associate_v2" "lb" {
  floating_ip = openstack_networking_floatingip_v2.lb.address
  port_id     = openstack_lb_loadbalancer_v2.lb.vip_port_id
}
