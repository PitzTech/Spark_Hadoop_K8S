FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

RUN apt-get install -y openjdk-8-jdk

# Definir o JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

RUN apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository universe && \
    apt-get update

COPY /config/jupyter/requirements.txt /

# Ajustes e instalaç?o dos componentes do cluster
RUN apt-get install -y wget vim ssh openssh-server curl iputils-ping nano sudo \
    python3 python3-pip python3-dev \
    build-essential libssl-dev libffi-dev libpq-dev mariadb-server libmariadb-java \
    texlive-xetex texlive-fonts-recommended texlive-plain-generic
RUN python3 -m pip install -r requirements.txt
RUN python3 -m pip install dask[bag] --upgrade
RUN python3 -m pip install --upgrade toree
RUN python3 -m pip install seaborn
RUN python3 -m bash_kernel.install
RUN python3 -c "import nltk; nltk.download('stopwords')"
RUN mkdir datasets

# Keys dos nodes. Necessarias para se comunicarem por SSH
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys
COPY /config/config /root/.ssh
RUN chmod 600 /root/.ssh/config

# Variaveis de ambiente do Hadoop
ENV HADOOP_VERSION=3.4.0
ENV HADOOP_MINOR_VERSION=3
ENV HADOOP_HOME=/usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV HDFS_NAMENODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV HDFS_DATANODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root

# Variaveis de ambiente do Spark
ENV SPARK_VERSION=3.5.0
ENV SPARK_HOME=/usr/spark-${SPARK_VERSION}
ENV SPARK_CONF_DIR=$SPARK_HOME/conf
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"

# Configuracoes do pyspark
ENV PYSPARK_PYTHON=python3

# Usar python3 para modo cluster, e jupyter + configuracao de PYSPARK_DRIVER_PYTHON_OPTS='notebook'
# para modo interativo
ENV PYSPARK_DRIVER_PYTHON=python3
# ENV PYSPARK_DRIVER_PYTHON=jupyter
# ENV PYSPARK_DRIVER_PYTHON_OPTS='notebook'

# Adicao de valores aos paths abaixo para que os componentes os localizem
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip:/usr/bin/python3
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$SPARK_HOME/bin:$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip:$PYTHONPATH

#  Instalaç?o do Hadoop
    # && wget \
    # "http://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
COPY bin/hadoop-${HADOOP_VERSION}.tar.gz .
RUN tar zvxf hadoop-${HADOOP_VERSION}.tar.gz -C /usr/ \
    && rm hadoop-${HADOOP_VERSION}.tar.gz \
    && rm -rf ${HADOOP_HOME}/share/doc \
    && chown -R root:root ${HADOOP_HOME} \
    && echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

# Instalaç?o do Spark
    #&& wget \
    #"http://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz" \
COPY bin/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz .
RUN mkdir ${SPARK_HOME} \
    && tar zvxf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}/* ${SPARK_HOME} \
    && rm -r spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION} \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz \
    && chown -R root:root ${SPARK_HOME}

# Todos os arquivos de configuracao que devem ser copiados para dentro do
# container estao aqui
COPY config/hadoop/*.xml /usr/hadoop-${HADOOP_VERSION}/etc/hadoop/
COPY config/spark ${SPARK_HOME}/conf/
COPY config/scripts /

# Portas Hadoop e Spark
EXPOSE 9000 4040 8020 22 9083  9870

# Algumas configuracoes adicionais e inicio de alguns servicoes que devem ser feitos em
# tempo de execucao estao presentes no script bootstrap.
# Este cuidará de colocar alguns datasets exemplo dentro do HDFS, bem como de iniciar
# servicos do HDFS (formatando Namenode).
# O comando ENTRYPOINT define que este script será executado quando os containeres
# iniciarem.
ENTRYPOINT ["/bin/bash", "bootstrap.sh"]
