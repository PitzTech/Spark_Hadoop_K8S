# Distributed Spark/Hadoop Cluster

This project provides a distributed Apache Spark and Hadoop cluster that can be deployed using either Docker Compose or Kubernetes.

## Deployment Options

Choose your preferred deployment method:

### 🐳 Docker Compose (Local Development)
- **File**: `DOCKER_README.md`
- **Best for**: Local development, testing, quick setup
- **Requirements**: Docker, Docker Compose
- **Setup time**: ~5 minutes

### ☸️ Kubernetes (Distributed/Production)
- **File**: `K8S-README.md` 
- **Best for**: Distributed deployment, production-like environments
- **Requirements**: MicroK8s, Multipass (or any K8s cluster)
- **Setup time**: ~30 minutes

## Quick Start

### Option 1: Docker Compose
```bash
# Build images and start cluster
make build
docker-compose up -d

# Access interfaces
# Spark Master: http://localhost:8080
# Hadoop NameNode: http://localhost:9870
# YARN ResourceManager: http://localhost:8088
```

### Option 2: Kubernetes
```bash
# Build images
make build

# Follow detailed instructions in K8S-README.md
# for VM setup and cluster deployment
```

## Architecture

- **Master Node**: Spark Master + Hadoop NameNode + YARN ResourceManager
- **Worker Nodes**: Spark Workers + Hadoop DataNodes + YARN NodeManagers
- **Scalable**: Workers can be scaled up/down based on workload

## Project Structure

```
cluster-hadoop/
├── README.md                   # This file
├── DOCKER_README.md           # Docker Compose setup guide
├── K8S-README.md             # Kubernetes setup guide
├── Makefile                  # Build automation
├── docker-compose.yml        # Docker Compose configuration
├── k8s/                      # Kubernetes manifests
├── hadoop/                   # Docker images
│   ├── spark-base/          # Base image
│   ├── spark-master/        # Master node image
│   └── spark-worker/        # Worker node image
└── user_data/               # Sample data and notebooks
```

## Features

- **Auto-download**: Dependencies downloaded automatically via Makefile
- **Local images**: No internet dependency during deployment
- **Web interfaces**: Access Spark, Hadoop, and YARN UIs
- **Jupyter integration**: Built-in Jupyter notebook support
- **Sample data**: Includes Project Gutenberg texts for testing
- **Scalable workers**: Easy horizontal scaling

## Getting Started

1. **Choose your deployment method** based on your needs
2. **Read the appropriate README**:
   - For local development → `DOCKER_README.md`
   - For distributed setup → `K8S-README.md`
3. **Run `make build`** to automatically build all images
4. **Follow the deployment steps** in your chosen guide

## Requirements

### Common
- Docker
- Make
- curl (for auto-downloads)

### Docker Compose
- Docker Compose

### Kubernetes  
- MicroK8s or any Kubernetes cluster
- Multipass (for VM-based setup)

## Support

For deployment-specific issues, refer to the troubleshooting sections in:
- `DOCKER_README.md` - Docker Compose issues
- `K8S-README.md` - Kubernetes deployment issues

---

**Choose your path and follow the detailed instructions in the corresponding README file!**