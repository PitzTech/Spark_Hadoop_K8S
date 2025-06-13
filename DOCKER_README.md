# Cluster Hadoop e Spark com Docker

Este projeto configura um cluster Hadoop e Spark utilizando Docker.

## Pré-requisitos

### 1. Instalação do Docker

O Docker é obrigatório para executar este projeto. Instale usando os comandos abaixo:

#### Ubuntu/Debian:
```bash
# Atualizar pacotes
sudo apt-get update

# Instalar dependências
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release

# Adicionar chave GPG oficial do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Adicionar repositório Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Reiniciar sessão ou executar:
newgrp docker

# Verificar instalação
docker --version
docker compose version
```

#### CentOS/RHEL/Fedora:
```bash
# Instalar Docker
sudo dnf install docker docker-compose

# Iniciar e habilitar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Verificar Instalação
```bash
# Testar Docker
docker run hello-world

# Verificar Docker Compose
docker compose --version
```

## Configuração do Projeto

1. Instalar dependências adicionais:
   ```bash
   sudo apt-get install make curl

2. Inicie o projeto:
   ```bash
   sudo make build
   sudo docker compose up
   sudo docker compose up --build

   sudo docker logs spark-master
   sudo docker logs spark-worker-1
   sudo docker logs spark-worker-2


   sudo docker exec -it spark-master bash
   echo $HADOOP_HOME
   /path/to/hadoop/sbin/start-dfs.sh
   ...

3. Para parar o projeto:
   ```bash
   sudo docker compose down
   ...





