FROM ubuntu:22.04

LABEL maintainer="Preetam R"
LABEL version="1.0.0-beta.1"
LABEL description="MicroLakehouse - Single-node Spark, Trino, MinIO, and Iceberg playground"
LABEL spark_version="3.5.1"
LABEL trino_version="440"
LABEL iceberg_version="1.5.0"

ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies
RUN apt-get update && apt-get install -y \
    wget curl unzip postgresql postgresql-contrib supervisor \
    openjdk-17-jdk python3 python3-pip software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Jupyter
RUN pip3 install jupyterlab pyspark==3.5.1 psycopg2-binary

ENV SPARK_HOME=/opt/spark
ENV TRINO_HOME=/opt/trino
ENV MINIO_HOME=/opt/minio
ENV PATH=$PATH:$SPARK_HOME/bin:$TRINO_HOME/bin:$MINIO_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Install MinIO
RUN mkdir -p /opt/minio && \
    wget -q https://dl.min.io/server/minio/release/linux-amd64/minio -O /opt/minio/minio && \
    chmod +x /opt/minio/minio && \
    wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /opt/minio/mc && \
    chmod +x /opt/minio/mc

# Install Trino
ARG TRINO_VERSION=440
RUN wget -q https://repo1.maven.org/maven2/io/trino/trino-server/${TRINO_VERSION}/trino-server-${TRINO_VERSION}.tar.gz && \
    tar -xzf trino-server-${TRINO_VERSION}.tar.gz && \
    mv trino-server-${TRINO_VERSION} /opt/trino && \
    rm trino-server-${TRINO_VERSION}.tar.gz && \
    wget -q https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar -O /opt/trino/bin/trino && \
    chmod +x /opt/trino/bin/trino

# Install Spark
ARG SPARK_VERSION=3.5.1
RUN wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop3 /opt/spark && \
    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Add Iceberg and PostgreSQL dependencies
ARG ICEBERG_VERSION=1.5.0
RUN wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar -P /opt/spark/jars/ && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar -P /opt/spark/jars/ && \
    wget -q https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar -P /opt/spark/jars/ && \
    wget -q https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar -P /opt/trino/plugin/iceberg/

# Setup PostgreSQL DB for JDBC catalog
RUN /etc/init.d/postgresql start && \
    su - postgres -c "psql -c \"CREATE USER iceberg WITH PASSWORD 'iceberg';\"" && \
    su - postgres -c "psql -c \"CREATE DATABASE iceberg OWNER iceberg;\"" && \
    /etc/init.d/postgresql stop

# Copy configurations
COPY trino-config /opt/trino/etc
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

# Setup Jupyter Workspace
RUN mkdir -p /workspace
COPY jupyter-config/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
COPY Example_Notebook.ipynb /workspace/Example_Notebook.ipynb

# Working directory
WORKDIR /workspace

# Expose ports
# 8888 - JupyterLab
# 8080 - Trino
# 9000 - MinIO API, 9001 - MinIO Console
# 4040 - Spark UI
EXPOSE 8888 8080 9000 9001 4040

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
