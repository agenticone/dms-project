#!/bin/bash
set -e

# This script is executed by the postgres container on startup.
# It uses psql variables (-v) to safely pass passwords, avoiding issues with special characters.
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$POSTGRES_DB" \
     -v keycloak_password="$KEYCLOAK_DB_PASSWORD" \
     -v jbpm_password="$JBPM_DB_PASSWORD" \
     <<-EOSQL
    CREATE USER keycloak WITH PASSWORD :'keycloak_password';
    CREATE DATABASE keycloak WITH OWNER = keycloak;

    CREATE USER jbpm WITH PASSWORD :'jbpm_password';
    CREATE DATABASE jbpm WITH OWNER = jbpm;
EOSQL
