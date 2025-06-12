#!/bin/bash

echo "Undeploying Spark-Hadoop cluster from Kubernetes..."

# Delete external services
echo "Deleting external services..."
kubectl delete -f external-services.yaml --ignore-not-found=true

# Delete workers
echo "Deleting Spark Workers..."
kubectl delete -f spark-worker-deployments.yaml --ignore-not-found=true

# Delete master
echo "Deleting Spark Master..."
kubectl delete -f spark-master-deployment.yaml --ignore-not-found=true

# Delete persistent volumes
echo "Deleting persistent volumes..."
kubectl delete -f persistent-volumes.yaml --ignore-not-found=true

# Delete ConfigMaps
echo "Deleting ConfigMaps..."
kubectl delete -f configmaps.yaml --ignore-not-found=true

# Delete namespace (this will clean up any remaining resources)
echo "Deleting namespace..."
kubectl delete -f namespace.yaml --ignore-not-found=true

echo "Undeployment complete!"