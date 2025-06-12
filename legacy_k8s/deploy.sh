#!/bin/bash

echo "Deploying Spark-Hadoop cluster to Kubernetes..."

# Create namespace
echo "Creating namespace..."
kubectl apply -f namespace.yaml

# Create ConfigMaps
echo "Creating ConfigMaps..."
kubectl apply -f configmaps.yaml

# Create persistent volumes
echo "Creating persistent volumes..."
kubectl apply -f persistent-volumes.yaml

# Wait for PVCs to be bound
echo "Waiting for PVCs to be bound..."
kubectl wait --for=condition=Bound pvc/user-data-pvc -n spark-hadoop --timeout=60s

# Deploy Spark Master
echo "Deploying Spark Master..."
kubectl apply -f spark-master-deployment.yaml

# Wait for master to be ready
echo "Waiting for Spark Master to be ready..."
kubectl wait --for=condition=available deployment/spark-master -n spark-hadoop --timeout=300s

# Deploy Spark Workers
echo "Deploying Spark Workers..."
kubectl apply -f spark-worker-deployments.yaml

# Wait for workers to be ready
echo "Waiting for Spark Workers to be ready..."
kubectl wait --for=condition=available deployment/spark-worker-1 -n spark-hadoop --timeout=300s
kubectl wait --for=condition=available deployment/spark-worker-2 -n spark-hadoop --timeout=300s

# Create external services
echo "Creating external services..."
kubectl apply -f external-services.yaml

echo "Deployment complete!"
echo ""
echo "Access URLs (replace <NODE_IP> with your Kubernetes node IP):"
echo "- Spark Master UI: http://<NODE_IP>:30080"
echo "- YARN ResourceManager: http://<NODE_IP>:30088"
echo "- HDFS NameNode: http://<NODE_IP>:30870"
echo "- Jupyter Notebook: http://<NODE_IP>:30888"
echo "- FastAPI: http://<NODE_IP>:30000"
echo "- Spark History Server: http://<NODE_IP>:31080"
echo "- Spark Worker 1 UI: http://<NODE_IP>:30081"
echo "- Spark Worker 2 UI: http://<NODE_IP>:30082"
echo ""
echo "To check status:"
echo "kubectl get pods -n spark-hadoop"
echo "kubectl get services -n spark-hadoop"