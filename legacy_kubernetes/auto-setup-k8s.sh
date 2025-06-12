#!/bin/bash

# Script automatizado para setup completo do cluster Kubernetes Hadoop/Spark
# Funciona para VMs do VirtualBox

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}    SETUP AUTOMATIZADO - CLUSTER KUBERNETES HADOOP/SPARK${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Execute como root: sudo $0${NC}"
    exit 1
fi

# Obter usuário real (não root)
REAL_USER=${SUDO_USER:-$(logname)}
USER_HOME=$(eval echo ~$REAL_USER)

# Validar recursos mínimos do sistema
echo -e "${BLUE}🔍 Verificando recursos do sistema...${NC}"
TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
TOTAL_CPU=$(nproc)

if [ $TOTAL_RAM -lt 2048 ]; then
    echo -e "${RED}❌ RAM insuficiente! Mínimo: 2GB, Disponível: ${TOTAL_RAM}MB${NC}"
    exit 1
fi

if [ $TOTAL_CPU -lt 2 ]; then
    echo -e "${RED}❌ CPU insuficiente! Mínimo: 2 cores, Disponível: ${TOTAL_CPU}${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Recursos suficientes: ${TOTAL_RAM}MB RAM, ${TOTAL_CPU} CPUs${NC}"

echo -e "${YELLOW}🔧 Configuração inicial...${NC}"
echo ""

# Selecionar tipo de nó
echo -e "${BLUE}Selecione o tipo de nó:${NC}"
echo "1) Master (Control Plane)"
echo "2) Worker"
echo ""
read -p "Digite sua escolha (1 ou 2): " NODE_TYPE

case $NODE_TYPE in
    1)
        NODE_ROLE="master"
        echo -e "${GREEN}✅ Configurando como MASTER${NC}"
        ;;
    2)
        NODE_ROLE="worker"
        echo -e "${GREEN}✅ Configurando como WORKER${NC}"
        ;;
    *)
        echo -e "${RED}❌ Opção inválida!${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}🚀 Iniciando instalação...${NC}"
echo ""

# 1. Atualizar sistema
echo -e "${BLUE}📦 Atualizando sistema...${NC}"
apt update && apt upgrade -y

# 2. Instalar dependências básicas
echo -e "${BLUE}📦 Instalando dependências...${NC}"
apt install -y curl wget apt-transport-https ca-certificates software-properties-common

# 3. Instalar Docker
echo -e "${BLUE}🐳 Instalando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
fi

systemctl enable docker
systemctl start docker
usermod -aG docker $REAL_USER

# 4. Configurar containerd para Kubernetes
echo -e "${BLUE}⚙️  Configurando containerd...${NC}"
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# Configurar Docker para Kubernetes
echo -e "${BLUE}⚙️  Configurando Docker...${NC}"
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl restart docker

# 5. Desabilitar swap
echo -e "${BLUE}💾 Desabilitando swap...${NC}"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 6. Configurar módulos do kernel
echo -e "${BLUE}🔧 Configurando módulos do kernel...${NC}"

# Carregar módulos necessários
modprobe br_netfilter
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe overlay

cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
overlay
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# 7. Instalar Kubernetes
echo -e "${BLUE}☸️  Instalando Kubernetes...${NC}"
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 8. Criar diretórios para volumes
echo -e "${BLUE}📁 Criando diretórios para volumes...${NC}"
mkdir -p /data/hadoop-master
mkdir -p /data/hadoop-worker1
mkdir -p /data/hadoop-worker2
# Usar permissões mais seguras
chmod 755 /data/hadoop-*
chown root:root /data/hadoop-*

# 9. Baixar imagens Docker
echo -e "${BLUE}📥 Baixando imagens Docker Hadoop/Spark...${NC}"
docker pull apache/spark:3.4.0
docker pull apache/hadoop:3
echo -e "${GREEN}✅ Imagens Docker baixadas com sucesso!${NC}"

# 10. Obter IP da máquina de forma robusta
get_machine_ip() {
    # Tentar múltiplos métodos para obter o IP
    local ip=""

    # Método 1: via rota padrão
    ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7}' | head -1)

    # Método 2: se falhou, tentar interface padrão
    if [ -z "$ip" ]; then
        ip=$(ip route | grep default | awk '{print $5}' | head -1 | xargs ip addr show | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1)
    fi

    # Método 3: se ainda falhou, listar todas as interfaces
    if [ -z "$ip" ]; then
        ip=$(hostname -I | awk '{print $1}')
    fi

    echo "$ip"
}

MACHINE_IP=$(get_machine_ip)
echo -e "${GREEN}🌐 IP desta máquina: ${MACHINE_IP}${NC}"

# Configurações específicas do nó
if [ "$NODE_ROLE" = "master" ]; then
    echo ""
    echo -e "${YELLOW}🏛️  CONFIGURAÇÃO MASTER${NC}"
    echo ""

    # Inicializar cluster
    echo -e "${BLUE}🚀 Inicializando cluster Kubernetes...${NC}"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$MACHINE_IP --apiserver-bind-address=0.0.0.0 > /tmp/kubeadm-init.log 2>&1

    # Configurar kubectl para usuário
    echo -e "${BLUE}⚙️  Configurando kubectl...${NC}"
    mkdir -p $USER_HOME/.kube
    cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    chown $REAL_USER:$REAL_USER $USER_HOME/.kube/config

    # Configurar kubectl para root também
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config

    # Instalar CNI (Flannel)
    echo -e "${BLUE}🌐 Instalando CNI (Flannel)...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

    # Permitir pods no master (para clusters pequenos)
    echo -e "${BLUE}🔓 Removendo taint do master...${NC}"
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || echo "Taint control-plane já removido ou não existe"
    kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || echo "Taint master já removido ou não existe"

    # Aguardar cluster estar pronto
    echo -e "${BLUE}⏳ Aguardando cluster estar pronto...${NC}"
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s

    # Criar manifests localmente
    echo -e "${BLUE}📝 Criando manifests Kubernetes...${NC}"

    # Namespace
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hadoop-cluster
  labels:
    name: hadoop-cluster
EOF

    # PersistentVolumes
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hadoop-master-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data/hadoop-master
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hadoop-worker1-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data/hadoop-worker1
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hadoop-worker2-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data/hadoop-worker2
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hadoop-master-pvc
  namespace: hadoop-cluster
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hadoop-worker1-pvc
  namespace: hadoop-cluster
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hadoop-worker2-pvc
  namespace: hadoop-cluster
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
EOF

    # Services
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: spark-master-service
  namespace: hadoop-cluster
  labels:
    app: spark-master
spec:
  type: NodePort
  ports:
    - port: 8080
      nodePort: 30080
      name: spark-web
    - port: 7077
      nodePort: 30077
      name: spark-master
    - port: 9870
      nodePort: 30870
      name: namenode-web
    - port: 8888
      nodePort: 30888
      name: jupyter
    - port: 8088
      nodePort: 30088
      name: resourcemanager
    - port: 8042
      nodePort: 30042
      name: nodemanager
    - port: 18080
      nodePort: 31080
      name: history-server
    - port: 8000
      nodePort: 30000
      name: fastapi
  selector:
    app: spark-master
EOF

    # Spark Master Deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-master
  namespace: hadoop-cluster
  labels:
    app: spark-master
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark-master
  template:
    metadata:
      labels:
        app: spark-master
    spec:
      hostname: spark-master
      containers:
      - name: spark-master
        image: apache/spark:3.4.0
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args: ["-c", "/opt/spark/bin/spark-class org.apache.spark.deploy.master.Master"]
        ports:
        - containerPort: 8080
        - containerPort: 7077
        - containerPort: 9870
        - containerPort: 8888
        - containerPort: 8088
        - containerPort: 8042
        - containerPort: 18080
        - containerPort: 8000
        env:
        - name: SPARK_LOCAL_IP
          value: "spark-master"
        - name: SPARK_MASTER_HOST
          value: "spark-master"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        volumeMounts:
        - name: hadoop-data
          mountPath: /user_data
      volumes:
      - name: hadoop-data
        persistentVolumeClaim:
          claimName: hadoop-master-pvc
EOF

    # Workers Deployments
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-worker1
  namespace: hadoop-cluster
  labels:
    app: spark-worker1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark-worker1
  template:
    metadata:
      labels:
        app: spark-worker1
    spec:
      hostname: spark-worker-1
      containers:
      - name: spark-worker
        image: apache/spark:3.4.0
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args: ["-c", "/opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker spark://spark-master:7077"]
        ports:
        - containerPort: 8081
        - containerPort: 8042
        env:
        - name: SPARK_LOCAL_IP
          value: "spark-worker-1"
        - name: SPARK_MASTER
          value: "spark://spark-master:7077"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: worker-data
          mountPath: /user_data
      volumes:
      - name: worker-data
        persistentVolumeClaim:
          claimName: hadoop-worker1-pvc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-worker2
  namespace: hadoop-cluster
  labels:
    app: spark-worker2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark-worker2
  template:
    metadata:
      labels:
        app: spark-worker2
    spec:
      hostname: spark-worker-2
      containers:
      - name: spark-worker
        image: apache/spark:3.4.0
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args: ["-c", "/opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker spark://spark-master:7077"]
        ports:
        - containerPort: 8081
        - containerPort: 8042
        env:
        - name: SPARK_LOCAL_IP
          value: "spark-worker-2"
        - name: SPARK_MASTER
          value: "spark://spark-master:7077"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: worker-data
          mountPath: /user_data
      volumes:
      - name: worker-data
        persistentVolumeClaim:
          claimName: hadoop-worker2-pvc
EOF

    echo -e "${BLUE}⏳ Aguardando pods estarem prontos...${NC}"
    sleep 60

    # Escalar workers
    echo -e "${BLUE}📈 Escalonando workers...${NC}"
    kubectl scale deployment spark-worker1 --replicas=2 -n hadoop-cluster
    kubectl scale deployment spark-worker2 --replicas=2 -n hadoop-cluster

    # Aguardar escalonamento
    sleep 30

    # Verificar deploy
    echo ""
    echo -e "${YELLOW}🔍 VERIFICAÇÃO DO DEPLOY${NC}"
    echo ""
    kubectl get nodes
    echo ""
    kubectl get pods -n hadoop-cluster
    echo ""
    kubectl get services -n hadoop-cluster

    # Obter token para workers
    echo -e "${BLUE}🔑 Gerando token para workers...${NC}"
    JOIN_COMMAND=$(kubeadm token create --print-join-command 2>/dev/null)

    if [ -z "$JOIN_COMMAND" ]; then
        echo -e "${RED}❌ Erro ao gerar token. Tentando novamente...${NC}"
        sleep 10
        JOIN_COMMAND=$(kubeadm token create --print-join-command)
    fi

    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}                    ✅ MASTER CONFIGURADO!${NC}"
    echo -e "${GREEN}=================================================================${NC}"
    echo ""
    echo -e "${YELLOW}📋 INFORMAÇÕES IMPORTANTES:${NC}"
    echo ""
    echo -e "${BLUE}🌐 IP do Master: ${GREEN}${MACHINE_IP}${NC}"
    echo ""
    echo -e "${BLUE}🔗 Comando para Workers:${NC}"
    echo -e "${YELLOW}${JOIN_COMMAND}${NC}"
    echo ""
    echo -e "${BLUE}🌐 URLs dos Serviços (use IP do Node):${NC}"
    echo "• Spark Master UI:      http://${MACHINE_IP}:30080"
    echo "• Hadoop NameNode:      http://${MACHINE_IP}:30870"
    echo "• YARN ResourceManager: http://${MACHINE_IP}:30088"
    echo "• NodeManager:          http://${MACHINE_IP}:30042"
    echo "• Spark History:        http://${MACHINE_IP}:31080"
    echo "• Jupyter Notebook:     http://${MACHINE_IP}:30888"
    echo "• FastAPI:              http://${MACHINE_IP}:30000"
    echo ""
    echo -e "${YELLOW}⚠️  CONFIGURAÇÃO VIRTUALBOX:${NC}"
    echo "Configure redirecionamento de portas no VirtualBox:"
    echo "Host: 30080 → Guest: 30080 (Spark Master)"
    echo "Host: 30870 → Guest: 30870 (NameNode)"
    echo "Host: 30888 → Guest: 30888 (Jupyter)"
    echo "Host: 30088 → Guest: 30088 (ResourceManager)"
    echo "Host: 30042 → Guest: 30042 (NodeManager)"
    echo "Host: 31080 → Guest: 31080 (History Server)"
    echo "Host: 30000 → Guest: 30000 (FastAPI)"
    echo ""
    echo -e "${GREEN}Execute este script nas VMs Workers usando o comando join acima!${NC}"

else
    # CONFIGURAÇÃO WORKER
    echo ""
    echo -e "${YELLOW}👷 CONFIGURAÇÃO WORKER${NC}"
    echo ""

    echo -e "${BLUE}Digite o comando de join do master:${NC}"
    echo "Exemplo: kubeadm join 192.168.1.100:6443 --token abc123... --discovery-token-ca-cert-hash sha256:def456..."
    echo ""
    read -p "Comando join: " JOIN_COMMAND

    if [ -z "$JOIN_COMMAND" ]; then
        echo -e "${RED}❌ Comando join não pode estar vazio!${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔗 Conectando ao cluster...${NC}"

    # Validar formato do comando join
    if [[ ! "$JOIN_COMMAND" =~ ^kubeadm\ join.* ]]; then
        echo -e "${RED}❌ Comando join inválido!${NC}"
        exit 1
    fi

    # Executar join com retry
    for i in {1..3}; do
        echo -e "${BLUE}Tentativa $i de 3...${NC}"
        if $JOIN_COMMAND; then
            echo -e "${GREEN}✅ Conectado com sucesso!${NC}"
            break
        else
            if [ $i -eq 3 ]; then
                echo -e "${RED}❌ Falha ao conectar após 3 tentativas${NC}"
                exit 1
            fi
            echo -e "${YELLOW}⚠️  Tentativa $i falhou. Aguardando 10s...${NC}"
            sleep 10
        fi
    done

    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}                    ✅ WORKER CONFIGURADO!${NC}"
    echo -e "${GREEN}=================================================================${NC}"
    echo ""
    echo -e "${BLUE}🌐 IP deste Worker: ${GREEN}${MACHINE_IP}${NC}"
    echo ""
    echo -e "${GREEN}Worker conectado ao cluster com sucesso!${NC}"
    echo -e "${YELLOW}Verifique no master com: kubectl get nodes${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Setup concluído com sucesso!${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos passos:${NC}"
if [ "$NODE_ROLE" = "master" ]; then
    echo "1. Execute este script nas VMs Workers"
    echo "2. Configure redirecionamento de portas no VirtualBox"
    echo "3. Acesse as interfaces web usando as URLs acima"
else
    echo "1. Worker está pronto e conectado ao cluster"
    echo "2. Verifique no master: kubectl get nodes"
fi
echo ""
echo -e "${BLUE}💡 Para monitorar: kubectl get pods -n hadoop-cluster -w${NC}"
