#!/bin/bash
# Kind Cluster Setup Script - Vendor Neutral
# Automatically detects Public IP for nip.io configuration

CLUSTER_NAME="bankapp-kind-cluster"

echo "Creating Kind Cluster: $CLUSTER_NAME..."
# Create kind cluster with 80 and 443 ports forwarded for the Gateway
cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.35.0
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
# Use server-side apply to avoid oversized annotation errors on CRDs.
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods..."
kubectl wait -n argocd --for=condition=Ready pods --all --timeout=5m

echo "Patching Envoy Gateway Service to NodePort..."
# The Envoy data-plane service is created dynamically when a Gateway resource is applied.
# We will wait up to 1 minute for it to appear (in case ArgoCD or a manual apply triggers it)
echo "Waiting for Envoy data-plane service to be created (this may take a moment)..."
for i in {1..12}; do
  ENVOY_SVC_NAME=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/own-gateway-name=bankapp-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "$ENVOY_SVC_NAME" ]; then
    ENVOY_SVC_NAME=$(kubectl get svc -n envoy-gateway-system -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' | head -n1 2>/dev/null || true)
  fi
  
  if [ -n "$ENVOY_SVC_NAME" ]; then
    echo "Found Envoy Service: $ENVOY_SVC_NAME. Patching..."
    kubectl patch svc "$ENVOY_SVC_NAME" -n envoy-gateway-system --type='merge' -p '{"spec": {"type": "NodePort", "ports": [{"name": "http", "port": 80, "targetPort": 10080, "nodePort": 30080}, {"name": "https", "port": 443, "targetPort": 10443, "nodePort": 30443}]}}'
    break
  fi
  
  if [ $i -eq 12 ]; then
    echo "WARNING: Envoy data-plane service not found yet."
    echo "This is expected if you haven't deployed the BankApp Gateway via ArgoCD yet."
    echo "AFTER you sync the application in ArgoCD, run this command to enable access:"
    echo "  kubectl patch svc \$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/own-gateway-name=bankapp-gateway -o jsonpath='{.items[0].metadata.name}') -n envoy-gateway-system --type='merge' -p '{\"spec\": {\"type\": \"NodePort\", \"ports\": [{\"name\": \"http\", \"port\": 80, \"targetPort\": 10080, \"nodePort\": 30080}, {\"name\": \"https\", \"port\": 443, \"targetPort\": 10443, \"nodePort\": 30443}]}}'"
    echo "--------------------------------------------------"
  else
    echo "Still waiting for service... ($((i*5))s)"
    sleep 5
  fi
done

# Detect Public IP for advice
PUBLIC_IP=$(curl -s ifconfig.me)

echo "Kind Setup Complete!"
echo "--------------------------------------------------"
echo "Recommended Domain (nip.io): $PUBLIC_IP.nip.io"
echo "Update your charts/bankapp/values.yaml with this domain."
echo "--------------------------------------------------"
echo "ArgoCD Login Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
echo "--------------------------------------------------"
