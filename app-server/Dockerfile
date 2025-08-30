# Use a stable base image like Ubuntu 22.04 to install multiple runtimes
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=22
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Install essential tools, Java 17, and dependencies for Node.js installation
# This includes curl and other tools for debugging.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    openjdk-17-jdk \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js v22 using the official NodeSource repository
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up the application directory
WORKDIR /app

# Copy package.json and package-lock.json to leverage Docker layer caching
COPY package*.json ./

# Install Node.js dependencies, including the MongoDB driver
RUN npm install

# Copy the rest of the application source code
COPY . .

# Expose the port the app will run on
EXPOSE 3000

# Define the command to run the application.
# This starts the Node.js server. The Java runtime is available for any child processes.
CMD ["node", "server.js"]