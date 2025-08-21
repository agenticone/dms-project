#!/bin/bash
set -e

# Debug slapd startup
echo "Starting slapd with debug logging..."
/opt/bitnami/openldap/sbin/slapd -h "ldap://0.0.0.0:389 ldaps://0.0.0.0:636" -d 256 &

# Wait for slapd to start
echo "Waiting for slapd to be ready..."
for i in {1..60}; do
    if nc -z localhost 389; then
        echo "slapd is ready on port 389"
        break
    fi
    sleep 1
done

# Verify slapd is running
if ! ps aux | grep -v grep | grep slapd > /dev/null; then
    echo "Error: slapd failed to start"
    exit 1
fi

# Keep container running
exec "$@"