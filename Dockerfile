FROM minio/minio:latest AS minio
FROM minio/mc:latest AS mc

FROM ubuntu:22.04

LABEL maintainer="Preetam R"
LABEL version="1.0.0-beta.2"
LABEL description="MicroLakehouse - Single-node Spark, Trino, MinIO, and Iceberg playground"
LABEL spark_version="3.5.1"
LABEL trino_version="440"
LABEL iceberg_version="1.5.0"

ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    unzip \
    file \
    supervisor \
    ca-certificates \
    software-properties-common \
    postgresql \
    postgresql-contrib \
    openjdk-21-jdk \
    python3 \
    python3-pip \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip3 install --no-cache-dir --upgrade pip

# Install Jupyter + PySpark
RUN pip3 install --no-cache-dir \
    jupyterlab \
    pyspark==3.5.1 \
    psycopg2-binary

ENV SPARK_HOME=/opt/spark
ENV TRINO_HOME=/opt/trino
ENV MINIO_HOME=/opt/minio
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

ENV AWS_REGION=us-east-1
ENV AWS_ACCESS_KEY_ID=admin
ENV AWS_SECRET_ACCESS_KEY=password

ENV PATH=$PATH:$SPARK_HOME/bin:$TRINO_HOME/bin:$MINIO_HOME

# --------------------------------------------------------------------
# MinIO
# --------------------------------------------------------------------
RUN mkdir -p /opt/minio /data

COPY --from=minio /usr/bin/minio /opt/minio/minio
COPY --from=mc /usr/bin/mc /opt/minio/mc

RUN chmod +x /opt/minio/minio /opt/minio/mc

# Verify binaries during build
RUN /opt/minio/minio --help >/dev/null
RUN /opt/minio/mc --help >/dev/null

# --------------------------------------------------------------------
# Trino
# --------------------------------------------------------------------
ARG TRINO_VERSION=440

COPY --from=trinodb/trino:440 /usr/lib/trino /opt/trino
COPY --from=trinodb/trino:440 /usr/bin/trino /opt/trino/bin/trino

# --------------------------------------------------------------------
# Spark
# --------------------------------------------------------------------
ARG SPARK_VERSION=3.5.1

RUN curl -sSLf \
    https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz \
    -o spark.tgz && \
    tar -xzf spark.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop3 /opt/spark && \
    rm -f spark.tgz

# --------------------------------------------------------------------
# Iceberg
# --------------------------------------------------------------------
ARG ICEBERG_VERSION=1.5.0

RUN curl -sSLf \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar \
    -o /opt/spark/jars/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar && \
    curl -sSLf \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar \
    -o /opt/spark/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar && \
    curl -sSLf \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar \
    -o /opt/spark/jars/postgresql-42.7.3.jar && \
    mkdir -p /opt/trino/plugin/iceberg && \
    cp /opt/spark/jars/postgresql-42.7.3.jar /opt/trino/plugin/iceberg/

# --------------------------------------------------------------------
# PostgreSQL setup
# --------------------------------------------------------------------
RUN service postgresql start && \
    su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='iceberg'\" | grep -q 1 || psql -c \"CREATE USER iceberg WITH PASSWORD 'iceberg';\"" && \
    su - postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw iceberg || psql -c \"CREATE DATABASE iceberg OWNER iceberg;\"" && \
    service postgresql stop

# --------------------------------------------------------------------
# Configs
# --------------------------------------------------------------------
COPY trino-config /opt/trino/etc
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

# --------------------------------------------------------------------
# Workspace
# --------------------------------------------------------------------
RUN mkdir -p /workspace

COPY jupyter-config/spark-defaults.conf \
    /opt/spark/conf/spark-defaults.conf

COPY Example_Notebook.ipynb \
    /workspace/Example_Notebook.ipynb

WORKDIR /workspace

# --------------------------------------------------------------------
# Ports
# --------------------------------------------------------------------
EXPOSE 8888
EXPOSE 8080
EXPOSE 9000
EXPOSE 9001
EXPOSE 4040

ENTRYPOINT ["/usr/bin/supervisord","-c","/etc/supervisor/conf.d/supervisord.conf"]