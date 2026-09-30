#!/bin/bash
# Wait for MinIO to become available
sleep 10
/opt/minio/mc alias set myminio http://localhost:9000 admin password
/opt/minio/mc mb myminio/warehouse || true
