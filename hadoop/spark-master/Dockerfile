
FROM spark-base-hadoop:latest

ENV SPARK_MASTER="spark://spark-master:7077"
ENV SPARK_MASTER_HOST=spark-master
ENV SPARK_MASTER_PORT=7077
ENV SPARK_MASTER_WEBUI_PORT=8080
ENV SPARK_MASTER_LOG=/opt/spark/logs
#ENV SPARK_LOCAL_IP=localhost

COPY config/hadoop/masters $HADOOP_HOME/conf/
COPY config/hadoop/masters $HADOOP_HOME/etc/hadoop/
COPY config/hadoop/workers $HADOOP_HOME/conf/
COPY config/hadoop/workers $HADOOP_HOME/etc/hadoop/

RUN pip install "fastapi[all]"

EXPOSE 8080 7077 6066 7001 8030 8031 8032 2181 9870 8000

ENTRYPOINT ["/bin/bash", "bootstrap.sh"]
