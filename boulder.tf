provider "libvirt" {
    uri = "qemu:///system"
}

resource "libvirt_cloudinit" "letsencryptinit" {
  name = "cloudinit_letsencrypt"
  local_hostname = "letsencrypt"
  ssh_authorized_key = ""
  user_data = <<EOF
packages:
- qemu-guest-agent
- deltarpm
- git
- golang
- epel-release
- docker
- vim 
- certbot
write_files:
-   content: |
        #!/bin/bash
        export GOPATH=/root/gopath
        mkdir -p $GOPATH
        git clone https://github.com/certbot/certbot.git /root/certbot
        git clone https://github.com/letsencrypt/boulder/ /root/gopath/src/github.com/letsencrypt/boulder
        cd /root/gopath/src/github.com/letsencrypt/boulder
        docker-compose up &
    path: /root/run_docker-compose.sh
    permissions: '0755'
runcmd:
- systemctl enable docker
- systemctl start docker
- systemctl enable qemu-guest-agent
- systemctl start qemu-guest-agent
- [ "yum", "-y", "install", "python-pip" ]
- [ "yum", "-y", "upgrade", "python*" ]
- pip install docker-compose
- setenforce permissive
- /root/run_docker-compose.sh
EOF
}

resource "libvirt_volume" "centos" {
  name = "centos_default_letsencrypt.img"
  source = "http://localhost:8180/CentOS-7-x86_64-GenericCloud.qcow2"
}

resource "libvirt_domain" "letsencrypt" {
  name = "letsencrypt"
  memory = "2048"
  disk {
    volume_id = "${libvirt_volume.centos.id}"
  }
  network_interface {
    bridge = "br0"
    wait_for_lease = "true"
  }
  console {
    type = "pty"
    target_port = "0"
    target_type = "serial"
  }
  cloudinit = "${libvirt_cloudinit.letsencryptinit.id}"
}

