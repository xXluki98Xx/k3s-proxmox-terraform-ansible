# Original work was extended to

* Hardening for OS (and K3s Cluster)
* Storage Nodes
* Caching Server for Container Images and Package Caching
* Bandwidth reduction due to proxy usage
* Added Playbook for VM-Template creation

Currently only on Debian 11 tested

### Prework

```bash
cp terraform/vars.tf-example terraform/vars.tf
cp -R inventory/sample inventory/my-cluster
```

### Proxmox setup

The "cloudinit.yml" contains a simple Ansible Workflow to create a template VM for the Proxmox k3s.

```bash
ansible-playbook -i proxmoxServerIp, cloudinit.yml
```

### Terraform setup

To get started with the Terraform part you need to provide the Credentials for your Proxmox Server/ Cluster.
If you did not know how, take a look [here](https://austinsnerdythings.com/2021/09/01/how-to-deploy-vms-in-proxmox-with-terraform/).

Setup your k3s Cluster Config in the vars.tf, after you apply, the ansible inventory file will be created.
The Terraform Config uses the template vm from the cloudinit.yml, which has to be present on each node you want to interact with.
Terraform is going to set the sshkey, -user, -password to the VMs it is going to create.

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

### Ansible setup

One finished you can run the following code, but be sure to update the yml in the group_vars folder.

```bash
ansible-playbook site.yml -i inventory/my-cluster/hosts.ini
```

### Kubeconfig

At the end, the kube.conf will be copied to your local machine to ~/.kube/{{ cluster_name }}-config

---

## Original README below

---

# Build a Kubernetes cluster using k3s on Proxmox via Ansible and Terraform

This is based on the great work that <https://github.com/itwars> done with Ansible, all I left to do is to put it all together with terraform and Proxmox!

## System requirements

* The deployment environment must have Ansible 2.4.0+
* Terraform installed
* Proxmox server

## How to
for updated documentation check out my [medium](https://medium.com/@ssnetanel/build-a-kubernetes-cluster-using-k3s-on-proxmox-via-ansible-and-terraform-c97c7974d4a5).


### Proxmox setup

This setup is relaying on cloud-init images.

Using cloud-init image save us a lot of time and it's work great!
I use ubuntu focal image, you can use whatever distro you like.

to configure the cloud-init image you will need to connect to a Linux server and run the following:

install image tools on the server (you will need another server, these tools cannot be installed on Proxmox)

```bash
apt-get install libguestfs-tools
```

Get the image that you would like to work with.
you can browse to <https://cloud-images.ubuntu.com> and select any other version that you would like to work with.
for Debian, got to <https://cloud.debian.org/images/cloud/>.
it can also work for centos (R.I.P)

```bash
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
```

update the image and install Proxmox agent - this is a must if we want terraform to work properly.
it can take a minute to add the package to the image.

```bash
virt-customize focal-server-cloudimg-amd64.img --install qemu-guest-agent
```

now that we have the image, we need to move it to the Proxmox server.
we can do that by using `scp`

```bash
scp focal-server-cloudimg-amd64.img Proxmox_username@Proxmox_host:/path_on_Proxmox/focal-server-cloudimg-amd64.img
```

so now we should have the image configured and on our Proxmox server. let's start creating the VM

```bash
qm create 9000 --name "ubuntu-focal-cloudinit-template" --memory 2048 --net0 virtio,bridge=vmbr0
```

for ubuntu images, rename the image suffix

```bash
mv focal-server-cloudimg-amd64.img focal-server-cloudimg-amd64.qcow2
```

import the disk to the VM

```bash
qm importdisk 9000 focal-server-cloudimg-amd64.qcow2 local-lvm
```

configure the VM to use the new image

```bash
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
```

add cloud-init image to the VM

```bash
qm set 9000 --ide2 local-lvm:cloudinit
```

set the VM to boot from the cloud-init disk:

```bash
qm set 9000 --boot c --bootdisk scsi0
```

update the serial on the VM

```bash
qm set 9000 --serial0 socket --vga serial0
```

Good! so we are almost done with the image. now we can configure our base configuration for the image.
you can connect to the Proxmox server and go to your VM and look on the cloud-init tab, here you will find some more parameters that we will need to change.

![alt text](pics/gui-cloudinit-config.png)

you will need to change the user name, password, and add the ssh public key so we can connect to the VM later using Ansible and terraform.
update the variables and click on `Regenerate Image`

Great! so now we can convert the VM to a template and start working with terraform.

```bash
qm template 9000
```

### terraform setup

our terraform file also creates a dynamic host file for Ansible, so we need to create the files first

```bash
cp -R inventory/sample inventory/my-cluster
```

Rename the file `terraform/vars.sample` to `terraform/vars.tf` and update all the vars.
there you can select how many nodes would you like to have on your cluster and configure the name of the base image.
to run the Terrafom, you will need to cd into `terraform` and run:

```bash
terraform init
terraform plan
terraform apply
```

it can take some time to create the servers on Proxmox but you can monitor them over Proxmox.
it shoul look like this now:

![alt text](pics/h0Ha98fXyO.png)

### Ansible setup

First, update the var file in `inventory/my-cluster/group_vars/all.yml` and update the user name that you're selected in the cloud-init setup.

after you run the Terrafom file, your file should look like this:

```bash
[master]
192.168.3.200 Ansible_ssh_private_key_file=~/.ssh/proxk3s

[node]
192.168.3.202 Ansible_ssh_private_key_file=~/.ssh/proxk3s
192.168.3.201 Ansible_ssh_private_key_file=~/.ssh/proxk3s
192.168.3.198 Ansible_ssh_private_key_file=~/.ssh/proxk3s
192.168.3.203 Ansible_ssh_private_key_file=~/.ssh/proxk3s

[k3s_cluster:children]
master
node
```

Start provisioning of the cluster using the following command:

```bash
Ansible-playbook site.yml -i inventory/my-cluster/hosts.ini
```

## Kubeconfig

To get access to your **Kubernetes** cluster just

```bash
scp debian@master_ip:~/.kube/config ~/.kube/config
```
