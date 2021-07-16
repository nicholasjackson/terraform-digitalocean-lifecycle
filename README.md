# Zero downtime updates with Terraform

HashiCorp Terraform enables you to safely and predictably create, change, and improve infrastructure. It is an open source tool that codifies APIs into declarative configuration files that can be shared amongst team members, treated as code, edited, reviewed, and versioned.

Change is part of managing infrastructure, nothing ever stays the same and nor should it, we often need to update and patch VMs, and we need to be able to do this without causing any disruption to our users.  Changing certain attributes on a resource such as changing the image of a VM, will cause terraform to destroy the resource and re-create it. When this is not managed correctly, this behavior can cause downtime for your systems.

In this post, we are going to look at two simple features in Terraform that allow us to avoid downtime caused by updates and allow uninterrupted replacement of resources.  The examples in this post use the DigitalOcean provider, however, the techniques explained are not specific to any particular provider they are features built into the Terraform core.

## Problem 1 - How to ensure new infrastructure is created before the old is destroyed
Consider the following resource to create a simple droplet:

```ruby
resource "digitalocean_droplet" "web" {
  count  = 2
  image  = "${var.image}"
  name   = "web-${count.index}"
  region = "lon1"
  size   = "s-1vcpu-1gb"
  tags   = ["example"]
}
```

If this resource already exists from a previous `terraform apply` and we then modify the image, the next time we run `plan`, terraform informs us that the existing resource will be destroyed before the new one is created.

```bash
An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  ~ update in-place
-/+ destroy and then create replacement

Terraform will perform the following actions:

-/+ digitalocean_droplet.web[0] (new resource required)
      id:                   "92822972" => <computed> (forces new resource)
      disk:                 "20" => <computed>
```

The reason for this is that it is not possible to update this particular attribute of a resource and Terraform needs to remove the existing instance and the new one.  Terraform's standard behavior is that it will first `destroy` the resource and once the destruction has completed it will then `create` the replacement.  In a production environment, this would cause undesirable momentary downtime.

To avoid this we can utilize a meta parameter available on Terraform resource stanza blocks [lifecycle](https://www.terraform.io/docs/configuration/resources.html#lifecycle).

The lifecycle configuration block allows you to set three different flags which control the lifecycle of your resource.
* create_before_destroy - This flag is used to ensure the replacement of a resource is created before the original instance is destroyed.
* prevent_destroy - This flag provides extra protection against the destruction of a given resource. 
* ignore_changes - Customizes how diffs are evaluated for resources, allowing individual attributes to be ignored through changes.

The flag we are interested in is `create_before_destroy` we can add it to our resource stanza like so:

```ruby
resource "digitalocean_droplet" "web" {
  count  = 2
  image  = "${var.image}"
#...

  lifecycle {
    create_before_destroy = true
  }
}
```

With the addition of the lifecycle hook, when we run our `terraform apply`, Terraform first creates the new resources before destroying the old resources.

## Problem 2 - A running VM does not necessarily mean a working application
Because a virtual machine has started, it does not mean that an application is available to serve requests.  When a VM starts it goes through a startup lifecycle; the VM boots, then systemd or startup scripts need to run. Finally, your application needs time to start.  Terraform is not aware of your application lifecycle and depending on the type and complexity this could be some minutes after Terraform has created the instance.

To solve this problem, we can add a [provisioner](https://www.terraform.io/docs/provisioners/index.html) to our resource which can perform an application health check.  Terraform does not declare the resource successfully created until the provisioner has completed without error.  The provisioner delays the destruction of the old resources until we are sure that our new resource has been created and is capable of serving requests.

```ruby
resource "digitalocean_droplet" "web" {
  count  = 2
  image  = "${var.image}"
#...
  lifecycle {
    create_before_destroy = true
  }

  provisioner "local-exec" {
    command = "./check_health.sh ${self.ipv4_address}"
  }
}
```

In this example, we are running a shell script which curls the application and looks for an HTTP status code  `200`.  Depending on your application you may need to write something more complex.  For example, if you are running Consul and the application registers a health check with Consul, your provisioner command could query Consuls service catalog to check the application health.  Because you can leverage all of the available provisioners, Terraform offers you have the flexibility of tailoring this step specific to your resource.  Once the provisioner has completed successfully then Terraform declares that the resource has been successfully created and will continue to remove the old resource.  Should the provisioner fail then Terraform will `taint` the resource and fail the `apply` step, the old resources are not deleted, and you can correct any issues and re-run `terraform plan` and `terraform apply`.



## Running the examples

### Set environment variables

```bash
export DIGITALOCEAN_TOKEN=xxxxxxxxxxxxx
export DIGITALOCEAN_API_TOKEN=xxxxxxxxxxxxxx
```

### Build Packer images
The example in this repository requires you create the two images containing NGINX and a simple HTML page to differentiate between the two versions, to do this you will need `packer` and `ansible` installed.

```bash
$ cd packer
# Build version 1
$ packer build -var 'siteversion=1' example.json
# Build version 2
$ packer build -var 'siteversion=2' example.json
```

### Init terraform

To run the example first initialize `terraform` to download any required plugins

```bash
$ terraform init
```

### Create version 1 of the configuration

The next step is to create the initial version running terraform `plan` and `apply`, we are specifiying the version as a variable to the plan command, this will select the correct image which you built in the previous step:

```bash
$ terraform plan -var 'siteversion=1' -out out.plan
$ terraform apply out.plan
```

Now the initial version has been created containing two droplets with our version 1 image and a load balancer you can run the simple test script to ping the service.

```bash
$ ./test $(terraform output lb_ip)
```

### Create version 2 of the configuration

In a new terminal window we can now update the existing infrastructure by re-running the plan and specifying `siteversion=2` as a variable, this will force terraform to re-create the two droplets as the image has now changes.

```bash
$ terraform plan -var 'siteversion=2' -out out.plan
$ terraform apply out.plan
```

You will see that terraform is creating the new droplets before destroying the old ones, it also waits for the health check script to complete to ensure that the application has initialized.  If you look at the test script you should see the version transition seemlessly between `Version 1` and `Version 2`

## Summary
Implementing `lifecycle hooks` and utilizing `provisioners` ensure that your new instances are created and available to serve requests before Terraform removes the old instances, this gives you a seamless and uninterrupted upgrade process.

To try out these examples, please see the example code which can be found at: [https://github.com/nicholasjackson/terraform-digitalocean-lifecycle](https://github.com/nicholasjackson/terraform-digitalocean-lifecycle)

A full walkthrough of this example can be seen in the following video: <iframe width="560" height="315" src="https://www.youtube.com/embed/bQxS4FT9qtc" frameborder="0" allow="autoplay; encrypted-media" allowfullscreen></iframe>
