#!/bin/bash
set -e

# Build script for minio-client-tools container image
# Usage: ./build.sh [--push] [IMAGE_NAME:TAG]

IMAGE_NAME="${1:-minio-client-tools:latest}"
PUSH=false

# Check for --push flag
if [[ "$1" == "--push" ]]; then
    PUSH=true
    IMAGE_NAME="${2:-minio-client-tools:latest}"
fi

echo "Building container image: ${IMAGE_NAME}"
echo "======================================="

# Build the image
# Note: Building for linux/amd64 explicitly for compatibility
podman build \
    --format docker \
    --platform linux/amd64 \
    --build-arg WAIT_FOR_PORT_VERSION=1.0.7 \
    --build-arg MINIO_CLIENT_VERSION=RELEASE.2024-10-08T09-37-26Z \
    -t "${IMAGE_NAME}" \
    .

echo ""
echo "Build completed successfully!"
echo "Image: ${IMAGE_NAME}"

# Test the image
echo ""
echo "Testing the image..."
echo "======================================="

echo "Checking container can start..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" /bin/bash -c "echo 'Container started successfully'"

echo ""
echo "Checking wait-for-port..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" /bin/bash -c "wait-for-port --help || true" | head -5

echo ""
echo "Checking minio client..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" mc --version

echo ""
echo "All tests passed!"

# Push if requested
if [ "$PUSH" = true ]; then
    echo ""
    echo "Pushing image to registry..."
    echo "======================================="
    podman push "${IMAGE_NAME}"
    echo "Image pushed successfully!"
fi

echo ""
echo "To use the image:"
echo "  podman run -it --rm ${IMAGE_NAME} bash"
echo ""
echo "To push the image:"
echo "  podman push ${IMAGE_NAME}"

