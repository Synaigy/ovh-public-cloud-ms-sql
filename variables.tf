# ---------- Credentials ----------
variable "ovh_service_name" {
  description = "Public Cloud project ID (used as OpenStack tenant ID)"
  type        = string
  sensitive   = false
}

variable "ovh_application_key" {
  description = "OVH API application key"
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "OVH API application secret"
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "OVH API consumer key"
  type        = string
  sensitive   = true
}

variable "openstack_password" {
  description = "OpenStack user password"
  type        = string
  sensitive   = true
}

variable "openstack_user" {
  description = "OpenStack username"
  type        = string
  sensitive   = true
}

# ---------- Main ----------
variable "region" {
  description = "OVHcloud Public Cloud region (e.g. DE1, GRA11, SBG7)"
  type        = string
  default     = "DE1"
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "hello"
}

variable "ssh_public_key" {
  description = "Public SSH key used to log in to the VMs"
  type        = string
}

variable "enable_ssh" {
  description = "true = attach a public IP to the web server for SSH (debugging)"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Source range allowed to SSH into the web server (ideally your own IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}

# ---------- Images and flavors ----------
variable "db_image_name" {
  description = "Base image for the database server (SQL Server is installed by script)"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "web_image_name" {
  description = "Base image for the web server"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "db_flavor" {
  description = "Instance flavor for the database server"
  type        = string
  default     = "b3-8"
}

variable "web_flavor" {
  description = "Instance flavor for the web server"
  type        = string
  default     = "d2-4"
}

# ---------- SQL Server ----------
variable "mssql_pid" {
  description = "SQL Server 2025 edition (Express, StandardDeveloper, EnterpriseDeveloper, ...)"
  type        = string
  default     = "Express"
}

variable "sa_password" {
  description = "SQL Server sa password (min. 8 characters, upper/lower case, digit, special character)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.sa_password) >= 8 && !can(regex("['\"\\\\$`]", var.sa_password))
    error_message = "Use at least 8 characters and none of these characters: ' \" \\ $ `"
  }
}

variable "app_db_password" {
  description = "Password for the SQL login 'webapp' used by the web server"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.app_db_password) >= 8 && !can(regex("['\"\\\\$`]", var.app_db_password))
    error_message = "Use at least 8 characters and none of these characters: ' \" \\ $ `"
  }
}

# ---------- Network: static private IPs ----------
# Fixed private IPs so the web server can reach the database directly
variable "subnet_cidr" {
  description = "CIDR of the private subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "web_ip" {
  description = "Private IP of the web server"
  type        = string
  default     = "10.0.0.10"
}

variable "db_ip" {
  description = "Private IP of the database server"
  type        = string
  default     = "10.0.0.20"
}
