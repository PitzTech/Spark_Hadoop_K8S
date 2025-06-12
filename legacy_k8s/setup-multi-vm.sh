#!/bin/bash

# Multi-VM Kubernetes Setup Helper Script
# This script helps configure the deployments for multi-VM setup

NAMESPACE="spark-hadoop"

function show_usage() {
    echo "Multi-VM Kubernetes Setup Helper"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  configure-nfs <master-ip>    Configure NFS for shared storage"
    echo "  add-node-selectors          Add node selectors to deployments"
    echo "  check-nodes                 Check node status and labels"
    echo "  label-nodes                 Help label nodes for scheduling"
    echo "  test-connectivity          Test inter-pod connectivity"
    echo ""
    echo "Examples:"
    echo "  $0 configure-nfs 10.0.2.10"
    echo "  $0 add-node-selectors"
    echo "  $0 check-nodes"
}

function configure_nfs() {
    local master_ip=$1
    
    if [ -z "$master_ip" ]; then
        echo "Error: Please specify master IP address"
        show_usage
        exit 1
    fi
    
    echo "Configuring NFS for multi-VM setup with master at $master_ip..."
    
    # Update persistent-volumes.yaml for NFS
    cat > persistent-volumes.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: user-data-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: $master_ip
    path: /home/user/cluster-hadoop/user_data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: user-data-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
EOF
    
    echo "Updated persistent-volumes.yaml for NFS with server $master_ip"
    echo ""
    echo "On the master VM ($master_ip), run:"
    echo "  sudo apt-get install nfs-kernel-server"
    echo "  echo '/home/user/cluster-hadoop/user_data *(rw,sync,no_subtree_check)' | sudo tee -a /etc/exports"
    echo "  sudo systemctl restart nfs-kernel-server"
    echo ""
    echo "On worker VMs, run:"
    echo "  sudo apt-get install nfs-common"
}

function add_node_selectors() {
    echo "Adding node selectors to deployments..."
    
    # Check if files exist
    if [ ! -f "spark-master-deployment.yaml" ]; then
        echo "Error: spark-master-deployment.yaml not found in current directory"
        exit 1
    fi
    
    # Add node selector to master deployment
    if ! grep -q "nodeSelector:" spark-master-deployment.yaml; then
        # Find the spec.template.spec section and add nodeSelector
        sed -i '/spec:/,/template:/,/spec:/{
            /template:/,/spec:/{
                /spec:/a\
        nodeSelector:\
          node-role: master
            }
        }' spark-master-deployment.yaml
        echo "Added node selector to spark-master-deployment.yaml"
    else
        echo "Node selector already exists in spark-master-deployment.yaml"
    fi
    
    # Add node selector to worker deployments
    if ! grep -q "nodeSelector:" spark-worker-deployments.yaml; then
        sed -i '/spec:/,/template:/,/spec:/{
            /template:/,/spec:/{
                /spec:/a\
        nodeSelector:\
          node-role: worker
            }
        }' spark-worker-deployments.yaml
        echo "Added node selector to spark-worker-deployments.yaml"
    else
        echo "Node selector already exists in spark-worker-deployments.yaml"
    fi
    
    echo "Node selectors added successfully!"
}

function check_nodes() {
    echo "=== Kubernetes Nodes Status ==="
    kubectl get nodes -o wide
    echo ""
    
    echo "=== Node Labels ==="
    kubectl get nodes --show-labels
    echo ""
    
    echo "=== Pods Distribution ==="
    kubectl get pods -n $NAMESPACE -o wide 2>/dev/null || echo "No pods found in $NAMESPACE namespace"
    echo ""
    
    echo "=== Cluster Info ==="
    kubectl cluster-info
}

function label_nodes() {
    echo "=== Current Nodes ==="
    kubectl get nodes
    echo ""
    
    echo "To label nodes for proper scheduling, run:"
    echo ""
    echo "# Label master node:"
    echo "kubectl label nodes <master-node-name> node-role=master"
    echo ""
    echo "# Label worker nodes:"
    echo "kubectl label nodes <worker-node-1-name> node-role=worker"
    echo "kubectl label nodes <worker-node-2-name> node-role=worker"
    echo ""
    echo "Replace <node-name> with actual node names from the list above."
    echo ""
    echo "Example:"
    read -p "Enter master node name (or press Enter to skip): " master_node
    if [ ! -z "$master_node" ]; then
        kubectl label nodes $master_node node-role=master
        echo "Master node $master_node labeled successfully!"
    fi
    
    echo ""
    echo "Enter worker node names (press Enter after each, empty line to finish):"
    while true; do
        read -p "Worker node name: " worker_node
        if [ -z "$worker_node" ]; then
            break
        fi
        kubectl label nodes $worker_node node-role=worker
        echo "Worker node $worker_node labeled successfully!"
    done
}

function test_connectivity() {
    echo "Testing inter-pod connectivity..."
    
    # Check if pods are running
    master_pod=$(kubectl get pods -n $NAMESPACE -l app=spark-master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    worker_pods=$(kubectl get pods -n $NAMESPACE --no-headers | grep spark-worker | awk '{print $1}')
    
    if [ -z "$master_pod" ]; then
        echo "No master pod found. Deploy the cluster first."
        return 1
    fi
    
    echo "Master pod: $master_pod"
    echo "Testing connectivity from master to workers..."
    
    for worker_pod in $worker_pods; do
        echo "Testing connection to $worker_pod..."
        worker_ip=$(kubectl get pod $worker_pod -n $NAMESPACE -o jsonpath='{.status.podIP}')
        if [ ! -z "$worker_ip" ]; then
            kubectl exec $master_pod -n $NAMESPACE -- nc -zv $worker_ip 8081 2>/dev/null \
                && echo "✓ Connection to $worker_pod ($worker_ip) successful" \
                || echo "✗ Connection to $worker_pod ($worker_ip) failed"
        else
            echo "✗ Could not get IP for $worker_pod"
        fi
    done
    
    echo ""
    echo "Testing service discovery..."
    kubectl exec $master_pod -n $NAMESPACE -- nslookup spark-worker-1-service 2>/dev/null \
        && echo "✓ Service discovery working" \
        || echo "✗ Service discovery failed"
}

# Main script logic
case "$1" in
    "configure-nfs")
        configure_nfs $2
        ;;
    "add-node-selectors")
        add_node_selectors
        ;;
    "check-nodes")
        check_nodes
        ;;
    "label-nodes")
        label_nodes
        ;;
    "test-connectivity")
        test_connectivity
        ;;
    *)
        show_usage
        exit 1
        ;;
esac