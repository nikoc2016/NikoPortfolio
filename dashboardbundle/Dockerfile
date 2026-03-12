# Stage 1: Build Stage
FROM alpine:latest AS builder

# Install dependencies
RUN apk add --no-cache \
    bash \
    git \
    make \
    npm \
    nodejs \
    go \
    unzip \
    curl 

# Set the working directory to /app
WORKDIR /app

# Copy the repository contents to /app
COPY . .

# Use bash for the build process
RUN /bin/bash -c "make build"

# Stage 2: Final Stage
FROM alpine:latest

# Install screen, bash, and necessary libraries
RUN apk add --no-cache \
    screen \
    bash \
    libc6-compat

# GET COMPILED PROMETHEUS
COPY --from=builder /app/prometheus /bin/prometheus/prometheus

# EXTRACT DEVOPS FILES
COPY DEVOPS_FILES.tar.gz /tmp/DEVOPS_FILES.tar.gz
RUN mkdir -p /bin && \
    tar -xzf /tmp/DEVOPS_FILES.tar.gz -C /bin/ && \
    mv /bin/DEVOPS_FILES/grafana-artifact /bin/grafana/ && \
    mv /bin/DEVOPS_FILES/prometheus.yml /bin/prometheus/ && \
    mv /bin/DEVOPS_FILES/entrypoint.sh /entrypoint.sh && \
    rm -rf /tmp/DEVOPS_FILES.tar.gz /bin/DEVOPS_FILES && \
    chmod +x /bin/prometheus/prometheus /bin/grafana/bin/grafana /entrypoint.sh

# Expose ports
EXPOSE 9090 3000

# Set entrypoint and start commands
ENTRYPOINT ["/entrypoint.sh"]
