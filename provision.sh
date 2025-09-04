#!/bin/bash

set -e

# Determine the project root directory. When run via Vagrant, scripts are
# uploaded to a temp path, so prefer the synced folder at /vagrant if present.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -d /vagrant ] && [ -f /vagrant/docker-compose.yml ]; then
  PROJECT_ROOT="/vagrant"
else
  PROJECT_ROOT="$SCRIPT_DIR"
fi
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

echo "Waiting for network connectivity..."
# Wait for default route to appear
tries=0
until ip route | grep -q '^default '; do
  tries=$((tries+1))
  if [ "$tries" -ge 60 ]; then
    echo "No default route after 120s. Network state:"
    ip addr || true
    ip route || true
    systemctl status systemd-networkd || true
    break
  fi
  sleep 2
done

# Wait for DNS resolution to work for key hosts
for host in archive.ubuntu.com download.docker.com registry-1.docker.io; do
  dns_tries=0
  until getent hosts "$host" >/dev/null 2>&1; do
    dns_tries=$((dns_tries+1))
    if [ "$dns_tries" -ge 60 ]; then
      echo "DNS lookup for $host failed after 120s. Resolver status:"
      command -v systemd-resolve >/dev/null && systemd-resolve --status || true
      break
    fi
    sleep 2
  done
done

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
# Import Docker's GPG key in non-interactive mode and ensure world-readable
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker's apt repository and refresh package lists
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
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
# Resolve compose file and run as 'vagrant' with docker group permissions.
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
  if [ -f "$PROJECT_ROOT/compose.yml" ]; then
    COMPOSE_FILE="$PROJECT_ROOT/compose.yml"
  else
    echo "Docker Compose configuration not found in $PROJECT_ROOT"
    ls -la "$PROJECT_ROOT" || true
    exit 1
  fi
fi

# Use sg to ensure access to the Docker socket even before newgrp applies.
if id "vagrant" &>/dev/null; then
  sudo -u vagrant sg docker -c "docker compose --project-directory '$PROJECT_ROOT' -f '$COMPOSE_FILE' up -d"
else
  sg docker -c "docker compose --project-directory '$PROJECT_ROOT' -f '$COMPOSE_FILE' up -d"
fi

echo "Setup complete."
if id "vagrant" &>/dev/null; then
    echo "Vagrant setup complete. Access services via VM's bridged IP (check with 'ip addr show')."
else
    echo "Deployment complete. Access services via your configured hostnames."
fi
