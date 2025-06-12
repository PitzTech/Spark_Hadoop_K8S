#!/bin/bash

echo "=== Removing Hadoop Cluster from Kubernetes ==="

# Remove deployments
echo "Removing deployments..."
kubectl delete -f manifests/spark-worker-deployments.yaml
kubectl delete -f manifests/spark-master-deployment.yaml

# Remove services
echo "Removing services..."
kubectl delete -f services/hadoop-services.yaml

# Remove volumes
echo "Removing volumes..."
kubectl delete -f volumes/persistent-volumes.yaml

# Remove namespace
echo "Removing namespace..."
kubectl delete -f manifests/namespace.yaml

echo "=== Cleanup Complete ==="