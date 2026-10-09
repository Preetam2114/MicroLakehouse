# MicroLakehouse

This repository contains a complete, single-node Data Lakehouse stack running in a **single Docker container**. 
It includes:
- **JupyterLab** (with PySpark)
- **Apache Spark** (configured for Iceberg and MinIO)
- **Apache Trino** (configured to query Iceberg via JDBC catalog)
- **MinIO** (S3-compatible storage layer)
- **PostgreSQL** (Acting as the Iceberg JDBC catalog)

## How to Build

From this directory, run:

```bash
docker build -t pvr2114/microlakehouse:1.0.0-beta.1 .
docker tag pvr2114/microlakehouse:1.0.0-beta.1 pvr2114/microlakehouse:latest
```

## How to Run

```bash
docker run -d -p 8888:8888 -p 8080:8080 -p 9000:9000 -p 9001:9001 -p 4040:4040 pvr2114/microlakehouse:1.0.0-beta.1
```

## Ports

- `8888`: JupyterLab
- `8080`: Trino UI / Server
- `9000`: MinIO API
- `9001`: MinIO Console
- `4040`: Spark UI

## Accessing Services

1. **JupyterLab**: Go to [http://localhost:8888](http://localhost:8888). Open the `Example_Notebook.ipynb` to get started.
2. **MinIO Console**: Go to [http://localhost:9001](http://localhost:9001). Username: `admin`, Password: `password`.
3. **Trino CLI**: Run `docker exec -it <container_id> /opt/trino/bin/trino --server localhost:8080 --catalog lakehouse`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
