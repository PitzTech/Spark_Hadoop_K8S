# Cluster Hadoop/Spark no Kubernetes

Este diretório contém os manifests para deploy do cluster Hadoop/Spark no Kubernetes com 3 VMs.

## Pré-requisitos

### 1. Cluster Kubernetes (3 VMs)
- **VM1 (Master)**: Control Plane + Worker
- **VM2 (Worker)**: Worker Node 
- **VM3 (Worker)**: Worker Node

### 2. Instalação do Kubernetes

**Em todas as VMs:**
```bash
# Instalar Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Instalar kubeadm, kubelet, kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

**Na VM Master:**
```bash
# Inicializar cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurar kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Instalar CNI (Flannel)
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

**Nas VMs Workers:**
```bash
# Obter token do master e executar:
sudo kubeadm join <MASTER-IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash <HASH>
```

### 3. Preparar Imagens Docker

**Em cada VM, fazer pull das imagens:**
```bash
sudo docker pull raulcsouza/spark-base-hadoop
sudo docker pull raulcsouza/spark-master-hadoop  
sudo docker pull raulcsouza/spark-worker-hadoop
```

## Deploy do Cluster Hadoop

### 1. Criar diretórios de dados nas VMs
```bash
# Em cada VM, criar diretórios para volumes persistentes
sudo mkdir -p /data/hadoop-master
sudo mkdir -p /data/hadoop-worker1  
sudo mkdir -p /data/hadoop-worker2
sudo chmod 777 /data/hadoop-*
```

### 2. Deploy automático
```bash
cd kubernetes/
./deploy.sh
```

### 3. Deploy manual (passo a passo)
```bash
# 1. Namespace
kubectl apply -f manifests/namespace.yaml

# 2. Volumes persistentes
kubectl apply -f volumes/persistent-volumes.yaml

# 3. Services  
kubectl apply -f services/hadoop-services.yaml

# 4. Spark Master
kubectl apply -f manifests/spark-master-deployment.yaml

# 5. Spark Workers
kubectl apply -f manifests/spark-worker-deployments.yaml
```

## Verificar Deploy

```bash
# Status dos pods
kubectl get pods -n hadoop-cluster

# Status dos services
kubectl get services -n hadoop-cluster

# Logs do master
kubectl logs -f deployment/spark-master -n hadoop-cluster

# Logs dos workers
kubectl logs -f deployment/spark-worker1 -n hadoop-cluster
kubectl logs -f deployment/spark-worker2 -n hadoop-cluster
```

## Acessar Interfaces Web

**Obter IP do Node:**
```bash
kubectl get nodes -o wide
```

**URLs de Acesso:**
- **Spark Master UI**: http://`<NODE-IP>`:30080
- **Hadoop NameNode**: http://`<NODE-IP>`:30870  
- **YARN ResourceManager**: http://`<NODE-IP>`:30088
- **NodeManager**: http://`<NODE-IP>`:30042
- **Spark History Server**: http://`<NODE-IP>`:31080
- **Jupyter Notebook**: http://`<NODE-IP>`:30888
- **FastAPI**: http://`<NODE-IP>`:30000

## Escalar Workers

```bash
# Adicionar mais workers
kubectl scale deployment spark-worker1 --replicas=2 -n hadoop-cluster
kubectl scale deployment spark-worker2 --replicas=2 -n hadoop-cluster
```

## Remover Cluster

```bash
./undeploy.sh
```

## Troubleshooting

### Pods não iniciam
```bash
# Verificar eventos
kubectl describe pod <POD-NAME> -n hadoop-cluster

# Verificar logs
kubectl logs <POD-NAME> -n hadoop-cluster
```

### Volumes não funcionam
```bash
# Verificar PVs e PVCs
kubectl get pv
kubectl get pvc -n hadoop-cluster

# Criar diretórios manualmente se necessário
sudo mkdir -p /data/hadoop-master /data/hadoop-worker1 /data/hadoop-worker2
sudo chmod 777 /data/hadoop-*
```

### Services não acessíveis
```bash
# Verificar NodePort services
kubectl get svc -n hadoop-cluster

# Verificar se firewall está bloqueando
sudo ufw status
sudo ufw allow 30000:32000/tcp
```

## Arquitetura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   VM1 (Master)  │    │  VM2 (Worker1)  │    │  VM3 (Worker2)  │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Spark Master│ │    │ │Spark Worker1│ │    │ │Spark Worker2│ │
│ │ HDFS Name   │ │    │ │ HDFS Data   │ │    │ │ HDFS Data   │ │
│ │ YARN RM     │ │    │ │ YARN NM     │ │    │ │ YARN NM     │ │
│ │ Jupyter     │ │    │ │             │ │    │ │             │ │
│ │ History     │ │    │ │             │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Recursos

- **Master**: 4GB RAM, 2 CPU
- **Worker1**: 2GB RAM, 1 CPU  
- **Worker2**: 2GB RAM, 1 CPU
- **Storage**: 10GB por nó (hostPath)