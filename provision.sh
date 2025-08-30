#!/bin/bash

set -e

# Determine the project root directory (where this script is located)
# and change the current directory to it. This makes all paths relative.
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$PROJECT_ROOT"

# Load environment variables from .env file in the project root
# Check for a vagrant-specific file first.
set -a
if [ -f ./.env.vagrant ]; then
  echo "Loading Vagrant environment variables from ./.env.vagrant..."
  source ./.env.vagrant
else
  echo "Loading default environment variables from ./.env..."
  [ -f ./.env ] && source ./.env
fi
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
# If the 'vagrant' user exists, add it to the docker group.
if id "vagrant" &>/dev/null; then
    echo "Adding vagrant user to docker group..."
    sudo usermod -aG docker vagrant
fi

echo "Preparing Traefik certificate storage..."
mkdir -p ./traefik/certs
# Create the acme.json file for Let's Encrypt certificates and set correct permissions
touch ./traefik/certs/acme.json
chmod 600 ./traefik/certs/acme.json

echo "Starting Docker Compose..."
# Run docker-compose as the vagrant user to ensure correct permissions on created files/volumes.
# The 'sg' command executes the command with the 'docker' group's permissions,
# which is necessary to communicate with the docker socket.
sg docker -c "docker compose up -d"

echo "Setup complete."
if id "vagrant" &>/dev/null; then
    echo "Vagrant setup complete. Access services via VM's bridged IP (check with 'ip addr show')."
else
    echo "Deployment complete. Access services via your configured hostnames."
fi
