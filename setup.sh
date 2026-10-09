#!/bin/bash

until curl -fs http://localhost:9000/minio/health/live >/dev/null 2>&1
do
  sleep 2
done

/opt/minio/mc alias set myminio http://localhost:9000 admin password
/opt/minio/mc mb myminio/warehouse || true