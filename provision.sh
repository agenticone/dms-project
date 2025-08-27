#!/bin/bash

set -e

# Load environment variables from .env file in the /vagrant directory
set -a
[ -f /vagrant/.env ] && source /vagrant/.env
set +a

echo "Updating system..."
sudo apt-get update -y

echo "Installing prerequisites..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release openssl

echo "Configuring firewall..."
sudo apt-get install -y ufw
sudo ufw allow ssh       # Allow SSH connections
sudo ufw allow http      # Allow HTTP on port 80
sudo ufw allow https     # Allow HTTPS on port 443
sudo ufw --force enable  # Enable the firewall

echo "Installing Docker..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "Starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker vagrant  # Allow vagrant user to run docker

echo "Preparing Traefik certificate storage..."
mkdir -p /vagrant/traefik/certs
# Create the acme.json file for Let's Encrypt certificates and set correct permissions
touch /vagrant/traefik/certs/acme.json
chmod 600 /vagrant/traefik/certs/acme.json

echo "Starting Docker Compose..."
cd /vagrant
# Run docker-compose as the vagrant user to ensure correct permissions on created files/volumes.
# The 'sg' command executes the command with the 'docker' group's permissions,
# ensuring it works even if the user's main shell session hasn't been refreshed.
sg docker -c "docker compose up -d"

echo "Setup complete. Access services via VM's bridged IP (check with 'ip addr show')."
