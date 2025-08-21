#!/bin/bash
set -e

# Copy custom LDIF to ensure correct permissions
cp /vagrant/openldap/init.ldif /container/service/slapd/assets/config/bootstrap/ldif/custom/init.ldif
chown openldap:openldap /container/service/slapd/assets/config/bootstrap/ldif/custom/init.ldif

# Skip problematic sed operations by overriding replication and password change
echo "Skipping replication-disable and root-password-change LDIF processing"

# Set environment variables to disable replication explicitly
export LDAP_NO_REPLICATION=true

# Run slapd directly
exec /container/run/process/slapd/run