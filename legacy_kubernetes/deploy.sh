#!/bin/bash

echo "=== Deploying Hadoop Cluster on Kubernetes ==="

# Criar namespace
echo "Creating namespace..."
kubectl apply -f manifests/namespace.yaml

# Criar volumes persistentes
echo "Creating persistent volumes..."
kubectl apply -f volumes/persistent-volumes.yaml

# Aguardar PVCs estarem prontos
echo "Waiting for PVCs to be bound..."
kubectl wait --for=condition=Bound pvc/hadoop-master-pvc -n hadoop-cluster --timeout=60s
kubectl wait --for=condition=Bound pvc/hadoop-worker1-pvc -n hadoop-cluster --timeout=60s
kubectl wait --for=condition=Bound pvc/hadoop-worker2-pvc -n hadoop-cluster --timeout=60s

# Criar services
echo "Creating services..."
kubectl apply -f services/hadoop-services.yaml

# Deploying Spark Master
echo "Deploying Spark Master..."
kubectl apply -f manifests/spark-master-deployment.yaml

# Aguardar master estar pronto
echo "Waiting for Spark Master to be ready..."
kubectl wait --for=condition=Available deployment/spark-master -n hadoop-cluster --timeout=300s

# Deploying Workers
echo "Deploying Spark Workers..."
kubectl apply -f manifests/spark-worker-deployments.yaml

# Aguardar workers estarem prontos
echo "Waiting for Workers to be ready..."
kubectl wait --for=condition=Available deployment/spark-worker1 -n hadoop-cluster --timeout=300s
kubectl wait --for=condition=Available deployment/spark-worker2 -n hadoop-cluster --timeout=300s

echo "=== Deployment Complete ==="
echo ""
echo "Access URLs (use your node IP):"
echo "Spark Master UI: http://<NODE-IP>:30080"
echo "Hadoop NameNode: http://<NODE-IP>:30870"
echo "YARN ResourceManager: http://<NODE-IP>:30088"
echo "NodeManager: http://<NODE-IP>:30042"
echo "Spark History: http://<NODE-IP>:31080"
echo "Jupyter Notebook: http://<NODE-IP>:30888"
echo "FastAPI: http://<NODE-IP>:30000"
echo ""
echo "Check status:"
echo "kubectl get pods -n hadoop-cluster"
echo "kubectl get services -n hadoop-cluster"