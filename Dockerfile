FROM ubuntu:16.04

ENV hadoop=3.2.0
ENV hive=4.0.0-alpha-1

USER root

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y software-properties-common && \
  apt-get update && add-apt-repository ppa:openjdk-r/ppa && \
  apt-get update && apt-get install -y \
  curl \
  tar \
  iputils-ping \
  krb5-user \
  libssl-dev:amd64 \
  openjdk-8-jdk \
  openssh-server \
  openssh-client \
  vim \
  sudo \
  lsof \
  man

# Setting up system users & groups
RUN groupadd -r supergroup && \
  groupadd -r hdfs && \
  useradd -r -m -s /bin/bash -g supergroup hdfs && \
  usermod -a -G hdfs hdfs && \
  sed -i -e 's/%sudo\s\+ALL=(ALL:ALL)\s\+ALL/%sudo ALL=(ALL) NOPASSWD:ALL/g' /etc/sudoers

# SSH
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Download jars and set up directory
RUN curl -s https://archive.apache.org/dist/hadoop/common/hadoop-$hadoop/hadoop-$hadoop.tar.gz \
  | tar -xz -C /opt
RUN cd /opt && ln -s ./hadoop-$hadoop hadoop

# Environment variables
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_PREFIX /opt/hadoop
ENV HADOOP_HOME /opt/hadoop
ENV HADOOP_COMMON_HOME /opt/hadoop
ENV HADOOP_HDFS_HOME /opt/hadoop
ENV HADOOP_CONF_DIR /opt/hadoop/etc/hadoop

ENV PATH $HADOOP_HOME/bin:$PATH

RUN apt-get update && \
  apt-get install -y postgresql && \
  apt-get install -y libpostgresql-jdbc-java && \
  apt-get install -y lsof man

# Setting up system users & groups
RUN groupadd -r hive && \
  useradd -r -m -s /bin/bash -g supergroup hive && \
  usermod -a -G hdfs hive && \
  usermod -a -G hive hive

# Download jars and set up directory
RUN curl -s https://people.apache.org/~pvary/apache-hive-4.0.0-alpha-1-rc2/apache-hive-4.0.0-alpha-1-bin.tar.gz \
  | tar -xz -C /opt
RUN cd /opt && ln -s ./apache-hive-$hive-bin hive

ENV HIVE_HOME /opt/hive
ENV HIVE_CONF_DIR $HIVE_HOME/conf
ENV PATH $HIVE_HOME/bin:$PATH

# RUN sed -i -e s/HOSTNAME/hdfs-box/ $HADOOP_HOME/etc/hadoop/core-site.xml

ADD etc/hive-site.xml $HIVE_CONF_DIR
ADD etc/hive-log4j.properties $HIVE_CONF_DIR
ADD etc/log4j.properties $HIVE_CONF_DIR

# Download Postgres client jar
RUN curl -s https://github.com/szehon-ho/dev-env/blob/hive-4.0.0/postgresql-9.4.1209.jre7.jar -o \
  $HIVE_HOME/lib/postgresql-9.4.1209.jre7.jar

USER postgres

ENV PGPASSWORD "hive"

# Initialize hive metastore db
RUN cd $HIVE_HOME/scripts/metastore/upgrade/postgres/ && \
  /etc/init.d/postgresql start && \
  psql --command "CREATE DATABASE metastore;" && \
  psql --command "CREATE USER hive WITH PASSWORD 'hive';" && \
  psql --command "ALTER USER hive WITH SUPERUSER;" && \
  psql --command "GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;"
  # && \
#  psql -U hive -d metastore --no-password -h localhost -f hive-schema-2.3.0.postgres.sql

USER root

COPY bootstrap_hive.sh /etc/bootstrap_hive.sh
RUN chmod 700 /etc/bootstrap_hive.sh
COPY wait-for-it.sh /etc/wait-for-it.sh
RUN chmod 700 /etc/wait-for-it.sh

RUN /etc/bootstrap_hive.sh
ENTRYPOINT ["/bin/bash"]

EXPOSE 9083 10000 10002 50111