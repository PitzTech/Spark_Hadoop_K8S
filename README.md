# Cluster Hadoop e Spark com Docker

Este projeto configura um cluster Hadoop e Spark utilizando Docker.

## Configuração

1. Instale as dependências:
   ```bash
   sudo apt-get update
   sudo apt install apt-transport-https ca-certificates curl software-properties-common
   ...

2. Inicie o projeto:
   ```bash
   sudo make build
   sudo docker compose up
   sudo docker compose up --build

   sudo docker logs spark-master
   sudo docker logs spark-worker-1
   sudo docker logs spark-worker-2


   sudo docker exec -it spark-master bash
   echo $HADOOP_HOME
   /path/to/hadoop/sbin/start-dfs.sh
   ...

3. Para parar o projeto:
   ```bash
   sudo docker compose down
   ...




