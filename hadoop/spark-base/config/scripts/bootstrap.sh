#!/bin/bash

# Este trecho rodará independente de termos um container master ou
# worker. Necesário para funcionamento do HDFS e para comunicação
# dos containers/nodes.
/etc/init.d/ssh start

# Aguardar um pouco para SSH inicializar
sleep 5

# Abaixo temos o trecho que rodará apenas no master.
if [[ $HOSTNAME =~ ^spark-master ]]; then

    echo "Starting Hadoop/Spark Master services..."

    # Formatamos o namenode apenas se não existir
    if [ ! -d "$HADOOP_HOME/logs" ]; then
        echo "Formatting namenode..."
        hdfs namenode -format -force
    fi

    # Iniciamos os serviços do Hadoop
    echo "Starting HDFS..."
    $HADOOP_HOME/bin/hdfs --daemon start namenode
    $HADOOP_HOME/bin/hdfs --daemon start datanode

    echo "Starting YARN..."
    $HADOOP_HOME/bin/yarn --daemon start resourcemanager

    # Iniciamos o Spark Master
    echo "Starting Spark Master..."
    $SPARK_HOME/sbin/start-master.sh --host 0.0.0.0 --port 7077 --webui-port 8080

    # Aguardar HDFS inicializar
    sleep 10

    # Criação de diretórios no ambiente distribuído do HDFS
    echo "Creating HDFS directories..."
    hdfs dfs -mkdir -p /spark_logs 2>/dev/null || true
    hdfs dfs -mkdir -p /datasets 2>/dev/null || true
    hdfs dfs -mkdir -p /datasets_processed 2>/dev/null || true
    hdfs dfs -mkdir -p /datasets/lab_file_txt 2>/dev/null || true

    # Aguardar diretórios serem criados
    sleep 5

    # Iniciamos o Spark History Server (após HDFS estar pronto)
    echo "Starting Spark History Server..."
    $SPARK_HOME/sbin/start-history-server.sh

    # Iniciamos o NodeManager no master também
    echo "Starting NodeManager on master..."
    $HADOOP_HOME/bin/yarn nodemanager &

    # Caso mantenha notebooks personalizados na pasta que tem bind mount com o
    # container /user_data, o trecho abaixo automaticamente fará o processo de
    # confiar em todos os notebooks, também liberando o server do jupyter de
    # solicitar um token
    echo "Starting Jupyter Notebook..."
    cd /user_data
    jupyter trust *.ipynb 2>/dev/null || true
    jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' &

    # Iniciamos a API do microserviço
    echo "Starting FastAPI Microservice..."
    cd /user_data
    uvicorn api:app --host 0.0.0.0 --port 8000 --reload &

    # Aguardar HDFS estar completamente pronto
    echo "Waiting for HDFS to be ready..."
    while ! hdfs dfs -test -d /datasets 2>/dev/null; do
        echo "HDFS not ready yet... retrying"
        sleep 2
    done

    # Copiar arquivos se existirem
    if [ -d "/user_data/lab_file_txt" ] && [ "$(ls -A /user_data/lab_file_txt/*.txt 2>/dev/null)" ]; then
        echo "Copying files to HDFS..."
        hdfs dfs -put /user_data/lab_file_txt/*.txt /datasets/lab_file_txt 2>/dev/null || true
    fi

    echo "Master services started successfully!"

# E abaixo temos o trecho que rodará nos workers
else
    echo "Starting Hadoop/Spark Worker services..."

    # Aguardar master estar pronto
    sleep 15

    # Configs de HDFS nos dataNodes (workers)
    echo "Starting DataNode..."
    $HADOOP_HOME/bin/hdfs --daemon start datanode

    echo "Starting NodeManager..."
    $HADOOP_HOME/bin/yarn nodemanager &

    # Iniciar Spark Worker
    echo "Starting Spark Worker..."
    $SPARK_HOME/sbin/start-worker.sh spark://spark-master:7077

    echo "Worker services started successfully!"
fi

# Manter container rodando
while :; do sleep 2073600; done
