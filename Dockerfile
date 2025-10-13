# Multi-stage build for minio-client and wait-for-port
# Stage 1: Download wait-for-port
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6-1758184547 AS wait-for-port-downloader

ARG WAIT_FOR_PORT_VERSION=1.0.7

RUN microdnf install -y wget tar gzip && \
    microdnf clean all

RUN wget https://github.com/bitnami/wait-for-port/releases/download/v${WAIT_FOR_PORT_VERSION}/wait-for-port-linux-amd64.tar.gz && \
    tar -xzf wait-for-port-linux-amd64.tar.gz && \
    chmod +x wait-for-port-linux-amd64

# Stage 2: Download minio client
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6-1758184547 AS minio-client-downloader

ARG MINIO_CLIENT_VERSION=RELEASE.2024-10-08T09-37-26Z

RUN microdnf install -y wget && \
    microdnf clean all

RUN wget https://dl.min.io/client/mc/release/linux-amd64/archive/mc.${MINIO_CLIENT_VERSION} -O mc && \
    chmod +x mc

# Final stage: Create the runtime image
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6-1758184547

LABEL name="minio-client-tools" \
      vendor="Custom" \
      version="1.0.0" \
      summary="MinIO Client and wait-for-port utility for OpenShift" \
      description="This image contains the MinIO client (mc) and Bitnami's wait-for-port utility, \
                   optimized for running on OpenShift clusters with arbitrary user IDs."

# Install required dependencies including bash and glibc
RUN microdnf install -y \
    ca-certificates \
    shadow-utils \
    bash \
    glibc \
    && microdnf clean all

# Copy binaries from build stages
COPY --from=wait-for-port-downloader /wait-for-port-linux-amd64 /usr/local/bin/wait-for-port
COPY --from=minio-client-downloader /mc /usr/local/bin/mc

# Create a user and set up directories with proper permissions for OpenShift
# OpenShift runs containers with random UIDs, so we need to ensure group permissions are set correctly
RUN useradd -u 1001 -r -g 0 -d /home/minio -s /sbin/nologin \
    -c "MinIO Client User" minio && \
    mkdir -p /home/minio/.mc && \
    chown -R 1001:0 /home/minio && \
    chmod -R g=u /home/minio && \
    chmod -R g=u /etc/passwd

# Set up environment
ENV HOME=/home/minio \
    PATH=/usr/local/bin:$PATH

WORKDIR /home/minio

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown 1001:0 /usr/local/bin/entrypoint.sh

# Ensure the user can write to necessary directories
RUN chmod g+w /home/minio && \
    chmod -R g+w /home/minio/.mc

# Switch to non-root user
USER 1001

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]

