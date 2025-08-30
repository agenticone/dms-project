# --- Stage 1: Builder ---
# Use a minimal, generic Linux image to prepare curl and its dependencies.
# Using a specific version of a small image like Fedora minimal for reproducibility.
# The fedora-minimal image is hosted on the official Fedora registry, not Docker Hub.
FROM registry.fedoraproject.org/fedora-minimal:39 AS builder

# Install curl and utilities needed to copy its dependencies.
# The fedora-minimal image uses 'microdnf' instead of the full 'dnf'.
RUN microdnf install -y curl findutils && microdnf clean all

# Create a staging directory for curl and its libraries, keeping them isolated.
RUN mkdir -p /tools/bin /tools/lib

# Copy the curl binary to our isolated tools directory.
RUN cp /usr/bin/curl /tools/bin/

# Find all of curl's shared library dependencies and copy them to our isolated lib directory.
RUN ldd /usr/bin/curl | grep '=> /' | awk '{print $3}' | xargs -I '{}' cp -v '{}' /tools/lib/

# --- Stage 2: Final Image ---
# Start from the official, minimal Keycloak image.
FROM quay.io/keycloak/keycloak:24.0.4 AS final

ARG PG_JDBC_VERSION
# Copy the PostgreSQL JDBC driver from the build context (the 'keycloak' directory)
COPY postgresql-${PG_JDBC_VERSION}.jar /opt/keycloak/providers/

# Switch to the root user to copy the files from the builder stage.
USER root
# Copy the isolated 'tools' directory containing curl and its libs.
# This does not interfere with the base image's system files.
COPY --from=builder /tools/ /tools/
USER keycloak
