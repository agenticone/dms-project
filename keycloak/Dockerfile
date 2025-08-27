# Stage 1: Builder
# This stage adds the JDBC driver and runs the Keycloak build process to create an optimized server image.
FROM quay.io/keycloak/keycloak:25.0.1 as builder

# Set environment variables for the build
ENV KC_DB=postgres

# Copy the PostgreSQL JDBC driver from the build context into the providers directory.
# You must download this JAR file and place it in the same directory as this Dockerfile.
RUN echo "--- Verifying JDBC driver in build context ---" && ls -l postgresql-42.7.3.jar || (echo "ERROR: PostgreSQL JDBC driver (postgresql-42.7.3.jar) not found. Please download it and place it in the 'keycloak' directory." && exit 1)
COPY --chown=keycloak:keycloak postgresql-42.7.3.jar /opt/keycloak/providers/

RUN echo "--- Verifying JDBC driver was copied to providers directory ---" && ls -l /opt/keycloak/providers/

# Run the build command. This packages the provider into the server runtime and creates an optimized build.
RUN echo "--- Starting Keycloak build process ---"
RUN /opt/keycloak/bin/kc.sh build
RUN echo "--- Keycloak build process finished ---"

# Stage 2: Final image
# This stage creates the final, lean image by copying the optimized server from the builder.
FROM quay.io/keycloak/keycloak:25.0.1

# Copy the pre-built and optimized server from the builder stage.
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# The entrypoint will be inherited from the base image.
# The command to start the server is specified in the docker-compose.yml file.