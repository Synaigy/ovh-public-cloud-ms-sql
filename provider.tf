terraform {
  backend "s3" {
    bucket = "bucket name"
    key    = "terraform.tfstate"
    region = "de"
    endpoints = {
      s3 = "https://s3.de.io.cloud.ovh.net"
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "2.19.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.4.0"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

provider "openstack" {
  auth_url         = "https://auth.cloud.ovh.net/v3" 
  domain_name      = "default"                       
  user_name        = var.openstack_user
  password         = var.openstack_password
  tenant_id        = var.ovh_service_name
  user_domain_name = "Default"
  region           = "DE1"
}
