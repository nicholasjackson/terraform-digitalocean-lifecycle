terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

locals {
  ubuntuversion = "18-04"
  dropletsize   = "s-1vcpu-1gb"
  dropletregion = "lon1"
}

variable "siteversion" {
  default = "1"
}

data "digitalocean_image" "example1" {
  name = "example-ubuntu-${local.ubuntuversion}-x64-${var.siteversion}"
}

resource "digitalocean_droplet" "web" {
  count = 2

  image  = "${data.digitalocean_image.example1.image}"
  name   = "web-${count.index}"
  region = local.dropletregion 
  size   = local.dropletsize 
  tags   = ["zero-downtime"]

  lifecycle {
    create_before_destroy = true
  }

  provisioner "local-exec" {
    command = "./check_health.sh ${self.ipv4_address}"
  }
}

resource "digitalocean_loadbalancer" "public" {
  name        = "loadbalancer-1"
  region      = "lon1"
  droplet_tag = "zero-downtime"

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  healthcheck {
    port                   = 80
    protocol               = "http"
    path                   = "/"
    check_interval_seconds = "5"
  }
}

output "lb_ip" {
  value = "${digitalocean_loadbalancer.public.ip}"
}
