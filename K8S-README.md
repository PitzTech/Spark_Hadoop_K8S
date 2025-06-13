# Distributed Spark/Hadoop Cluster on Kubernetes

This project sets up a distributed Apache Spark and Hadoop cluster using Kubernetes with MicroK8s and Multipass VMs using **local Docker images**.

## Prerequisites

### 1. Docker Installation (Required)

Docker must be installed on your host machine before proceeding:

#### Ubuntu/Debian:
```bash
# Update packages
sudo apt-get update

# Install dependencies
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Restart session or run:
newgrp docker

# Verify installation
docker --version
docker compose version
```

#### CentOS/RHEL/Fedora:
```bash
# Install Docker
sudo dnf install docker docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### Verify Docker Installation:
```bash
# Test Docker
docker run hello-world

# Check Docker Compose
docker compose --version
```

### 2. System Requirements
- Ubuntu/Linux host machine with Docker installed
- At least 8GB RAM and 20GB disk space
- Multipass installed
- Local Docker images built (spark-master-hadoop, spark-worker-hadoop)

## Architecture

- **Master Node**: Spark Master + Hadoop NameNode + YARN ResourceManager
- **Worker Nodes**: 2x Spark Workers + Hadoop DataNodes + YARN NodeManagers
- **Deployment**: Kubernetes cluster across multiple VMs using MicroK8s
- **Images**: Local Docker images (no internet pull required)

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
multipass launch -n k8s-master -c 2 -m 4Gb -d 100G

# Create worker nodes
multipass launch -n k8s-worker1 -c 2 -m 3Gb -d 100G
multipass launch -n k8s-worker2 -c 2 -m 3Gb -d 100G
```

### 3. Install MicroK8s on All Nodes

Get shell access to each VM and install MicroK8s:

```bash
# Master node
multipass shell k8s-master
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER
mkdir ~/.kube
sudo chown -f -R $USER ~/.kube
cd ~/.kube && sudo microk8s config > config
sudo ufw allow in on cni0 && sudo ufw allow out on cni0
sudo ufw default allow routed
sudo microk8s enable dns dashboard storage
newgrp microk8s
microk8s status --wait-ready

# Worker nodes (repeat for both k8s-worker1 and k8s-worker2)
multipass shell k8s-worker1
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER
mkdir ~/.kube
sudo chown -f -R $USER ~/.kube
cd ~/.kube && sudo microk8s config > config
sudo ufw allow in on cni0 && sudo ufw allow out on cni0
sudo ufw default allow routed
sudo microk8s enable dns dashboard storage
newgrp microk8s
microk8s status --wait-ready
```

### 4. Set Up Kubernetes Cluster

#### On Master Node:

```bash
# Enable required addons
microk8s enable dns storage registry

# Get join token para cada worker
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

### 5. Build and Import Docker Images

**IMPORTANT**: The Kubernetes manifests are configured to use local images only (`imagePullPolicy: Never`).

Download the required files by clicking the links below or copying them into your browser:

Hadoop 3.4.0:
https://drive.google.com/uc?id=1LCQEl0pVk3mCjbZZ4sZtXTG3fD68w7Oy

Spark 3.5.0:
https://drive.google.com/uc?id=19MRDBRugUU6mjB_cEhRhZBOJy92Z8gve

Save the files to the directory:
hadoop/spark-base/bin

#### Build images using Makefile:

```bash
# Navigate to project root
cd /path/to/Spark_Hadoop_K8S

# Install required dependencies
sudo apt-get install curl make

# Build all images using the provided Makefile
# This will automatically download required dependencies and build images
# NOTE: Docker must be installed before running this command

sudo make build

# Save images to tar files
docker save spark-base-hadoop:latest -o spark-base-hadoop.tar
docker save spark-master-hadoop:latest -o spark-master-hadoop.tar
docker save spark-worker-hadoop:latest -o spark-worker-hadoop.tar
```

**What `make build` does:**
- Builds all three Docker images in correct order
- Skips downloads if files already exist

#### Transfer images to all VMs:

```bash
# Transfer all images to all nodes
multipass transfer spark-base-hadoop.tar k8s-master:/home/ubuntu/
multipass transfer spark-master-hadoop.tar k8s-master:/home/ubuntu/
multipass transfer spark-worker-hadoop.tar k8s-master:/home/ubuntu/

multipass transfer spark-base-hadoop.tar k8s-worker1:/home/ubuntu/
multipass transfer spark-master-hadoop.tar k8s-worker1:/home/ubuntu/
multipass transfer spark-worker-hadoop.tar k8s-worker1:/home/ubuntu/

multipass transfer spark-base-hadoop.tar k8s-worker2:/home/ubuntu/
multipass transfer spark-master-hadoop.tar k8s-worker2:/home/ubuntu/
multipass transfer spark-worker-hadoop.tar k8s-worker2:/home/ubuntu/
```

#### Import images on all nodes:

```bash
# On master node
multipass shell k8s-master
microk8s ctr images import spark-base-hadoop.tar
microk8s ctr images import spark-master-hadoop.tar
microk8s ctr images import spark-worker-hadoop.tar

# On worker1
multipass shell k8s-worker1
microk8s ctr images import spark-base-hadoop.tar
microk8s ctr images import spark-master-hadoop.tar
microk8s ctr images import spark-worker-hadoop.tar

# On worker2
multipass shell k8s-worker2
microk8s ctr images import spark-base-hadoop.tar
microk8s ctr images import spark-master-hadoop.tar
microk8s ctr images import spark-worker-hadoop.tar
```

#### Verify images are loaded:

```bash
# On all nodes
microk8s ctr images list | grep hadoop
```

### 6. Deploy Spark/Hadoop Cluster

#### Copy Kubernetes manifests to master node:

```bash
# From your host machine
multipass transfer -r k8s/ k8s-master:/home/ubuntu/
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

### 7. Verify Deployment

```bash
# Check pods status
microk8s kubectl get pods

# Check services
microk8s kubectl get services

# Get master node IP for web interfaces
microk8s kubectl get nodes -o wide
```

### 8. Access Web Interfaces

Get the master node IP and access these interfaces:

- **Spark Master UI**: `http://<MASTER_NODE_IP>:8080`
- **Hadoop NameNode UI**: `http://<MASTER_NODE_IP>:9870`
- **YARN ResourceManager UI**: `http://<MASTER_NODE_IP>:8088`
- **Spark History Server**: `http://<MASTER_NODE_IP>:18080`

### 9. Port Forwarding (Alternative Access)

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
2. **ImagePullBackOff errors**: Ensure images are imported on all nodes with `microk8s ctr images list`
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

# List imported images
microk8s ctr images list | grep hadoop
```

## Image Configuration

The Kubernetes manifests are configured for local images:

- **Image names**: `spark-master-hadoop:latest`, `spark-worker-hadoop:latest`
- **Pull policy**: `imagePullPolicy: Never` (prevents internet pulls)
- **Import required**: Images must be imported on all nodes before deployment

## Resource Requirements

| Component | CPU | Memory | Disk |
|-----------|-----|--------|------|
| Master VM | 2 cores | 4GB | 20GB |
| Worker VM | 2 cores | 3GB | 15GB |
| **Total** | **6 cores** | **10GB** | **50GB** |
