# Spark-Hadoop Kubernetes Cluster

This directory contains Kubernetes manifests that replicate the exact behavior of your Docker Compose setup, providing the same Spark-Hadoop cluster functionality with added Kubernetes benefits.

## 🔄 Docker vs Kubernetes Behavior

### ✅ **Identical Behavior**:
- **Same Docker Images**: Uses your existing `raulcsouza/spark-master-hadoop` and `raulcsouza/spark-worker-hadoop`
- **Same Volume Mounts**: Local `user_data` directory mounted to `/user_data` in pods
- **Same Configuration**: Hadoop config files applied identically
- **Same Networking**: Internal service discovery via hostnames (`spark-master`, `spark-worker-1`, etc.)
- **Same Ports**: All original port mappings preserved
- **Same Environment**: Environment variables and startup behavior identical

### 🚀 **Additional Kubernetes Benefits**:
- **High Availability**: Automatic pod restarts on failure
- **Scalability**: Easy worker scaling (see [Adding More Workers](#adding-more-workers))
- **Resource Management**: CPU/memory limits and requests
- **Service Discovery**: Built-in DNS resolution
- **Rolling Updates**: Zero-downtime deployments

## 📁 File Structure

```
k8s/
├── README.md                     # This file
├── namespace.yaml               # Creates spark-hadoop namespace
├── configmaps.yaml             # Hadoop configuration files
├── persistent-volumes.yaml     # Local file mounting for user_data
├── spark-master-deployment.yaml # Spark Master + HDFS NameNode
├── spark-worker-deployments.yaml # Spark Workers (2 replicas)
├── external-services.yaml      # NodePort services for external access
├── deploy.sh                   # Automated deployment script
└── undeploy.sh                 # Cleanup script
```

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster running
- `kubectl` configured and working
- Files must exist at `/home/ubuntu_user/cluster-hadoop/` on Kubernetes nodes

### Deploy the Cluster
```bash
cd /home/ubuntu_user/cluster-hadoop/k8s
./deploy.sh
```

### Check Status
```bash
# View all pods
kubectl get pods -n spark-hadoop

# View services
kubectl get services -n spark-hadoop

# View logs
kubectl logs -f deployment/spark-master -n spark-hadoop
kubectl logs -f deployment/spark-worker-1 -n spark-hadoop
```

### Access the UIs
Replace `<NODE_IP>` with your Kubernetes node IP:

| Service | URL | Description |
|---------|-----|-------------|
| Spark Master UI | `http://<NODE_IP>:30080` | Spark cluster overview |
| YARN ResourceManager | `http://<NODE_IP>:30088` | Hadoop YARN jobs |
| HDFS NameNode | `http://<NODE_IP>:30870` | HDFS file system |
| Jupyter Notebook | `http://<NODE_IP>:30888` | Interactive notebooks |
| FastAPI | `http://<NODE_IP>:30000` | Your microservice API |
| Spark History Server | `http://<NODE_IP>:31080` | Completed Spark jobs |
| Worker 1 UI | `http://<NODE_IP>:30081` | Spark worker 1 status |
| Worker 2 UI | `http://<NODE_IP>:30082` | Spark worker 2 status |

### Clean Up
```bash
./undeploy.sh
```

## 🔧 Configuration Details

### Local File Mounting
- **`user_data/`**: Mounted as PersistentVolume with hostPath
  - Path: `/home/ubuntu_user/cluster-hadoop/user_data` → `/user_data` in pods
  - **Live sync**: Changes to local files immediately visible in pods
  - Contains: notebooks, datasets, API files

### Hadoop Configuration
- **Config files**: Stored in ConfigMaps from your local files:
  - `core-site.xml` - HDFS configuration
  - `yarn-site.xml` - YARN ResourceManager settings
  - `mapred-site.xml` - MapReduce configuration
- **Hostnames**: Service discovery via Kubernetes DNS
  - `spark-master` resolves to master pod IP
  - Workers connect to `spark://spark-master:7077`

### Networking
- **Internal**: ClusterIP services for inter-pod communication
- **External**: NodePort services for browser access
- **Ports**: Exact same mapping as Docker Compose

## 📈 Adding More Workers

### Method 1: Scale Existing Deployments
```bash
# Scale worker-1 to 2 replicas
kubectl scale deployment spark-worker-1 --replicas=2 -n spark-hadoop

# Scale worker-2 to 3 replicas
kubectl scale deployment spark-worker-2 --replicas=3 -n spark-hadoop
```

### Method 2: Add New Worker Deployment
Create a new worker deployment file:

```bash
# Copy existing worker
cp spark-worker-deployments.yaml spark-worker-3.yaml
```

Edit `spark-worker-3.yaml` and change:
- Deployment name: `spark-worker-3`
- Service name: `spark-worker-3-service`
- Hostname: `spark-worker-3`
- NodePort for UI: `30083`
- NodePort for NodeManager: `30843`

Apply the new worker:
```bash
kubectl apply -f spark-worker-3.yaml
```

### Method 3: Batch Worker Creation
Create multiple workers at once:

```bash
# Create workers 3-5
for i in {3..5}; do
  sed "s/worker-2/worker-$i/g; s/30082/300$((80+i))/g; s/30742/307$((40+i))/g" spark-worker-deployments.yaml > spark-worker-$i.yaml
  kubectl apply -f spark-worker-$i.yaml
done
```

### Verify New Workers
```bash
# Check worker registration in Spark Master UI
# Or check pods
kubectl get pods -n spark-hadoop -l app contains spark-worker

# View worker logs
kubectl logs -f deployment/spark-worker-3 -n spark-hadoop
```

## 🔍 Monitoring and Troubleshooting

### View Logs
```bash
# Master logs
kubectl logs -f deployment/spark-master -n spark-hadoop

# Worker logs
kubectl logs -f deployment/spark-worker-1 -n spark-hadoop

# All pods logs
kubectl logs -f -l app=spark-master -n spark-hadoop
```

### Debug Pod Issues
```bash
# Describe pod for events
kubectl describe pod <pod-name> -n spark-hadoop

# Get into pod shell
kubectl exec -it deployment/spark-master -n spark-hadoop -- /bin/bash

# Check resource usage
kubectl top pods -n spark-hadoop
```

### Common Issues

1. **PVC Not Binding**:
   ```bash
   # Check PV status
   kubectl get pv

   # Ensure hostPath exists on node
   ls -la /home/ubuntu_user/cluster-hadoop/user_data
   ```

2. **Workers Not Connecting**:
   ```bash
   # Check master service
   kubectl get svc spark-master -n spark-hadoop

   # Test connectivity from worker
   kubectl exec deployment/spark-worker-1 -n spark-hadoop -- nc -zv spark-master 7077
   ```

3. **Web UIs Not Accessible**:
   ```bash
   # Check NodePort services
   kubectl get svc -n spark-hadoop

   # Get node IP
   kubectl get nodes -o wide
   ```

## 📊 Resource Usage

### Default Resource Requests/Limits
Currently no limits set - pods use available node resources.

### Add Resource Limits (Optional)
Edit deployment files to add:
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "4Gi"
    cpu: "2"
```

## 🔄 Updates and Maintenance

### Update Docker Images
```bash
# Pull new image versions
docker pull raulcsouza/spark-master-hadoop:latest
docker pull raulcsouza/spark-worker-hadoop:latest

# Restart deployments to use new images
kubectl rollout restart deployment/spark-master -n spark-hadoop
kubectl rollout restart deployment/spark-worker-1 -n spark-hadoop
kubectl rollout restart deployment/spark-worker-2 -n spark-hadoop
```

### Update Configuration
```bash
# Edit ConfigMap
kubectl edit configmap hadoop-config -n spark-hadoop

# Restart pods to pick up changes
kubectl rollout restart deployment/spark-master -n spark-hadoop
```

### Backup User Data
```bash
# Since user_data is on host, backup normally:
tar -czf spark-hadoop-backup-$(date +%Y%m%d).tar.gz /home/ubuntu_user/cluster-hadoop/user_data/
```

## 🚨 Important Notes

1. **Node Requirements**: Kubernetes nodes must have access to `/home/ubuntu_user/cluster-hadoop/user_data`
2. **Single Node**: PersistentVolumes use hostPath, so pods must run on the same node as your files
3. **File Permissions**: Ensure Kubernetes has read/write access to mounted directories
4. **Port Conflicts**: NodePort services require ports 30000-31999 to be available
5. **Resource Limits**: Consider setting resource limits for production use

## 🆚 Migration from Docker Compose

### Stop Docker Compose
```bash
cd /home/ubuntu_user/cluster-hadoop
docker-compose down
```

### Deploy to Kubernetes
```bash
cd k8s
./deploy.sh
```

### Verify Data Integrity
- Check that notebooks and datasets are accessible
- Verify HDFS data persistence
- Test Spark job execution

Your cluster should work identically to the Docker Compose version!

## 🖥️ Multi-Machine VirtualBox Setup

This section explains how to set up a distributed Kubernetes cluster across multiple VirtualBox machines, with one machine as the master and others as worker nodes.

### Architecture Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   VirtualBox    │    │   VirtualBox    │    │   VirtualBox    │
│   Machine 1     │    │   Machine 2     │    │   Machine 3     │
│   (Master)      │    │   (Worker)      │    │   (Worker)      │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Kubernetes  │ │    │ │ Kubernetes  │ │    │ │ Kubernetes  │ │
│ │ Master      │◄├────┤►│ Worker Node │ │    │ │ Worker Node │ │
│ │             │ │    │ │             │ │    │ │             │ │
│ │ Spark       │ │    │ │ Spark       │ │    │ │ Spark       │ │
│ │ Master Pod  │ │    │ │ Worker Pods │ │    │ │ Worker Pods │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
     10.0.2.10           10.0.2.11           10.0.2.12
```

### 📋 Prerequisites

1. **VirtualBox Machines Requirements**:
   - **Master VM**: 4GB+ RAM, 50GB+ disk, 2+ CPU cores
   - **Worker VMs**: 2GB+ RAM, 20GB+ disk, 1+ CPU cores
   - **All VMs**: Ubuntu 20.04+ with Docker and Kubernetes installed

2. **Network Configuration**:
   - All VMs must be on the same network (Bridge or Host-Only)
   - Static IP addresses recommended
   - Ports 6443, 2379-2380, 10250-10252 open for Kubernetes
   - Ports 30000-32767 open for NodePort services

### 🔧 Step 1: Prepare VirtualBox Machines

#### On Each VM (Master + Workers):

1. **Install Docker**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Install Kubernetes**:
   ```bash
   # Update and install prerequisites
   sudo apt-get update
   sudo apt-get install -y apt-transport-https ca-certificates curl

   # Add Kubernetes repo
   curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
   echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

   # Install kubelet, kubeadm, kubectl
   sudo apt-get update
   sudo apt-get install -y kubelet kubeadm kubectl
   sudo apt-mark hold kubelet kubeadm kubectl
   ```

3. **Configure Container Runtime**:
   ```bash
   # Disable swap
   sudo swapoff -a
   sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

   # Configure containerd
   sudo mkdir -p /etc/containerd
   containerd config default | sudo tee /etc/containerd/config.toml
   sudo systemctl restart containerd
   sudo systemctl enable containerd
   ```

4. **Network Configuration**:
   ```bash
   # Configure bridge networking
   cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
   br_netfilter
   EOF

   cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
   net.bridge.bridge-nf-call-ip6tables = 1
   net.bridge.bridge-nf-call-iptables = 1
   EOF

   sudo sysctl --system
   ```

### 🎯 Step 2: Initialize Master Node

**On Master VM** (e.g., IP: 10.0.2.10):

1. **Copy Cluster Files**:
   ```bash
   # Copy your cluster-hadoop directory to the master VM
   scp -r /home/ubuntu_user/cluster-hadoop user@10.0.2.10:/home/user/
   ```

2. **Initialize Kubernetes Master**:
   ```bash
   # Initialize cluster with pod network CIDR
   sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=10.0.2.10

   # Configure kubectl for regular user
   mkdir -p $HOME/.kube
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```

3. **Install Pod Network (Calico)**:
   ```bash
   kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
   kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
   ```

4. **Save Join Command**:
   ```bash
   # Save this command for worker nodes
   kubeadm token create --print-join-command > /tmp/join-command.txt
   cat /tmp/join-command.txt
   ```

### 🔗 Step 3: Join Worker Nodes

**On Each Worker VM** (e.g., IPs: 10.0.2.11, 10.0.2.12):

1. **Join the Cluster**:
   ```bash
   # Use the join command from master (example):
   sudo kubeadm join 10.0.2.10:6443 --token <token> \
       --discovery-token-ca-cert-hash sha256:<hash>
   ```

2. **Verify Connection**:
   ```bash
   # On master, check nodes
   kubectl get nodes

   # Should show:
   # NAME     STATUS   ROLES           AGE   VERSION
   # master   Ready    control-plane   5m    v1.28.0
   # worker1  Ready    <none>          2m    v1.28.0
   # worker2  Ready    <none>          1m    v1.28.0
   ```

### 🚀 Step 4: Deploy Spark-Hadoop Cluster

**On Master VM**:

1. **Update PersistentVolume Configuration**:
   Edit `k8s/persistent-volumes.yaml` to ensure the path exists on all nodes or use NFS:

   ```yaml
   # Option 1: Use NFS (recommended for multi-node)
   spec:
     nfs:
       server: 10.0.2.10
       path: /home/user/cluster-hadoop/user_data

   # Option 2: Ensure files exist on all nodes
   # Copy user_data to same path on all worker nodes
   ```

2. **Label Nodes for Scheduling**:
   ```bash
   # Label master for Spark Master pod
   kubectl label nodes <master-node-name> node-role=master

   # Label workers for Spark Worker pods
   kubectl label nodes <worker-node-1> node-role=worker
   kubectl label nodes <worker-node-2> node-role=worker
   ```

3. **Update Deployments for Node Affinity**:
   Edit `spark-master-deployment.yaml`:
   ```yaml
   spec:
     template:
       spec:
         nodeSelector:
           node-role: master
   ```

   Edit `spark-worker-deployments.yaml`:
   ```yaml
   spec:
     template:
       spec:
         nodeSelector:
           node-role: worker
   ```

4. **Deploy the Cluster**:
   ```bash
   cd /home/user/cluster-hadoop/k8s
   ./deploy.sh
   ```

### 🌐 Step 5: VirtualBox Port Forwarding Configuration

When using VirtualBox, you need to configure port forwarding to access the Kubernetes services from your host machine.

#### 🔌 Port Forwarding Setup

For **each VirtualBox VM**, configure port forwarding in VirtualBox Manager:

1. **Right-click VM** → **Settings** → **Network** → **Advanced** → **Port Forwarding**

2. **Add rules for each service**:

| Service              | Host Port | Guest Port | Guest IP  | Description            |
|---------             |-----------|------------|---------- |-------------           |
| Spark Master UI      | 8080      | 30080      | 10.0.2.10 | Spark cluster overview |
| YARN ResourceManager | 8088      | 30088      | 10.0.2.10 | Hadoop YARN jobs       |
| HDFS NameNode        | 9870      | 30870      | 10.0.2.10 | HDFS file system       |
| Jupyter Notebook     | 8888      | 30888      | 10.0.2.10 | Interactive notebooks  |
| FastAPI              | 8000      | 30000      | 10.0.2.10 | Your microservice API  |
| Spark History Server | 18080     | 31080      | 10.0.2.10 | Completed Spark jobs   |
| Worker 1 UI          | 8081      | 30081      | 10.0.2.11 | Spark worker 1 status  |
| Worker 2 UI          | 8082      | 30082      | 10.0.2.12 | Spark worker 2 status  |
| Kubernetes API       | 6443      | 6443       | 10.0.2.10 | Kubectl access         |

#### 📝 Port Forwarding Rules Explanation

- **Host Port**: The port you access from your physical machine (localhost:8080)
- **Guest Port**: The Kubernetes NodePort service port inside the VM (30080)
- **Guest IP**: The VM's internal IP address (10.0.2.10 for master, 10.0.2.11/12 for workers)

#### 🌐 Access Services from Host Machine

After configuring port forwarding, access services from your host machine:

| Service               | URL from Host Machine   | Internal VM Address      |
|--------              -|----------------------   |-------------------       |
| Spark Master UI       | `http://localhost:8080` | `http://10.0.2.10:30080` |
| YARN ResourceManager  | `http://localhost:8088` | `http://10.0.2.10:30088` |
| HDFS NameNode         | `http://localhost:9870` | `http://10.0.2.10:30870` |
| Jupyter Notebook      | `http://localhost:8888` | `http://10.0.2.10:30888` |
| FastAPI               | `http://localhost:8000` | `http://10.0.2.10:30000` |
| Spark History Server  | `http://localhost:18080`| `http://10.0.2.10:31080` |
| Worker 1 UI           | `http://localhost:8081` | `http://10.0.2.11:30081` |
| Worker 2 UI           | `http://localhost:8082` | `http://10.0.2.12:30082` |

#### 🔧 Alternative: Bridge Network Access

If you prefer direct access without port forwarding, configure **Bridge Network**:

1. **VM Settings** → **Network** → **Adapter 1** → **Attached to: Bridged Adapter**
2. **Select your host network interface**
3. **VMs will get IPs from your router (e.g., 192.168.1.100-102)**
4. **Access directly**: `http://192.168.1.100:30080` (using actual VM IP)

### 📊 Step 6: Verify Multi-Node Operation

1. **Check Pod Distribution**:
   ```bash
   kubectl get pods -n spark-hadoop -o wide

   # Should show pods distributed across nodes:
   # NAME                            READY   STATUS    NODE
   # spark-master-xxx                1/1     Running   master
   # spark-worker-1-xxx              1/1     Running   worker1
   # spark-worker-2-xxx              1/1     Running   worker2
   ```

2. **Check Spark Worker Registration**:
   - Access Spark Master UI: `http://10.0.2.10:30080`
   - Verify workers from different VMs are registered

3. **Test Cross-Node Communication**:
   ```bash
   # From master pod, test connectivity to workers
   kubectl exec -it deployment/spark-master -n spark-hadoop -- \
     nc -zv spark-worker-1 8081
   ```

### 🔧 Troubleshooting Multi-VM Setup

#### Network Issues:
```bash
# Test inter-VM connectivity
ping 10.0.2.11  # From master to worker

# Check Kubernetes networking
kubectl get pods -n kube-system | grep calico

# Test pod-to-pod communication
kubectl exec -it <pod1> -- ping <pod2-ip>
```

#### Node Not Joining:
```bash
# On worker node, check kubelet logs
sudo journalctl -xeu kubelet

# Reset and retry join
sudo kubeadm reset
sudo systemctl restart kubelet
# Then retry join command
```

#### Persistent Volume Issues:
```bash
# Option 1: Set up NFS server on master
sudo apt-get install nfs-kernel-server
echo "/home/user/cluster-hadoop/user_data *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo systemctl restart nfs-kernel-server

# Option 2: Use shared storage or copy files to all nodes
for node in worker1 worker2; do
  scp -r /home/user/cluster-hadoop/user_data user@$node:/home/user/cluster-hadoop/
done
```

### 🎯 Advanced Multi-VM Features

#### Auto-Scaling Workers:
```bash
# Add more VMs and join them to cluster
# Then use the scaling script:
./scale-workers.sh add 3
./scale-workers.sh add 4

# Workers will automatically be scheduled on available nodes
```

#### Load Balancing:
```bash
# Use LoadBalancer service type if you have MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

# Configure IP pool for your VM network range
```

#### High Availability:
```bash
# For production, set up HA control plane with multiple masters
# Use external etcd cluster for better reliability
```

This multi-VM setup gives you a true distributed Kubernetes cluster running your Spark-Hadoop workloads across multiple VirtualBox machines!
