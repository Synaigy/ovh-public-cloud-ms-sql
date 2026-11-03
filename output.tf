output "website_url" {
  description = "Hello-World-Seite über den Load Balancer"
  value       = "http://${openstack_networking_floatingip_v2.lb.address}/"
}

output "db_test_url" {
  description = "Seite, die die Nachricht aus der Datenbank liest"
  value       = "http://${openstack_networking_floatingip_v2.lb.address}/db"
}

output "ssh_web" {
  value = var.enable_ssh ? "ssh ubuntu@${one(openstack_networking_floatingip_v2.web[*].address)}" : "SSH deaktiviert (enable_ssh = true setzen)"
}

output "ssh_db" {
  value = var.enable_ssh ? "ssh -J ubuntu@${one(openstack_networking_floatingip_v2.web[*].address)} ubuntu@${var.db_ip}" : "SSH deaktiviert (enable_ssh = true setzen)"
}
