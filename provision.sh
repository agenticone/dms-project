#!/bin/bash

set -e

echo "Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "Installing prerequisites..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release openssl

echo "Installing Docker..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "Starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker vagrant  # Allow vagrant user to run docker

echo "Generating self-signed certs if not exist..."
mkdir -p /vagrant/traefik/certs
if [ ! -f /vagrant/traefik/certs/selfsigned.key ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /vagrant/traefik/certs/selfsigned.key -out /vagrant/traefik/certs/selfsigned.crt -subj "/CN=localhost"
fi

echo "Starting Docker Compose..."
cd /vagrant
docker compose up -d

echo "Setup complete. Access services via VM's bridged IP (check with 'ip addr show')."
