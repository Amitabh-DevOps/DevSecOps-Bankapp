#!/bin/bash
# EKS Cluster Setup Script using eksctl
# Following Gateway API requirements

CLUSTER_NAME="bankapp-prod-cluster"
REGION="us-east-1"
NODE_GROUP_NAME="bankapp-ng"

echo "Fetching Default VPC Subnets..."
PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(aws ec2 describe-vpcs --filter "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)" --query 'Subnets[?MapPublicIpOnLaunch==`true`].SubnetId' --output text | tr '\t' ',')

echo "Creating EKS Cluster: $CLUSTER_NAME in Default VPC (Subnets: $PUBLIC_SUBNETS)..."
eksctl create cluster --name $CLUSTER_NAME --region $REGION --version 1.35 --vpc-public-subnets=$PUBLIC_SUBNETS --without-nodegroup

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

echo "Installing EBS CSI Driver..."
# 1. Create IAM Service Account for the EBS CSI Driver
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster $CLUSTER_NAME \
  --region $REGION \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name "EKS_EBS_CSI_DriverRole_$CLUSTER_NAME"

# 2. Install the EBS CSI Addon
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster $CLUSTER_NAME \
  --region $REGION \
  --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/EKS_EBS_CSI_DriverRole_$CLUSTER_NAME \
  --force

echo "Verifying nodes..."
kubectl get nodes

echo "EKS Setup Complete!"
