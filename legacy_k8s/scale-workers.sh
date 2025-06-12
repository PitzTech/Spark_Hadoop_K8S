#!/bin/bash

# Spark-Hadoop Worker Scaling Script
# Usage: ./scale-workers.sh [add|remove|list] [worker-number]

NAMESPACE="spark-hadoop"

function show_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  add <number>     Add a new worker (e.g., add 3 creates spark-worker-3)"
    echo "  remove <number>  Remove worker by number (e.g., remove 3)"
    echo "  scale <name> <replicas>  Scale existing worker deployment"
    echo "  list            List all current workers"
    echo "  status          Show worker status in Spark Master"
    echo ""
    echo "Examples:"
    echo "  $0 add 3              # Add spark-worker-3"
    echo "  $0 remove 3           # Remove spark-worker-3"
    echo "  $0 scale worker-1 3   # Scale worker-1 to 3 replicas"
    echo "  $0 list               # List all workers"
}

function list_workers() {
    echo "Current Spark Workers:"
    kubectl get deployments -n $NAMESPACE -l app --no-headers | grep spark-worker
    echo ""
    echo "Worker Pods:"
    kubectl get pods -n $NAMESPACE -l app --no-headers | grep spark-worker
    echo ""
    echo "Worker Services:"
    kubectl get services -n $NAMESPACE --no-headers | grep spark-worker
}

function add_worker() {
    local worker_num=$1
    local worker_name="spark-worker-$worker_num"
    local ui_port=$((30080 + worker_num))
    local nm_port=$((30042 + worker_num * 100))
    
    if [ -z "$worker_num" ]; then
        echo "Error: Please specify worker number"
        show_usage
        exit 1
    fi
    
    # Check if worker already exists
    if kubectl get deployment $worker_name -n $NAMESPACE >/dev/null 2>&1; then
        echo "Error: $worker_name already exists!"
        exit 1
    fi
    
    echo "Creating $worker_name..."
    
    # Create worker deployment and service
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $worker_name
  namespace: $NAMESPACE
  labels:
    app: $worker_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $worker_name
  template:
    metadata:
      labels:
        app: $worker_name
    spec:
      hostname: $worker_name
      containers:
      - name: spark-worker
        image: raulcsouza/spark-worker-hadoop
        imagePullPolicy: IfNotPresent
        tty: true
        ports:
        - containerPort: 8081
          name: worker-ui
        - containerPort: 8042
          name: nodemanager
        env:
        - name: SPARK_LOCAL_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: SPARK_MASTER
          value: "spark://spark-master:7077"
---
apiVersion: v1
kind: Service
metadata:
  name: ${worker_name}-service
  namespace: $NAMESPACE
spec:
  selector:
    app: $worker_name
  ports:
  - name: worker-ui
    port: 8081
    targetPort: 8081
    nodePort: $ui_port
  - name: nodemanager
    port: 8042
    targetPort: 8042
    nodePort: $nm_port
  type: NodePort
EOF
    
    echo "$worker_name created successfully!"
    echo "Worker UI will be available at: http://<NODE_IP>:$ui_port"
    echo "NodeManager UI will be available at: http://<NODE_IP>:$nm_port"
}

function remove_worker() {
    local worker_num=$1
    local worker_name="spark-worker-$worker_num"
    
    if [ -z "$worker_num" ]; then
        echo "Error: Please specify worker number"
        show_usage
        exit 1
    fi
    
    echo "Removing $worker_name..."
    
    # Remove deployment and service
    kubectl delete deployment $worker_name -n $NAMESPACE --ignore-not-found=true
    kubectl delete service ${worker_name}-service -n $NAMESPACE --ignore-not-found=true
    
    echo "$worker_name removed successfully!"
}

function scale_worker() {
    local worker_name=$1
    local replicas=$2
    
    if [ -z "$worker_name" ] || [ -z "$replicas" ]; then
        echo "Error: Please specify worker name and replica count"
        show_usage
        exit 1
    fi
    
    # Add spark- prefix if not present
    if [[ $worker_name != spark-* ]]; then
        worker_name="spark-$worker_name"
    fi
    
    echo "Scaling $worker_name to $replicas replicas..."
    kubectl scale deployment $worker_name --replicas=$replicas -n $NAMESPACE
    
    echo "$worker_name scaled to $replicas replicas!"
}

function show_status() {
    echo "=== Spark Workers Status ==="
    list_workers
    echo ""
    echo "=== Resource Usage ==="
    kubectl top pods -n $NAMESPACE 2>/dev/null | grep spark-worker || echo "Resource metrics not available"
    echo ""
    echo "=== Recent Events ==="
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
}

# Main script logic
case "$1" in
    "add")
        add_worker $2
        ;;
    "remove")
        remove_worker $2
        ;;
    "scale")
        scale_worker $2 $3
        ;;
    "list")
        list_workers
        ;;
    "status")
        show_status
        ;;
    *)
        show_usage
        exit 1
        ;;
esac