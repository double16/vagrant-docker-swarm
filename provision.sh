#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

if [ -n "$http_proxy" ]; then
  cat > /etc/apt/apt.conf.d/01proxy <<EOF
Acquire::HTTP::Proxy "$http_proxy";
Acquire::HTTPS::Proxy false;
EOF
fi

apt-get update -y -qq

apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   edge"

# GlusterFS
add-apt-repository ppa:gluster/glusterfs-4.1
add-apt-repository ppa:gluster/glusterfs-coreutils

apt-get update -y -qq

# apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install --force-yes -y docker-ce glusterfs-server glusterfs-coreutils
mkdir -p /etc/systemd/system/docker.service.d/http-proxy.conf

usermod -aG docker vagrant

systemctl start docker
