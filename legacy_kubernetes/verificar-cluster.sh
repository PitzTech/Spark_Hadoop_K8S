#!/bin/bash

# Script para verificar status do cluster Kubernetes Hadoop/Spark

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}           VERIFICAÇÃO DO CLUSTER KUBERNETES HADOOP${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl não encontrado!${NC}"
    exit 1
fi

echo -e "${YELLOW}🔍 Status dos Nodes:${NC}"
kubectl get nodes -o wide
echo ""

echo -e "${YELLOW}🔍 Status dos Pods Hadoop:${NC}"
kubectl get pods -n hadoop-cluster -o wide
echo ""

echo -e "${YELLOW}🔍 Status dos Services:${NC}"
kubectl get services -n hadoop-cluster
echo ""

echo -e "${YELLOW}🔍 Status dos PersistentVolumes:${NC}"
kubectl get pv
echo ""

echo -e "${YELLOW}🔍 Status dos PersistentVolumeClaims:${NC}"
kubectl get pvc -n hadoop-cluster
echo ""

# Obter IP do primeiro node
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

if [ -n "$NODE_IP" ]; then
    echo -e "${GREEN}🌐 URLs dos Serviços:${NC}"
    echo "• Spark Master UI:      http://${NODE_IP}:30080"
    echo "• Hadoop NameNode:      http://${NODE_IP}:30870"
    echo "• YARN ResourceManager: http://${NODE_IP}:30088"
    echo "• NodeManager:          http://${NODE_IP}:30042"
    echo "• Spark History:        http://${NODE_IP}:31080"
    echo "• Jupyter Notebook:     http://${NODE_IP}:30888"
    echo "• FastAPI:              http://${NODE_IP}:30000"
    echo ""
fi

# Verificar se pods estão rodando
RUNNING_PODS=$(kubectl get pods -n hadoop-cluster --field-selector=status.phase=Running --no-headers | wc -l)
TOTAL_PODS=$(kubectl get pods -n hadoop-cluster --no-headers | wc -l)

echo -e "${YELLOW}📊 Resumo:${NC}"
echo "• Pods rodando: ${RUNNING_PODS}/${TOTAL_PODS}"

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Cluster está funcionando corretamente!${NC}"
else
    echo -e "${YELLOW}⚠️  Alguns pods podem estar iniciando...${NC}"
    echo ""
    echo -e "${BLUE}🔍 Pods com problemas:${NC}"
    kubectl get pods -n hadoop-cluster | grep -v Running | grep -v Completed
    echo ""
    echo -e "${BLUE}💡 Para ver logs de um pod:${NC}"
    echo "kubectl logs <pod-name> -n hadoop-cluster"
fi

echo ""
echo -e "${BLUE}🔄 Para monitorar em tempo real:${NC}"
echo "kubectl get pods -n hadoop-cluster -w"