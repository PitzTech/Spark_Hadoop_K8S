#!/bin/bash

# Script para configurar 3 VMs para cluster Kubernetes

echo "=== Script de Setup para 3 VMs Kubernetes ==="
echo "Execute este script em cada VM do cluster"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo "Execute como root (sudo)"
    exit 1
fi

echo "1. Atualizando sistema..."
apt update && apt upgrade -y

echo "2. Instalando Docker..."
apt install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker $SUDO_USER

echo "3. Desabilitando swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "4. Configurando módulos do kernel..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

echo "5. Instalando kubeadm, kubelet, kubectl..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "6. Criando diretórios para volumes..."
mkdir -p /data/hadoop-master
mkdir -p /data/hadoop-worker1
mkdir -p /data/hadoop-worker2
chmod 777 /data/hadoop-*

echo "7. Baixando imagens Docker..."
docker pull raulcsouza/spark-base-hadoop
docker pull raulcsouza/spark-master-hadoop
docker pull raulcsouza/spark-worker-hadoop

echo ""
echo "=== Setup Concluído ==="
echo ""
echo "Para VM MASTER, execute:"
echo "sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
echo ""
echo "Para VMs WORKERS, execute o comando join que aparecerá no master"
echo ""
echo "Reinicie a VM para garantir que todas as configurações sejam aplicadas"