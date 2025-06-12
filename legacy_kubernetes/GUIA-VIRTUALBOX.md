# Guia de Configuração VirtualBox para Cluster Kubernetes

## 🖥️ Configuração das VMs

### 1. Criar 3 VMs Ubuntu Server

**Especificações mínimas por VM:**
- **RAM**: 4GB (Master), 2GB (Workers)
- **CPU**: 2 cores (Master), 1 core (Workers)
- **Disco**: 20GB
- **OS**: Ubuntu Server 22.04 LTS

### 2. Configuração de Rede

**Para cada VM, configure 2 adaptadores de rede:**

#### Adaptador 1 (NAT) - Para acesso à internet
- Tipo: NAT
- Usado para: Download de pacotes, imagens Docker

#### Adaptador 2 (Host-Only ou Bridged) - Para comunicação entre VMs
- Tipo: Rede interna ou Host-Only
- Usado para: Comunicação do cluster Kubernetes

### 3. Redirecionamento de Portas (Port Forwarding)

**Configure no VirtualBox para a VM Master:**

1. **VM Master → Configurações → Rede → Adaptador 1 → Avançado → Redirecionamento de Portas**

|       Nome      | Protocolo | IP Host | Porta Host | IP Convidado | Porta Convidado |
|-----------------|-----------|---------|------------|--------------|-----------------|
| spark-master    |    TCP    |         |    8080    |              |      30080      |
| namenode        |    TCP    |         |    9870    |              |      30870      |
| resourcemanager |    TCP    |         |    8088    |              |      30088      |
| nodemanager     |    TCP    |         |    8042    |              |      30042      |
| jupyter         |    TCP    |         |    8888    |              |      30888      |
| history-server  |    TCP    |         |    18080   |              |      31080      |
| fastapi         |    TCP    |         |    8000    |              |      30000      |
| kubernetes-api  |    TCP    |         |    6443    |              |      6443       |

## 🚀 Execução do Script

### 1. VM Master (primeira VM)

```bash
# Na VM Master
sudo chmod +x fix-containerd.sh
sudo ./fix-containerd.sh

sudo chmod +x auto-setup-k8s.sh
sudo ./auto-setup-k8s.sh

# Selecionar: 1 (Master)
```

**O script irá:**
- ✅ Instalar Docker, Kubernetes
- ✅ Inicializar cluster como master
- ✅ Fazer deploy do cluster Hadoop/Spark
- ✅ Escalar workers automaticamente
- ✅ Mostrar URLs de acesso
- ✅ Fornecer comando para workers

### 2. VMs Workers (segunda e terceira VMs)

```bash
# Em cada VM Worker
sudo chmod +x fix-containerd.sh
sudo ./fix-containerd.sh

sudo chmod +x auto-setup-k8s.sh
sudo ./auto-setup-k8s.sh

# Selecionar: 2 (Worker)
# Inserir comando join fornecido pelo master
```

## 🌐 Acessar Interfaces (Windows Host)

Após o setup completo, acesse pelo navegador do Windows:

- **Spark Master UI**: http://localhost:8080
- **Hadoop NameNode**: http://localhost:9870
- **YARN ResourceManager**: http://localhost:8088
- **NodeManager**: http://localhost:8042
- **Spark History**: http://localhost:18080
- **Jupyter Notebook**: http://localhost:8888
- **FastAPI**: http://localhost:8000

## 🔧 Troubleshooting

### Problema: VMs não se comunicam
**Solução:**
```bash
# Verificar IPs das VMs
ip addr show

# Testar conectividade
ping <ip-da-outra-vm>

# Verificar firewall
sudo ufw status
sudo ufw allow from <subnet-das-vms>
```

### Problema: Portas não acessíveis do Windows
**Verificar:**
1. Redirecionamento configurado no VirtualBox
2. Firewall do Windows
3. Serviços rodando na VM: `kubectl get svc -n hadoop-cluster`

### Problema: Pods não iniciam
**Verificar:**
```bash
# Status dos pods
kubectl get pods -n hadoop-cluster

# Logs de um pod específico
kubectl logs <pod-name> -n hadoop-cluster

# Eventos do cluster
kubectl get events -n hadoop-cluster
```

### Problema: Join command não funciona
**Solução:**
```bash
# No master, gerar novo token
kubeadm token create --print-join-command

# Usar o novo comando no worker
```

## 📝 Comandos Úteis

### Verificar Status do Cluster
```bash
# Nodes do cluster
kubectl get nodes

# Pods do Hadoop
kubectl get pods -n hadoop-cluster

# Services
kubectl get svc -n hadoop-cluster

# Logs em tempo real
kubectl logs -f deployment/spark-master -n hadoop-cluster
```

### Escalar Workers
```bash
# Aumentar réplicas
kubectl scale deployment spark-worker1 --replicas=3 -n hadoop-cluster
kubectl scale deployment spark-worker2 --replicas=3 -n hadoop-cluster

# Verificar escalonamento
kubectl get pods -n hadoop-cluster -w
```

### Reiniciar Cluster
```bash
# Deletar todos os pods
kubectl delete pods --all -n hadoop-cluster

# Pods serão recriados automaticamente
```

## 🎯 Resultado Final

**Cluster Kubernetes com:**
- ✅ 1 Master node com Control Plane
- ✅ 2+ Worker nodes
- ✅ Cluster Hadoop/Spark distribuído
- ✅ Todas as interfaces web funcionando
- ✅ Escalabilidade automática
- ✅ Volumes persistentes
- ✅ Acesso via port forwarding do VirtualBox

**Aplicações rodando:**
- 🔥 Spark Master + History Server
- 📁 HDFS (NameNode + DataNodes)
- 🧵 YARN (ResourceManager + NodeManagers)
- 📓 Jupyter Notebook
- 🚀 FastAPI Microservice
- 📊 Todas as interfaces de monitoramento
