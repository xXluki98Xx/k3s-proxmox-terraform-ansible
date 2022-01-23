provider "hcloud" {
  token = "${var.token}"
}

resource "hcloud_network" "network" {
  name          = "network"
  ip_range      = var.basic.network
}

resource "hcloud_network_subnet" "network-subnet" {
  type          = "cloud"
  network_id    = hcloud_network.network.id
  network_zone  = var.basic.networkzone
  ip_range      = var.basic.subnetwork
}

resource "hcloud_server" "hetzner_vm_master" {
  name          = "${var.master.name}-${count.index + 1}"

  count         = var.master.count
  server_type   = var.master.type
  image         = var.master.image
  location      = var.master_nodes[count.index % length(var.master_nodes)]

  user_data     = data.template_file.cloud_init_k3s.rendered

  network {
    network_id  = hcloud_network.network.id
    ip          = "${var.basic.ipset}.${var.master.ip + count.index + 1}"
  }

  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
}

resource "hcloud_server" "hetzner_vm_worker" {
  name          = "${var.worker.name}-${count.index + 1}"

  count         = var.worker.count
  server_type   = var.worker.type
  image         = var.worker.image
  location      = var.worker_nodes[count.index % length(var.worker_nodes)]

  user_data     = data.template_file.cloud_init_k3s.rendered

  network {
    network_id  = hcloud_network.network.id
    ip          = "${var.basic.ipset}.${var.worker.ip + count.index + 1}"
  }

  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
}

resource "hcloud_server" "hetzner_vm_storage" {
  name          = "${var.storage.name}-${count.index + 1}"

  count         = var.storage.count
  server_type   = var.storage.type
  image         = var.storage.image
  location      = var.storage_nodes[count.index % length(var.storage_nodes)]

  user_data     = data.template_file.cloud_init_k3s.rendered

  network {
    network_id  = hcloud_network.network.id
    ip          = "${var.basic.ipset}.${var.storage.ip + count.index + 1}"
  }

  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
}

resource "hcloud_server" "hetzner_vm_cache" {
  name          = "${var.cache.name}-${count.index + 1}"

  count         = var.cache.count
  server_type   = var.cache.type
  image         = var.cache.image
  location      = var.cache_nodes[count.index % length(var.cache_nodes)]

  user_data     = data.template_file.cloud_init_k3s.rendered

  network {
    network_id  = hcloud_network.network.id
    ip          = "${var.basic.ipset}.${var.cache.ip + count.index + 1}"
  }

  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
}

data "template_file" "k3s" {
  template = file("./templates/k3s.tpl")
  vars = {
    k3s_master_ip   = "${join("\n", [for instance in hcloud_server.hetzner_vm_master  : join("", [instance.ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
    k3s_worker_ip   = "${join("\n", [for instance in hcloud_server.hetzner_vm_worker  : join("", [instance.ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
    k3s_storage_ip  = "${join("\n", [for instance in hcloud_server.hetzner_vm_storage : join("", [instance.ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
    k3s_cache_ip    = "${join("\n", [for instance in hcloud_server.hetzner_vm_cache   : join("", [instance.ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
  }
}

resource "local_file" "k3s_file" {
  content  = data.template_file.k3s.rendered
  filename = "../inventory/my-hetzner-cluster/hosts.ini"
}

output "master-IPs" {
  value = ["${hcloud_server.hetzner_vm_master.*.ipv4_address}"]
}

output "worker-IPs" {
  value = ["${hcloud_server.hetzner_vm_worker.*.ipv4_address}"]
}

output "storage-IPs" {
  value = ["${hcloud_server.hetzner_vm_storage.*.ipv4_address}"]
}

output "cache-IPs" {
  value = ["${hcloud_server.hetzner_vm_cache.*.ipv4_address}"]
}