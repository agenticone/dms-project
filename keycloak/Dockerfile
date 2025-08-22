# Stage 1: Builder
# Use a full UBI 9 image that includes dnf and other tools
FROM registry.access.redhat.com/ubi9/ubi:9.4 AS builder

# Create directories for the binary and its libraries
RUN mkdir -p /curl_dist/bin /curl_dist/libs

# Copy the curl binary
RUN cp /usr/bin/curl /curl_dist/bin/

# Identify and copy all shared library dependencies of curl into a flat directory
RUN ldd /usr/bin/curl | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' /curl_dist/libs/

# Stage 2: Final Image
# Use the official, minimal Keycloak image
FROM quay.io/keycloak/keycloak:25.0.4

# Switch to root user to install packages
USER root

# Create destination directories and copy the curl binary and all its libraries from the builder stage
RUN mkdir -p /usr/bin /usr/lib64
COPY --from=builder /curl_dist/bin/curl /usr/bin/
COPY --from=builder /curl_dist/libs/* /usr/lib64/

# Switch back to the default keycloak user
USER keycloak
