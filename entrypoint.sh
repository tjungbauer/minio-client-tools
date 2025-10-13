#!/bin/bash
set -e

# This entrypoint script handles OpenShift's arbitrary user ID assignment
# It ensures the current user has proper /etc/passwd entry

# If running with an arbitrary UID (OpenShift), update /etc/passwd
if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "minio:x:$(id -u):0:MinIO Client User:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi

# Execute the provided command or default to bash
exec "$@"

