FROM spark-base-hadoop:latest

ENV SPARK_WORKER_WEBUI_PORT=8081
ENV SPARK_MASTER="spark://spark-master:7077"
ENV SPARK_WORKER_LOG=/opt/spark/logs
ENV YARN_CONF_DIR=$HADOOP_CONF_DIR

EXPOSE 8081 7001 8030 8031 8032 2181

ENTRYPOINT ["/bin/bash", "bootstrap.sh"]
