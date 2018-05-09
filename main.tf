provider "digitalocean" {}

variable "version" {
  default = "1"
}

data "digitalocean_image" "example1" {
  name = "example-ubuntu-16-04-x64-${var.version}"
}

resource "digitalocean_droplet" "web" {
  count  = 2
  image  = "${data.digitalocean_image.example1.image}"
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
    path     = "/"
  }
}

output "lb_ip" {
  value = "${digitalocean_loadbalancer.public.ip}"
}
