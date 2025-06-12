#!/bin/bash

# Script para corrigir configuração do containerd
# Execute como root: sudo ./fix-containerd.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Corrigindo configuração do containerd...${NC}"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Execute como root: sudo $0${NC}"
    exit 1
fi

# Parar serviços
echo -e "${YELLOW}⏹️  Parando serviços...${NC}"
systemctl stop kubelet || true
systemctl stop containerd || true

# Remover configuração antiga do containerd
echo -e "${YELLOW}🗑️  Removendo configuração antiga...${NC}"
rm -f /etc/containerd/config.toml

# Gerar nova configuração padrão
echo -e "${YELLOW}⚙️  Gerando nova configuração...${NC}"
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Modificar a configuração para usar systemd cgroup driver
echo -e "${YELLOW}🔄 Configurando systemd cgroup driver...${NC}"
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Reiniciar containerd
echo -e "${YELLOW}🔄 Reiniciando containerd...${NC}"
systemctl enable containerd
systemctl restart containerd

# Verificar se containerd está funcionando
sleep 5
if systemctl is-active --quiet containerd; then
    echo -e "${GREEN}✅ Containerd está funcionando!${NC}"
else
    echo -e "${RED}❌ Erro: containerd não está funcionando${NC}"
    exit 1
fi

# Reiniciar kubelet
echo -e "${YELLOW}🔄 Reiniciando kubelet...${NC}"
systemctl enable kubelet
systemctl restart kubelet

# Reset kubeadm para limpar estado anterior
echo -e "${YELLOW}🔄 Resetando kubeadm...${NC}"
kubeadm reset -f || true

# Limpar iptables
echo -e "${YELLOW}🧹 Limpando iptables...${NC}"
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

# Remover CNI
echo -e "${YELLOW}🧹 Limpando CNI...${NC}"
rm -rf /etc/cni/net.d/*
rm -rf /var/lib/cni/

echo -e "${GREEN}✅ Correção concluída!${NC}"
echo -e "${YELLOW}Agora você pode executar novamente o auto-setup-k8s.sh${NC}"
