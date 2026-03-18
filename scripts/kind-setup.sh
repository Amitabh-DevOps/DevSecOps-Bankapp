#!/bin/bash
# Kind Cluster Setup Script
# Vendor-neutral, community-based Kubernetes local cluster

CLUSTER_NAME="bankapp-kind-cluster"

echo "Creating Kind Cluster: $CLUSTER_NAME..."
# Create kind cluster with 80 and 443 ports forwarded for the Gateway
cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    protocol: TCP
  - containerPort: 30443
    hostPort: 443
    protocol: TCP
EOF

echo "Setting up Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

echo "Installing Envoy Gateway via Helm..."
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.1 \
  -n envoy-gateway-system \
  --create-namespace \
  --set service.type=LoadBalancer # Set to LoadBalancer for simulated cloud experience


echo "Waiting for Envoy Gateway system components..."
kubectl wait -n envoy-gateway-system \
  deployment/envoy-gateway \
  --for=condition=Available --timeout=5m

echo "Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods..."
kubectl wait -n argocd --for=condition=Ready pods --all --timeout=5m

echo "Kind Setup Complete!"
echo "--------------------------------------------------"
echo "ArgoCD Login Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
echo "--------------------------------------------------"
