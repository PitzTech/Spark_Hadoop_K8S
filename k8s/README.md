# Distributed Spark/Hadoop Cluster on Kubernetes

This project sets up a distributed Apache Spark and Hadoop cluster using Kubernetes with MicroK8s and Multipass VMs.

## Prerequisites

- Ubuntu/Linux host machine
- At least 8GB RAM and 20GB disk space
- Multipass installed
- Internet connection for downloading images

## Architecture

- **Master Node**: Spark Master + Hadoop NameNode + YARN ResourceManager
- **Worker Nodes**: 2x Spark Workers + Hadoop DataNodes + YARN NodeManagers
- **Deployment**: Kubernetes cluster across multiple VMs using MicroK8s

## Setup Instructions

### 1. Install Multipass

```bash
# On Ubuntu/Debian
sudo snap install multipass

# On macOS
brew install multipass

# On Windows
# Download from https://multipass.run/
```

### 2. Create Virtual Machines

Create three VMs for the Kubernetes cluster:

```bash
# Create master node
multipass launch --name k8s-master --cpus 2 --mem 4G --disk 20G 22.04

# Create worker nodes
multipass launch --name k8s-worker1 --cpus 2 --mem 3G --disk 15G 22.04
multipass launch --name k8s-worker2 --cpus 2 --mem 3G --disk 15G 22.04
```

### 3. Install MicroK8s on All Nodes

Get shell access to each VM and install MicroK8s:

```bash
# Master node
multipass shell k8s-master
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s
microk8s status --wait-ready

# Worker nodes (repeat for both k8s-worker1 and k8s-worker2)
multipass shell k8s-worker1
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s
```

### 4. Set Up Kubernetes Cluster

#### On Master Node:

```bash
# Enable required addons
microk8s enable dns storage registry

# Get join token
microk8s add-node
# Copy the join command shown
```

#### On Worker Nodes:

```bash
# Join the cluster using the command from master
# Example: microk8s join 192.168.64.2:25000/92b2db237428470dc4fcfc4485738efb/36c2e93d95a2
microk8s join <MASTER_IP>:25000/<TOKEN>
```

#### Verify Cluster:

```bash
# On master node
microk8s kubectl get nodes
```

### 5. Deploy Spark/Hadoop Cluster

#### Copy Kubernetes manifests to master node:

```bash
# From your host machine
multipass transfer k8s/ k8s-master:/home/ubuntu/
```

#### Deploy the cluster:

```bash
# On master node
cd k8s/

# Deploy ConfigMaps
microk8s kubectl apply -f spark-master-cm1-configmap.yaml
microk8s kubectl apply -f spark-master-cm2-configmap.yaml
microk8s kubectl apply -f spark-master-cm3-configmap.yaml

# Deploy Master
microk8s kubectl apply -f spark-master-deployment.yaml
microk8s kubectl apply -f spark-master-service.yaml

# Deploy Workers
microk8s kubectl apply -f spark-worker-deployment.yaml
microk8s kubectl apply -f spark-worker-service.yaml
```

### 6. Verify Deployment

```bash
# Check pods status
microk8s kubectl get pods

# Check services
microk8s kubectl get services

# Get master node IP for web interfaces
microk8s kubectl get nodes -o wide
```

### 7. Access Web Interfaces

Get the master node IP and access these interfaces:

- **Spark Master UI**: `http://<MASTER_NODE_IP>:8080`
- **Hadoop NameNode UI**: `http://<MASTER_NODE_IP>:9870`
- **YARN ResourceManager UI**: `http://<MASTER_NODE_IP>:8088`
- **Spark History Server**: `http://<MASTER_NODE_IP>:18080`

### 8. Port Forwarding (Alternative Access)

If you can't access directly, use port forwarding:

```bash
# Forward Spark Master UI
microk8s kubectl port-forward service/spark-master 8080:8080 --address=0.0.0.0

# Forward Hadoop NameNode UI
microk8s kubectl port-forward service/spark-master 9870:9870 --address=0.0.0.0

# Forward YARN ResourceManager UI
microk8s kubectl port-forward service/spark-master 8088:8088 --address=0.0.0.0
```

## Testing the Cluster

### 1. Submit a Spark Job

```bash
# Get into the master pod
microk8s kubectl exec -it deployment/spark-master -- bash

# Submit a sample Spark job
spark-submit --class org.apache.spark.examples.SparkPi \
  --master spark://spark-master:7077 \
  --executor-memory 1g \
  --total-executor-cores 2 \
  /opt/spark/examples/jars/spark-examples_*.jar 100
```

### 2. Test HDFS

```bash
# Create test directory
hdfs dfs -mkdir /test

# Upload a file
echo "Hello Hadoop" | hdfs dfs -put - /test/hello.txt

# List files
hdfs dfs -ls /test

# Read file
hdfs dfs -cat /test/hello.txt
```

## Scaling

To scale the worker nodes:

```bash
# Scale to 3 workers
microk8s kubectl scale deployment spark-worker --replicas=3

# Scale back to 2 workers
microk8s kubectl scale deployment spark-worker --replicas=2
```

## Cleanup

### Remove Kubernetes Resources

```bash
# Delete all resources
microk8s kubectl delete -f .
```

### Stop/Delete VMs

```bash
# Stop VMs
multipass stop k8s-master k8s-worker1 k8s-worker2

# Delete VMs
multipass delete k8s-master k8s-worker1 k8s-worker2
multipass purge
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending**: Check node resources with `microk8s kubectl describe nodes`
2. **Image pull errors**: Ensure internet connectivity in VMs
3. **Service not accessible**: Check firewall rules and service endpoints

### Useful Commands

```bash
# Check pod logs
microk8s kubectl logs deployment/spark-master

# Describe pod for troubleshooting
microk8s kubectl describe pod <pod-name>

# Get cluster info
microk8s kubectl cluster-info

# Check node status
microk8s kubectl get nodes -o wide
```

## Configuration Files

- `spark-master-deployment.yaml`: Spark Master + Hadoop NameNode
- `spark-worker-deployment.yaml`: Spark Workers (scalable)
- `spark-master-service.yaml`: Services for master node
- `spark-worker-service.yaml`: Services for worker nodes
- `spark-master-cm*-configmap.yaml`: Hadoop configuration files

## Resource Requirements

| Component | CPU | Memory | Disk |
|-----------|-----|--------|------|
| Master VM | 2 cores | 4GB | 20GB |
| Worker VM | 2 cores | 3GB | 15GB |
| **Total** | **6 cores** | **10GB** | **50GB** |