# ---------- Credentials (from GitHub Secrets) ----------
variable "ovh_service_name" {
  description = "Service name for ovh project"
  type        = string
  sensitive   = false
}

variable "ovh_application_key" {
  description = "Application key for ovh project"
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "Application secret for ovh project"
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "Consumer key for ovh project"
  type        = string
  sensitive   = true
}

variable "openstack_password" {
  description = "openstack password"
  type        = string
  sensitive   = true
}

variable "openstack_user" {
  description = "openstack user"
  type        = string
  sensitive   = true
}

# ---------- Main ----------
variable "region" {
  description = "OVH-Region (muss die Region sein, in der dein mssql-Image liegt)"
  type        = string
  default     = "DE1"
}

variable "prefix" {
  description = "Präfix für alle Ressourcennamen"
  type        = string
  default     = "hello"
}

variable "ssh_public_key" {
  description = "Öffentlicher SSH-Key für den Login auf die VMs"
  type        = string
}

variable "enable_ssh" {
  description = "true = Webserver bekommt eine Public IP für SSH (Debugging)"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Von wo SSH auf den Webserver erlaubt ist (am besten deine eigene IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}

# ---------- Images and Flavors ----------
variable "db_image_name" {
  description = "Name des Snapshots mit SQL Server 2025"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "web_image_name" {
  description = "Basis-Image für den Webserver"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "db_flavor" {
  type    = string
  default = "b3-8"
}

variable "web_flavor" {
  type    = string
  default = "d2-4"
}

# ---------- SQL Server ----------
variable "mssql_pid" {
  description = "SQL-Server-2025-Edition (Express, StandardDeveloper, EnterpriseDeveloper, ...)"
  type        = string
  default     = "Express"
}

variable "sa_password" {
  description = "SA-Passwort für SQL Server (min. 8 Zeichen, Groß/Klein/Zahl/Sonderzeichen)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.sa_password) >= 8 && !can(regex("['\"\\\\$`]", var.sa_password))
    error_message = "Mindestens 8 Zeichen und keine Zeichen ' \" \\ $ ` verwenden."
  }
}

variable "app_db_password" {
  description = "Passwort für den DB-User 'webapp', mit dem der Webserver verbindet"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.app_db_password) >= 8 && !can(regex("['\"\\\\$`]", var.app_db_password))
    error_message = "Mindestens 8 Zeichen und keine Zeichen ' \" \\ $ ` verwenden."
  }
}

# ---------- Networks: static private IPs ----------
# Feste private IPs, damit der Webserver die DB direkt findet
variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "web_ip" {
  type    = string
  default = "10.0.0.10"
}

variable "db_ip" {
  type    = string
  default = "10.0.0.20"
}
