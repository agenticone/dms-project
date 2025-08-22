#!/bin/bash
set -e

# This script is executed by the postgres container on startup.
# It uses environment variables to create the users and databases.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
    CREATE DATABASE keycloak;
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

    CREATE USER jbpm WITH PASSWORD '${JBPM_DB_PASSWORD}';
    CREATE DATABASE jbpm;
    GRANT ALL PRIVILEGES ON DATABASE jbpm TO jbpm;
EOSQL
