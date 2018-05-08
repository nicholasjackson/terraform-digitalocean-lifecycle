provider "digitalocean" {}

variable "image" {
  #default = "34158157" // version 1
  default = "34157947" // version 2
}

resource "digitalocean_droplet" "web" {
  count  = 2
  image  = "${var.image}"
  name   = "web-${count.index}"
  region = "lon1"
  size   = "512mb"
  tags   = ["example"]

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
  droplet_tag = "example"

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  healthcheck {
    port     = 80
    protocol = "http"
  }
}

output "lb_ip" {
  value = "${digitalocean_loadbalancer.public.ip}"
}
