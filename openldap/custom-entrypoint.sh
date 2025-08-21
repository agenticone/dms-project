#!/bin/bash
set -e

# Debug slapd startup
echo "Starting slapd with debug logging..."
/opt/bitnami/openldap/sbin/slapd -h "ldap://0.0.0.0:389 ldaps://0.0.0.0:636" -d 256 &

# Wait for slapd to be ready
echo "Waiting for slapd to be ready..."
for i in {1..60}; do
    if ldapsearch -x -H ldap://localhost:389 -b "" -s base -D "cn=admin,dc=dms,dc=local" -w "${LDAP_ADMIN_PASSWORD:-adminpassword}" > /dev/null 2>&1; then
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