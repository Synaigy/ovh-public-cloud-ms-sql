output "website_url" {
  description = "Hello World page via the load balancer"
  value       = "http://${openstack_networking_floatingip_v2.lb.address}/"
}

output "db_test_url" {
  description = "Page that reads the message from the database"
  value       = "http://${openstack_networking_floatingip_v2.lb.address}/db"
}

output "ssh_web" {
  description = "SSH command for the web server"
  value       = var.enable_ssh ? "ssh ubuntu@${one(openstack_networking_floatingip_v2.web[*].address)}" : "SSH disabled (set enable_ssh = true)"
}

output "ssh_db" {
  description = "SSH command for the database server (via the web server as jump host)"
  value       = var.enable_ssh ? "ssh -J ubuntu@${one(openstack_networking_floatingip_v2.web[*].address)} ubuntu@${var.db_ip}" : "SSH disabled (set enable_ssh = true)"
}
