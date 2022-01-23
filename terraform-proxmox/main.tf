# https://austinsnerdythings.com/2021/09/01/how-to-deploy-vms-in-proxmox-with-terraform/
# https://yetiops.net/posts/proxmox-terraform-cloudinit-saltstack-prometheus/

provider "proxmox" {
  pm_api_url      = "https://${var.proxmox-host}:8006/api2/json"

  # pm_parallel     = 2

  pm_tls_insecure = true
  pm_api_token_id = var.token
  pm_api_token_secret = var.secret

  pm_log_enable   = true
  pm_log_file     = "terraform-plugin-proxmox.log"
  
  # pm_debug = true
  pm_log_levels   = {
    _default = "debug"
    _capturelog = ""
  }
}

resource "proxmox_vm_qemu" "proxmox_vm_master" {
  count       = var.master.count
  name        = "${var.master.name}-${count.index + 1}"
  clone       = var.master.image

  target_node = var.master_nodes[count.index % length(var.master_nodes)]
  
  os_type     = "cloud-init"
  agent       = 1
  cpu         = "kvm64"
  sockets     = var.master.sockets
  onboot      = var.master.onboot
  
  cores       = var.master.cpu
  # vcpus       = var.master.cpu
  memory      = var.master.memory

  vmid        = "${var.basic.vmid + var.master.ip + count.index + 1}"
  # ipconfig0   = "ip=${var.basic.network}.${var.master.ip + count.index + 1}/${var.basic.subnet},gw=${var.basic.gateway}"
 
  network {
    bridge    = "vmbr0"
    model     = "e1000"
    macaddr   = var.basic.masterMac
  }

  disk {
    type    = var.master.diskType
    storage = var.storage_volumes[var.master_nodes[count.index % length(var.master_nodes)]]
    size    = var.master.diskSize
  }

  lifecycle {
    ignore_changes  = [
      network,
      disk,
    ]
  }

  ciuser      = var.accounts.user
  cipassword  = var.accounts.password
  sshkeys     = "${file(var.accounts.sshKeyPathPub)}"
}

resource "proxmox_vm_qemu" "proxmox_vm_worker" {
  count       = var.worker.count
  name        = "${var.worker.name}-${count.index + 1}"
  clone       = var.worker.image

  target_node = var.worker_nodes[count.index % length(var.worker_nodes)]
  
  os_type     = "cloud-init"
  agent       = 1
  cpu         = "kvm64"
  sockets     = var.worker.sockets
  onboot      = var.worker.onboot

  cores       = var.worker.cpu
  memory      = var.worker.memory

  vmid        = "${var.basic.vmid + var.worker.ip + count.index + 1}"
  # ipconfig0   = "ip=${var.basic.network}.${var.master.ip + count.index + 1}/${var.basic.subnet},gw=${var.basic.gateway}"

  disk {
    type    = var.worker.diskType
    storage = var.storage_volumes[var.worker_nodes[count.index % length(var.worker_nodes)]]
    size    = var.worker.diskSize
  }

  lifecycle {
    ignore_changes  = [
      network,
      disk,
    ]
  }

  ciuser      = var.accounts.user
  cipassword  = var.accounts.password
  sshkeys     = "${file(var.accounts.sshKeyPathPub)}"
}

resource "proxmox_vm_qemu" "proxmox_vm_storage" {
  count       = var.storage.count
  name        = "${var.storage.name}-${count.index + 1}"
  clone       = var.storage.image

  target_node = var.storage_nodes[count.index % length(var.storage_nodes)]
  
  os_type     = "cloud-init"
  agent       = 1
  cpu         = "kvm64"
  sockets     = var.storage.sockets
  onboot      = var.storage.onboot
  
  cores       = var.storage.cpu
  memory      = var.storage.memory

  vmid        = "${var.basic.vmid + var.storage.ip + count.index + 1}"
  # ipconfig0   = "ip=${var.basic.network}.${var.master.ip + count.index + 1}/${var.basic.subnet},gw=${var.basic.gateway}"
  
  disk {
    type    = var.storage.diskType
    storage = var.storage_volumes[var.storage_nodes[count.index % length(var.storage_nodes)]]
    size    = var.storage.diskSize
  }

  network {
    bridge    = "vmbr0"
    model     = "e1000"
    # tag       = var.basic.vlan
  }

  lifecycle {
    ignore_changes  = [
      network,
      disk,
    ]
  }

  ciuser      = var.accounts.user
  cipassword  = var.accounts.password
  sshkeys     = "${file(var.accounts.sshKeyPathPub)}"
}

resource "proxmox_vm_qemu" "proxmox_vm_cache" {
  count       = var.cache.count
  name        = "${var.cache.name}-${count.index + 1}"
  clone       = var.cache.image

  target_node = var.cache_nodes[count.index % length(var.cache_nodes)]
  
  os_type     = "cloud-init"
  agent       = 1
  cpu         = "kvm64"
  sockets     = var.cache.sockets
  onboot      = var.cache.onboot
  
  cores       = var.cache.cpu
  memory      = var.cache.memory

  vmid        = "${var.basic.vmid + var.cache.ip + count.index + 1}"
  # ipconfig0   = "ip=${var.basic.network}.${var.caching.ip + count.index + 1}/${var.basic.subnet},gw=${var.basic.gateway}"

  disk {
    type    = var.cache.diskType
    storage = var.storage_volumes[var.cache_nodes[count.index % length(var.cache_nodes)]]
    size    = var.cache.diskSize
  }
  
  network {
    bridge    = "vmbr0"
    model     = "e1000"
    # tag       = var.basic.vlan
    macaddr   = var.basic.cacheMac
  }

  lifecycle {
    ignore_changes  = [
      network,
      disk,
    ]
  }

  ciuser      = var.accounts.user
  cipassword  = var.accounts.password
  sshkeys     = "${file(var.accounts.sshKeyPathPub)}"
}

data "template_file" "k3s" {
  template = file("./templates/k3s.tpl")
  vars = {
    k3s_master_ip   = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_master  : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
    k3s_worker_ip   = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_worker  : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
    k3s_storage_ip  = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_storage : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
    k3s_cache_ip    = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_cache   : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.accounts.sshKeyPath])])}"
  }
}

resource "local_file" "k3s_file" {
  content  = data.template_file.k3s.rendered
  filename = "../inventory/my-cluster/hosts.ini"
}

output "master-IPs" {
  value = ["${proxmox_vm_qemu.proxmox_vm_master.*.default_ipv4_address}"]
}

output "worker-IPs" {
  value = ["${proxmox_vm_qemu.proxmox_vm_worker.*.default_ipv4_address}"]
}

output "storage-IPs" {
  value = ["${proxmox_vm_qemu.proxmox_vm_storage.*.default_ipv4_address}"]
}

output "cache-IPs" {
  value = ["${proxmox_vm_qemu.proxmox_vm_cache.*.default_ipv4_address}"]
}