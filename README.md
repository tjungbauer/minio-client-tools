# MinIO Client Tools Container Image

This container image provides the MinIO Client (`mc`) and Bitnami's `wait-for-port` utility in a Red Hat UBI9-based image, optimized for OpenShift clusters.

## Components

- **Base Image**: Red Hat Universal Base Image 9 (UBI9) Minimal
- **MinIO Client (mc)**: Command-line tool for managing MinIO and S3-compatible storage
- **wait-for-port**: Utility for waiting until a TCP port becomes available

## Features

- ✅ OpenShift compatible (supports arbitrary user IDs)
- ✅ Non-root user execution
- ✅ Minimal attack surface (ubi-minimal base)
- ✅ Proper group permissions for OpenShift security constraints

## Building the Image

### Quick Build (Recommended)

Use the provided build script:

```bash
./build.sh
```

Or specify a custom image name:

```bash
./build.sh minio-client-tools:v1.0.1
```

### Manual Build

```bash
podman build --platform linux/amd64 -t minio-client-tools:latest .
```

**Important for macOS Users**: Always use `--platform linux/amd64` to ensure compatibility with OpenShift/Kubernetes clusters and avoid Rosetta emulation issues.

### Build Arguments

You can customize the versions of the tools during build:

```bash
podman build \
  --platform linux/amd64 \
  --build-arg WAIT_FOR_PORT_VERSION=1.0.7 \
  --build-arg MINIO_CLIENT_VERSION=RELEASE.2024-10-08T09-37-26Z \
  -t minio-client-tools:latest .
```

### Testing the Image

After building, run the test script to verify everything works:

```bash
./test.sh
```

## Usage Examples

### 1. Wait for MinIO Service and Configure

```bash
podman run --rm minio-client-tools:latest sh -c "
  wait-for-port --host=minio.example.com --port=9000 --timeout=60 && \
  mc alias set myminio https://minio.example.com access-key secret-key && \
  mc mb myminio/mybucket
"
```

### 2. Use in OpenShift/Kubernetes as Init Container

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  initContainers:
  - name: wait-for-minio
    image: minio-client-tools:latest
    command:
    - /bin/bash
    - -c
    - |
      wait-for-port --host=minio-service --port=9000 --timeout=300
      echo "MinIO is ready!"
  containers:
  - name: main-app
    image: your-app:latest
```

### 3. Configure MinIO Buckets in a Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: minio-setup
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: minio-setup
        image: minio-client-tools:latest
        command:
        - /bin/bash
        - -c
        - |
          # Wait for MinIO to be available
          wait-for-port --host=minio --port=9000 --timeout=120
          
          # Configure MinIO client
          mc alias set myminio http://minio:9000 ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}
          
          # Create buckets
          mc mb myminio/data || true
          mc mb myminio/backups || true
          
          # Set bucket policies
          mc anonymous set download myminio/data
          
          echo "MinIO setup complete!"
        env:
        - name: MINIO_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: accesskey
        - name: MINIO_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: secretkey
```

### 4. Interactive Shell

```bash
podman run -it --rm minio-client-tools:latest bash
```

Then inside the container:
```bash
# Check if a service is available
wait-for-port --host=example.com --port=9000 --timeout=30

# Use MinIO client
mc --help
mc alias set myalias https://minio.example.com accesskey secretkey
mc ls myalias
```

## Available Commands

### wait-for-port

Wait for a TCP port to become available:

```bash
wait-for-port --host=hostname --port=9000 --timeout=60
```

Options:
- `--host`: Target hostname or IP address
- `--port`: Target port number
- `--timeout`: Maximum time to wait in seconds (default: 60)

### mc (MinIO Client)

Full-featured client for MinIO and S3-compatible storage:

```bash
# Add a MinIO alias
mc alias set myalias http://minio:9000 accesskey secretkey

# List buckets
mc ls myalias

# Create a bucket
mc mb myalias/mybucket

# Copy files
mc cp local-file.txt myalias/mybucket/

# Mirror directories
mc mirror /local/path myalias/mybucket/path

# Set bucket policy
mc anonymous set download myalias/mybucket
```

For more commands, see: https://min.io/docs/minio/linux/reference/minio-mc.html

## OpenShift Considerations

This image is designed to work with OpenShift's security constraints:

1. **Arbitrary User IDs**: OpenShift assigns random user IDs. This image handles this through proper group permissions.
2. **Non-root**: Runs as user ID 1001 by default, but works with any UID.
3. **Read-only Root Filesystem**: Can run with `readOnlyRootFilesystem: true` if you mount a writable volume at `/home/minio/.mc`

Example with SecurityContext:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: minio-tools
spec:
  containers:
  - name: minio-tools
    image: minio-client-tools:latest
    securityContext:
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: mc-config
      mountPath: /home/minio/.mc
  volumes:
  - name: mc-config
    emptyDir: {}
```

## Environment Variables

- `HOME`: Set to `/home/minio` (MinIO client config location)
- `PATH`: Includes `/usr/local/bin` for easy access to tools

## Volume Mounts

If you need to persist MinIO client configuration:

```bash
podman run -v mc-config:/home/minio/.mc minio-client-tools:latest
```

## Troubleshooting

### Container Stops Immediately

If the container exits immediately, check:

1. **Bash is installed**: The image requires bash. This should be included in the build.
2. **Entrypoint is executable**: Verify with `podman run --rm minio-client-tools:latest /bin/bash -c "echo test"`
3. **Platform compatibility**: Ensure you built with `--platform linux/amd64`

### Rosetta Error on macOS (Apple Silicon)

If you see errors like `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2`:

**Solution**: Rebuild the image with explicit platform specification:

```bash
podman build --platform linux/amd64 -t minio-client-tools:latest .
# or use the build script which does this automatically
./build.sh
```

This ensures the image is built for x86_64 architecture, which is what Kubernetes/OpenShift clusters typically use.

### Testing on macOS

When running locally on macOS for testing:

```bash
# Always specify the platform when running
podman run --platform linux/amd64 --rm minio-client-tools:latest bash -c "mc --version"
```

### Permission Denied Errors in OpenShift

If you encounter permission errors in OpenShift, ensure your SecurityContextConstraint allows the container to run:

```bash
oc adm policy add-scc-to-user anyuid -z default
```

Or better, use the `restricted` SCC (which this image supports):

```bash
oc adm policy add-scc-to-user restricted -z default
```

### MinIO Client Configuration

The MinIO client stores its configuration in `~/.mc/`. If running with a read-only filesystem, mount a writable volume there.

### Debugging

To debug issues, run an interactive shell:

```bash
podman run -it --rm minio-client-tools:latest /bin/bash
```

Then inside the container:
```bash
# Check user
id

# Check if tools are available
which mc
which wait-for-port

# Test the tools
mc --version
wait-for-port --help
```

## License

This Dockerfile and associated scripts are provided as-is. The included software components have their own licenses:
- MinIO Client: GNU AGPLv3
- wait-for-port: Apache License 2.0
- Red Hat UBI: Red Hat Universal Base Image EULA

