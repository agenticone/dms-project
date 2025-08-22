# Use the official Keycloak image as a base
FROM quay.io/keycloak/keycloak:25.0.4

# Switch to root user to install packages
USER root

# Install curl using microdnf (the package manager for ubi-minimal)
# and clean up the cache to keep the image small
RUN microdnf install -y curl && microdnf clean all

# Switch back to the default keycloak user
USER keycloak
