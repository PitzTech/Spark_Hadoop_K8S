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

# Configure kubectl alias for easier management
echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
source ~/.bashrc

# Alternative: Export config for external tools
microk8s config > ~/.kube/config
```

### 5. Build Docker Images Directly in VMs

**IMPORTANT**: The Kubernetes manifests are configured to use local images only (`imagePullPolicy: Never`).

#### Download Required Binaries:

First, download the required Hadoop and Spark binaries on your host machine:

**Hadoop 3.4.0:**
https://drive.google.com/uc?id=1LCQEl0pVk3mCjbZZ4sZtXTG3fD68w7Oy

**Spark 3.5.0:**
https://drive.google.com/uc?id=19MRDBRugUU6mjB_cEhRhZBOJy92Z8gve

Save both files to your Downloads folder (or note the exact path where you save them).

#### Clone Repository and Transfer Binaries:

```bash
# Master node
multipass shell k8s-master
git clone https://github.com/PitzTech/Spark_Hadoop_K8S.git
exit

# Create bin folder and transfer binaries to master VM
# First create the bin directory in the VM
multipass exec k8s-master -- mkdir -p /home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/bin

# Then transfer the binaries (adjust paths to where you downloaded the files)
# If files are in Downloads folder:
multipass transfer ~/Downloads/hadoop-3.4.0.tar.gz k8s-master:/home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/bin/
multipass transfer ~/Downloads/spark-3.5.0-bin-hadoop3.tgz k8s-master:/home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/bin/

multipass transfer -r hadoop/spark-base/bin/ k8s-master:/home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/

# Repeat for worker nodes (if using multi-node setup)
multipass shell k8s-worker1
git clone https://github.com/PitzTech/Spark_Hadoop_K8S.git
exit

# Create bin directory and transfer binaries to worker1
multipass exec k8s-worker1 -- mkdir -p /home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/bin
multipass transfer ~/Downloads/hadoop-3.4.0.tar.gz k8s-worker1:/home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/bin/
multipass transfer ~/Downloads/spark-3.5.0-bin-hadoop3.tgz k8s-worker1:/home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/bin/

multipass transfer -r hadoop/spark-base/bin/ k8s-worker1:/home/ubuntu/Spark_Hadoop_K8S/hadoop/spark-base/
```

#### Build Images on All Nodes:

```bash
# On each VM (master, worker1, worker2):
multipass shell k8s-master  # (or k8s-worker1, k8s-worker2)
cd Spark_Hadoop_K8S

# Install required dependencies
sudo apt-get update
sudo apt-get install -y make curl

# Verify binaries are in place
ls -la hadoop/spark-base/bin/
# Should show: hadoop-3.4.0.tar.gz and spark-3.5.0-bin-hadoop3.tgz

# Build all images using the provided Makefile
sudo make build

# Verify images are built
docker images | grep hadoop
```

**What `make build` does:**
- Uses the transferred Hadoop 3.4.0 and Spark 3.5.0 binaries
- Builds all three Docker images in correct order (spark-base, spark-master, spark-worker)
- Takes 5-10 minutes per VM

**Note**: The large binaries (1.3GB total) are not included in the Git repository due to size limitations. You must download and transfer them manually.

#### Import Images to MicroK8s:

```bash
# On each VM, import the built images to MicroK8s
microk8s ctr images import <(docker save spark-base-hadoop:latest)
microk8s ctr images import <(docker save spark-master-hadoop:latest)
microk8s ctr images import <(docker save spark-worker-hadoop:latest)

# Verify images are available in MicroK8s
microk8s ctr images list | grep hadoop
```

**Advantages of this approach:**
- ✅ No large file transfers between host and VMs
- ✅ Each VM has the source code for debugging
- ✅ Faster than transferring 1.3GB+ tar files
- ✅ Self-contained - each VM builds independently
- ✅ Easy to make changes and rebuild

### 6. Deploy Spark/Hadoop Cluster

#### Kubernetes manifests are already available:

```bash
# On master node (manifests are already in the cloned repository)
cd Spark_Hadoop_K8S/k8s/
ls -la  # You should see all the .yaml files
```

#### Deploy the cluster:

```bash
# On master node
cd k8s/

# Deploy Persistent Volumes (FIRST)
microk8s kubectl apply -f hdfs-pv.yaml

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

# Wait for pods to be ready
microk8s kubectl get pods -w
```

**Note**: After deploying, it may take 2-3 minutes for all services to start properly.

## **Automatic Service Startup**

The bootstrap script **automatically starts all services** without manual intervention:

### **Master Pod** (`spark-master-xxxxxxxxx-xxxxx`):
- ✅ **Auto-detects master role** using hostname pattern `^spark-master`
- ✅ **Starts automatically:**
  - HDFS NameNode & DataNode
  - YARN ResourceManager
  - Spark Master (port 7077, WebUI 8080)
  - Spark History Server (port 18080)
  - Jupyter Notebook (port 8888)
  - FastAPI service (port 8000)

### **Worker Pods** (`spark-worker-xxxxxxxxx-xxxxx`):
- ✅ **Auto-detects worker role** (doesn't match spark-master pattern)
- ✅ **Starts automatically:**
  - HDFS DataNode
  - YARN NodeManager
  - Spark Worker (connects to master at spark://spark-master:7077)

**No SSH required** - Uses direct daemon commands for reliable startup.

### 7. Verify Deployment

```bash
# Check pods status
microk8s kubectl get pods

# Check services
microk8s kubectl get services

# Check pod logs to verify services started
microk8s kubectl logs deployment/spark-master --tail=20
microk8s kubectl logs deployment/spark-worker --tail=20

# Get master node IP for web interfaces
microk8s kubectl get nodes -o wide
```

**Expected output after successful deployment:**
- Pods should be in `Running` status
- Master logs should show: "Starting Hadoop/Spark Master services..."
- Worker logs should show: "Starting Hadoop/Spark Worker services..."

### 8. Access Web Interfaces with LoadBalancer

Access the Spark/Hadoop web interfaces using MetalLB LoadBalancer for a production-like Kubernetes setup:

#### **Step 1: Enable MetalLB**

```bash
# Enable MetalLB with IP range in same subnet as your VM
# Your VM IP: 10.201.228.21, so use range: 10.201.228.50-10.201.228.60
microk8s enable metallb:10.201.228.50-10.201.228.60

# Verify MetalLB is running
microk8s kubectl get pods -n metallb-system
```

#### **Step 2: Convert Services to LoadBalancer**

```bash
# Change spark-master service to LoadBalancer
microk8s kubectl patch service spark-master -p '{"spec":{"type":"LoadBalancer"}}'

# Optional: Also change worker service for worker web UI access
microk8s kubectl patch service spark-worker -p '{"spec":{"type":"LoadBalancer"}}'

# Check external IP assignment (may take 1-2 minutes)
microk8s kubectl get services -w

# Expected output:
# spark-master   LoadBalancer   10.152.183.87   10.201.228.50   8088:31234/TCP,8080:31235/TCP...
# spark-worker   LoadBalancer   10.152.183.68   10.201.228.51   8081:31236/TCP,8042:31237/TCP...
```

#### **Step 3: Access Web Interfaces**

**Access using LoadBalancer External IPs (from your browser):**
- **Spark Master UI**: `http://10.201.228.50:8080`
- **Hadoop NameNode UI**: `http://10.201.228.50:9870`
- **YARN ResourceManager UI**: `http://10.201.228.50:8088`
- **Jupyter Notebook**: `http://10.201.228.50:8888`
- **Spark History Server**: `http://10.201.228.50:18080`
- **Spark Worker UI**: `http://10.201.228.51:8081` (if worker service converted)

#### **Troubleshooting LoadBalancer**

```bash
# If LoadBalancer shows <pending> for EXTERNAL-IP:
microk8s kubectl describe service spark-master

# Check MetalLB logs:
microk8s kubectl logs -n metallb-system -l app=metallb

# Verify IP range is correct:
microk8s kubectl get configmap config -n metallb-system -o yaml

# Check if MetalLB controller is running:
microk8s kubectl get pods -n metallb-system

# Restart MetalLB if needed:
microk8s kubectl rollout restart deployment/controller -n metallb-system
```

**Note**: The LoadBalancer provides production-like external access to your Kubernetes services. Each service gets its own external IP from the configured range.

### 9. Monitoring Tools

### Kubernetes Management Applications

For monitoring cluster health, viewing real-time logs, and managing resources:

#### K9s (Recommended - Terminal-based)
```bash
# Install K9s - lightweight and powerful
curl -sS https://webinstall.dev/k9s | bash
# or via snap
sudo snap install k9s

# Launch K9s
k9s
```

**Features**: Real-time monitoring, live log streaming, pod management, resource graphs

#### Lens (GUI Option)
```bash
# Download and install Lens
wget https://api.k8slens.dev/binaries/Lens-2023.12.151144-latest.amd64.deb
sudo dpkg -i Lens-*.deb

# If missing dependencies:
sudo apt-get install -f
```

**Connect Lens to MicroK8s:**

1. **Export MicroK8s config** (on master node):
```bash
# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Export MicroK8s config to standard kubectl location
microk8s config > ~/.kube/config

# Set proper permissions
chmod 600 ~/.kube/config
```

2. **Transfer config to your host machine** (if Lens is on different machine):
```bash
# From your host machine, copy the config from master node
multipass transfer k8s-master:/home/ubuntu/.kube/config ~/.kube/config

# Or if running Lens directly on master VM:
# The config is already in ~/.kube/config
```

3. **Add cluster in Lens:**
   - Open Lens application
   - Click **"+"** or **"Add Cluster"**
   - Select **"Add from kubeconfig"**
   - Browse to `~/.kube/config` or paste the config content
   - Click **"Add Cluster"**

4. **Verify connection:**
   - Lens should now show your MicroK8s cluster
   - You'll see nodes, pods, and services
   - Real-time logs and monitoring will be available

#### Kubernetes Dashboard (Web-based)
```bash
# Enable dashboard (already mentioned above)
microk8s enable dashboard

# Access dashboard
microk8s dashboard-proxy
# Follow the instructions to get the token and URL
```

#### Configure External Tools
```bash
# For external tools like Lens, K9s to work with MicroK8s
mkdir -p ~/.kube
microk8s config > ~/.kube/config
chmod 600 ~/.kube/config

# Verify connection
kubectl get nodes

# Test with K9s
k9s
```

**Troubleshooting Lens Connection:**
- If Lens shows connection errors, verify the config file path
- Ensure MicroK8s is running: `microk8s status`
- Check cluster endpoint is accessible from your machine
- For VM setup, ensure proper network configuration

**Troubleshooting Pod Issues:**
```bash
# If pods are stuck or failing
microk8s kubectl describe pod <pod-name>
microk8s kubectl logs <pod-name> --previous

# Restart deployments after fixes
microk8s kubectl rollout restart deployment/spark-master
microk8s kubectl rollout restart deployment/spark-worker

# Delete and recreate if needed
microk8s kubectl delete -f spark-master-deployment.yaml
microk8s kubectl delete -f spark-worker-deployment.yaml
# Then reapply after rebuilding images
```

### 10. Testing the Cluster

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

### 11. Scaling

To scale the worker nodes:

```bash
# Scale to 3 workers
microk8s kubectl scale deployment spark-worker --replicas=3

# Scale back to 2 workers
microk8s kubectl scale deployment spark-worker --replicas=2
```

### 12. Cleanup

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

### 13. Troubleshooting

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

### 14. Image Configuration

The Kubernetes manifests are configured for local images:

- **Image names**: `spark-master-hadoop:latest`, `spark-worker-hadoop:latest`
- **Pull policy**: `imagePullPolicy: Never` (prevents internet pulls)
- **Import required**: Images must be imported on all nodes before deployment

### 15. Resource Requirements

| Component | CPU | Memory | Disk |
|-----------|-----|--------|------|
| Master VM | 2 cores | 4GB | 20GB |
| Worker VM | 2 cores | 3GB | 15GB |
| **Total** | **6 cores** | **10GB** | **50GB** |
