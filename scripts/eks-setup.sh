#!/bin/bash
# EKS Cluster Setup Script using eksctl
# Following Gateway API requirements

CLUSTER_NAME="bankapp-cluster"
REGION="us-east-1"
NODE_GROUP_NAME="bankapp-ng"

echo "Creating EKS Cluster: $CLUSTER_NAME..."
eksctl create cluster --name $CLUSTER_NAME --region $REGION --without-nodegroup

echo "Associating IAM OIDC Provider..."
eksctl utils associate-iam-oidc-provider --region=$REGION --cluster=$CLUSTER_NAME --approve

echo "Creating Node Group: $NODE_GROUP_NAME..."
eksctl create nodegroup \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --name=$NODE_GROUP_NAME \
  --node-type=t3.medium \
  --nodes=2 \
  --nodes-min=1 \
  --nodes-max=3 \
  --node-volume-size=20 \
  --managed

echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "Verifying nodes..."
kubectl get nodes

echo "EKS Setup Complete!"
