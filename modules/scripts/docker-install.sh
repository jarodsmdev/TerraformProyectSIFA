#!/bin/bash
set -eux

export DEBIAN_FRONTEND=noninteractive

# Esperar internet
until ping -c 1 archive.ubuntu.com >/dev/null 2>&1; do
  echo "Esperando conectividad..."
  sleep 5
done

apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

if id "ubuntu" &>/dev/null; then
    usermod -aG docker ubuntu
fi