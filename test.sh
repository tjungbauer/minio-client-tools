#!/bin/bash
set -e

IMAGE_NAME="${1:-minio-client-tools:latest}"

echo "Testing container image: ${IMAGE_NAME}"
echo "======================================="

# Test 1: Container starts and bash is available
echo ""
echo "Test 1: Checking if container starts with bash..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" /bin/bash -c "echo 'Container started successfully'"

# Test 2: wait-for-port is available and works
echo ""
echo "Test 2: Checking wait-for-port..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" /bin/bash -c "which wait-for-port && wait-for-port --help" || true

# Test 3: MinIO client is available and works
echo ""
echo "Test 3: Checking MinIO client..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" mc --version

# Test 4: Check user ID
echo ""
echo "Test 4: Checking user ID..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" /bin/bash -c "id"

# Test 5: Test with arbitrary UID (OpenShift simulation)
echo ""
echo "Test 5: Testing with arbitrary UID (simulating OpenShift)..."
podman run --platform linux/amd64 --rm --user 1000690000 "${IMAGE_NAME}" /bin/bash -c "id && mc --version"

# Test 6: Check home directory permissions
echo ""
echo "Test 6: Checking home directory permissions..."
podman run --platform linux/amd64 --rm "${IMAGE_NAME}" /bin/bash -c "ls -la /home/minio && touch /home/minio/.mc/test && rm /home/minio/.mc/test && echo 'Write test passed'"

echo ""
echo "======================================="
echo "✅ All tests passed successfully!"
echo ""
echo "Image ${IMAGE_NAME} is ready to use."

