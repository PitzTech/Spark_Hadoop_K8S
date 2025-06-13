#!/bin/bash

# Improved startup script with better error handling and logging
set -e  # Exit on any error
set -o pipefail  # Exit on pipe failures

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Health check function
check_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if netstat -tuln | grep -q ":$port "; then
            log "✅ $service is running on port $port"
            return 0
        fi
        attempt=$((attempt + 1))
        log "⏳ Waiting for $service on port $port (attempt $attempt/$max_attempts)"
        sleep 2
    done
    
    log "❌ $service failed to start on port $port after $max_attempts attempts"
    return 1
}

log "🚀 Starting Spark/Hadoop bootstrap script..."
log "📋 Hostname: $HOSTNAME"
log "📋 Role: $(if [[ $HOSTNAME =~ ^spark-master ]]; then echo 'MASTER'; else echo 'WORKER'; fi)"

# Este trecho rodará independente de termos um container master ou
# worker. Necesário para funcionamento do HDFS e para comunicação
# dos containers/nodes.
log "🔧 Starting SSH service..."
/etc/init.d/ssh start || handle_error "Failed to start SSH"

# Aguardar um pouco para SSH inicializar
log "⏳ Waiting for SSH to initialize..."
sleep 5

# Abaixo temos o trecho que rodará apenas no master.
if [[ $HOSTNAME =~ ^spark-master ]]; then

    log "🎯 Starting Hadoop/Spark Master services..."

    # Formatamos o namenode apenas se não existir
    if [ ! -d "$HADOOP_HOME/logs" ]; then
        log "🔧 Formatting namenode..."
        hdfs namenode -format -force || handle_error "Failed to format namenode"
    else
        log "✅ Namenode already formatted, skipping..."
    fi

    # Iniciamos os serviços do Hadoop
    log "🔧 Starting HDFS services..."
    $HADOOP_HOME/bin/hdfs --daemon start namenode || handle_error "Failed to start namenode"
    sleep 5
    check_service "NameNode" "9870" || log "⚠️ NameNode health check failed, continuing..."
    
    $HADOOP_HOME/bin/hdfs --daemon start datanode || handle_error "Failed to start datanode"
    sleep 3
    check_service "DataNode" "9864" || log "⚠️ DataNode health check failed, continuing..."

    log "🔧 Starting YARN ResourceManager..."
    $HADOOP_HOME/bin/yarn --daemon start resourcemanager || handle_error "Failed to start resourcemanager"
    sleep 3
    check_service "ResourceManager" "8088" || log "⚠️ ResourceManager health check failed, continuing..."

    # Iniciamos o Spark Master
    log "🔧 Starting Spark Master..."
    # Clear conflicting environment variables
    unset SPARK_MASTER_PORT SPARK_LOCAL_IP
    $SPARK_HOME/sbin/start-master.sh || handle_error "Failed to start Spark Master"
    sleep 5
    check_service "Spark Master" "8080" || log "⚠️ Spark Master health check failed, continuing..."

    # Aguardar HDFS inicializar
    log "⏳ Waiting for HDFS to stabilize..."
    sleep 10

    # Criação de diretórios no ambiente distribuído do HDFS (com timeout)
    log "🔧 Creating HDFS directories..."
    
    # Function to create directory with timeout
    create_hdfs_dir() {
        local dir=$1
        local timeout=10
        log "📁 Creating directory: $dir"
        timeout $timeout hdfs dfs -mkdir -p $dir 2>/dev/null || {
            log "⚠️ Failed to create $dir (timeout or error)"
            return 1
        }
        log "✅ Successfully created $dir"
        return 0
    }
    
    # Create directories with individual timeouts
    create_hdfs_dir "/spark_logs"
    create_hdfs_dir "/datasets" 
    create_hdfs_dir "/datasets_processed"
    create_hdfs_dir "/datasets/lab_file_txt"
    
    log "✅ HDFS directory creation completed"

    # Aguardar diretórios serem criados
    sleep 3

    # Iniciamos o Spark History Server (após HDFS estar pronto)
    log "🔧 Starting Spark History Server..."
    $SPARK_HOME/sbin/start-history-server.sh || log "⚠️ Failed to start Spark History Server, continuing..."
    sleep 3
    check_service "Spark History Server" "18080" || log "⚠️ Spark History Server health check failed, continuing..."

    # Iniciamos o NodeManager no master também
    log "🔧 Starting NodeManager on master..."
    $HADOOP_HOME/bin/yarn nodemanager &
    sleep 3
    check_service "NodeManager" "8042" || log "⚠️ NodeManager health check failed, continuing..."

    # Caso mantenha notebooks personalizados na pasta que tem bind mount com o
    # container /user_data, o trecho abaixo automaticamente fará o processo de
    # confiar em todos os notebooks, também liberando o server do jupyter de
    # solicitar um token
    log "🔧 Starting Jupyter Notebook..."
    if [ -d "/user_data" ]; then
        cd /user_data
        jupyter trust *.ipynb 2>/dev/null || true
        jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' &
        sleep 3
        check_service "Jupyter Notebook" "8888" || log "⚠️ Jupyter health check failed, continuing..."
    else
        log "⚠️ /user_data directory not found, skipping Jupyter..."
    fi

    # Iniciamos a API do microserviço
    log "🔧 Starting FastAPI Microservice..."
    if [ -d "/user_data" ] && [ -f "/user_data/api.py" ]; then
        cd /user_data
        uvicorn api:app --host 0.0.0.0 --port 8000 --reload &
        sleep 3
        check_service "FastAPI" "8000" || log "⚠️ FastAPI health check failed, continuing..."
    else
        log "⚠️ API file not found, skipping FastAPI..."
    fi

    # Copy files to HDFS in background (non-blocking)
    echo "Starting background file copy task..."
    (
        # Wait for HDFS to be ready (with timeout)
        echo "Background: Waiting for HDFS to be ready..."
        MAX_ATTEMPTS=30
        ATTEMPT=0
        while ! hdfs dfs -test -d /datasets 2>/dev/null; do
            ATTEMPT=$((ATTEMPT + 1))
            if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
                echo "Background: HDFS readiness check timed out after $MAX_ATTEMPTS attempts"
                exit 1
            fi
            echo "Background: HDFS not ready yet... retrying ($ATTEMPT/$MAX_ATTEMPTS)"
            sleep 2
        done
        
        # Copy files if they exist
        if [ -d "/user_data/lab_file_txt" ] && [ "$(ls -A /user_data/lab_file_txt/*.txt 2>/dev/null)" ]; then
            echo "Background: Copying files to HDFS..."
            hdfs dfs -put /user_data/lab_file_txt/*.txt /datasets/lab_file_txt 2>/dev/null || true
            echo "Background: File copy completed"
        else
            echo "Background: No files to copy"
        fi
    ) &

    log "🎉 Master services startup completed!"

# E abaixo temos o trecho que rodará nos workers
else
    log "🎯 Starting Hadoop/Spark Worker services..."

    # Aguardar master estar pronto
    log "⏳ Waiting for master to be ready..."
    sleep 15

    # Test master connectivity
    log "🔍 Testing connectivity to spark-master..."
    if ! nc -z spark-master 7077 2>/dev/null; then
        log "⚠️ Cannot connect to spark-master:7077, continuing anyway..."
    else
        log "✅ Master connectivity confirmed"
    fi

    # Configs de HDFS nos dataNodes (workers)
    log "🔧 Starting DataNode..."
    $HADOOP_HOME/bin/hdfs --daemon start datanode || handle_error "Failed to start datanode"
    sleep 3
    check_service "DataNode" "9864" || log "⚠️ DataNode health check failed, continuing..."

    log "🔧 Starting NodeManager..."
    $HADOOP_HOME/bin/yarn nodemanager &
    sleep 3
    check_service "NodeManager" "8042" || log "⚠️ NodeManager health check failed, continuing..."

    # Iniciar Spark Worker
    log "🔧 Starting Spark Worker..."
    # Clear conflicting environment variables
    unset SPARK_WORKER_PORT SPARK_LOCAL_IP
    $SPARK_HOME/sbin/start-worker.sh spark://spark-master:7077 || handle_error "Failed to start Spark Worker"
    sleep 5
    check_service "Spark Worker" "8081" || log "⚠️ Spark Worker health check failed, continuing..."

    log "🎉 Worker services startup completed!"
fi

log "🔄 Container initialization complete - entering keep-alive loop"
log "📊 Services status summary:"
netstat -tuln | grep -E ":(7077|8080|8088|9870|18080|8888|8000|8042|9864|8081)" || log "No services detected on expected ports"

# Manter container rodando
while :; do sleep 2073600; done
