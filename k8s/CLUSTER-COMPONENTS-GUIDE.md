# EKS Cluster Components Installation Guide

This guide covers installing essential Kubernetes components on your EKS cluster.

## Environment Reference

| Environment | Account ID | Cluster Name | AWS Profile |
|-------------|------------|--------------|-------------|
| dev | 891377046654 | d1-dev-cluster | dev |
| uat | 767397680435 | d1-uat-cluster | uat |
| prod | 654654495154 | d1-prod-cluster | prod |

---

## Prerequisites

### 1. Install Helm

```bash
# Windows (Chocolatey)
choco install kubernetes-helm

# macOS
brew install helm

# Verify
helm version
```

### 2. Connect to Cluster

```bash
# Replace <env> with: dev, uat, or prod
aws eks update-kubeconfig --name d1-<env>-cluster --region us-east-1 --profile <env>

# Verify connection
kubectl get nodes
kubectl cluster-info
```

### 3. Add Helm Repositories

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo add jetstack https://charts.jetstack.io
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
```

---

## Component 1: AWS Load Balancer Controller

Creates ALB/NLB for Ingress and LoadBalancer Services.

### Pre-flight Checklist

- [ ] EKS cluster is running
- [ ] OIDC provider is configured (done via Terraform)
- [ ] IAM role `MyAmazonEKSLoadBalancerControllerRole` exists
- [ ] You have your VPC ID

### Step 1: Get Required Values

```bash
# Set your environment
ENV=dev
ACCOUNT_ID=891377046654  # Change per environment
CLUSTER_NAME=d1-${ENV}-cluster

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=d1-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --profile ${ENV})

echo "VPC ID: $VPC_ID"
```

### Step 2: Install Controller

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=true \ 
  --set serviceAccount.name=aws-load-balancer-controller-sa \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/MyAmazonEKSLoadBalancerControllerRole" \
  --set region=us-east-1 \
  --set vpcId=${VPC_ID}


helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller-sa \
  --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/MyAmazonEKSLoadBalancerControllerRole \
  --set region=us-east-1 \
  --set vpcId=${VPC_ID}
```

### Step 3: Verify Installation

```bash
# Check deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check pods (should be 2/2 Running)
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20
```

### Step 4: Create IngressClass

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb
EOF
```

### Verification Test

```bash
# Deploy test app
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb
---
apiVersion: v1
kind: Namespace
metadata:
  name: lb-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: lb-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  namespace: lb-test
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: lb-test
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-svc
            port:
              number: 80
EOF

# Wait 2-3 minutes, then get ALB URL
kubectl get ingress -n lb-test

# Cleanup test
kubectl delete namespace lb-test
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Pods in CrashLoopBackOff | Check logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller` |
| "failed to get VPC ID" | Add `--set vpcId=<vpc-id>` to helm install |
| ServiceAccount not found | Set `--set serviceAccount.create=true` |
| IRSA not working | Verify IAM role trust policy has correct OIDC provider |

### Upgrade Command

```bash
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller-sa \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/MyAmazonEKSLoadBalancerControllerRole" \
  --set region=us-east-1 \
  --set vpcId=${VPC_ID}
```

### Uninstall Command

```bash
helm uninstall aws-load-balancer-controller -n kube-system
```

---

## Component 2: Cluster Autoscaler

Automatically scales node groups based on pod resource requests.

### Pre-flight Checklist

- [ ] EKS cluster is running
- [ ] Node groups have proper ASG tags (handled by Terraform)
- [ ] IAM role for Cluster Autoscaler exists (create below if not)

### Step 1: Create IAM Role (if not exists in Terraform)

**IAM Policy** - Save as `cluster-autoscaler-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "ec2:DescribeImages",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": ["*"],
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled": "true",
          "aws:ResourceTag/k8s.io/cluster-autoscaler/${CLUSTER_NAME}": "owned"
        }
      }
    }
  ]
}
```

**Create via AWS CLI:**

```bash
# Create policy
aws iam create-policy \
  --policy-name ${CLUSTER_NAME}-cluster-autoscaler-policy \
  --policy-document file://cluster-autoscaler-policy.json \
  --profile ${ENV}

# Get OIDC provider URL
OIDC_URL=$(aws eks describe-cluster \
  --name ${CLUSTER_NAME} \
  --query "cluster.identity.oidc.issuer" \
  --output text \
  --profile ${ENV})

OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)

# Create trust policy
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:cluster-autoscaler-sa"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name ${CLUSTER_NAME}-cluster-autoscaler-role \
  --assume-role-policy-document file://trust-policy.json \
  --profile ${ENV}

# Attach policy
aws iam attach-role-policy \
  --role-name ${CLUSTER_NAME}-cluster-autoscaler-role \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${CLUSTER_NAME}-cluster-autoscaler-policy \
  --profile ${ENV}
```

### Step 2: Install Cluster Autoscaler

```bash
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  -n kube-system \
  --set autoDiscovery.clusterName=${CLUSTER_NAME} \
  --set awsRegion=us-east-1 \
  --set rbac.serviceAccount.create=true \
  --set rbac.serviceAccount.name=cluster-autoscaler-sa \
  --set "rbac.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${CLUSTER_NAME}-cluster-autoscaler-role"
```

### Step 3: Verify Installation

```bash
# Check deployment
kubectl get deployment -n kube-system cluster-autoscaler

# Check pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler --tail=30
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Failed to get ASG" | Verify ASG has tags: `k8s.io/cluster-autoscaler/enabled=true` |
| IRSA not working | Check service account annotation matches IAM role |
| Not scaling | Check logs for "scale up" or "scale down" events |

### Uninstall Command

```bash
helm uninstall cluster-autoscaler -n kube-system
```

---

## Component 3: Metrics Server

Enables `kubectl top` and Horizontal Pod Autoscaler (HPA).

### Pre-flight Checklist

- [ ] EKS cluster is running
- [ ] No existing metrics-server installation

### Step 1: Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Step 2: Verify Installation

```bash
# Check deployment
kubectl get deployment -n kube-system metrics-server

# Check pods
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Test (wait 1-2 minutes after install)
kubectl top nodes
kubectl top pods -A
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Metrics not available yet" | Wait 2-3 minutes for metrics to populate |
| "unable to fetch metrics" | Check metrics-server logs: `kubectl logs -n kube-system -l k8s-app=metrics-server` |

### Uninstall Command

```bash
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## Component 4: gp3 StorageClass

Faster and cheaper than default gp2 storage.

### Pre-flight Checklist

- [ ] EBS CSI Driver addon is installed (via Terraform)
- [ ] EBS CSI Driver IRSA is configured

### Step 1: Create gp3 StorageClass

```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

### Step 2: Remove Default from gp2 (Optional)

```bash
# Remove default annotation from gp2
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

### Step 3: Verify

```bash
# List storage classes
kubectl get storageclass

# Test PVC creation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gp3-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 1Gi
EOF

# Check PVC (will be Pending until a pod uses it)
kubectl get pvc gp3-test-pvc

# Cleanup
kubectl delete pvc gp3-test-pvc
```

### gp3 vs gp2 Comparison

| Feature | gp2 | gp3 |
|---------|-----|-----|
| Baseline IOPS | 100-16,000 (size dependent) | 3,000 (configurable) |
| Throughput | 128-250 MB/s | 125-1,000 MB/s |
| Cost | ~$0.10/GB/month | ~$0.08/GB/month |
| Recommendation | Legacy | **Use this** |

---

## Component 5: External DNS

Automatically creates Route53 DNS records for Ingress/Services.

### Pre-flight Checklist

- [ ] Route53 hosted zone exists
- [ ] IAM role for External DNS exists

### Step 1: Create IAM Role

```bash
# Create policy
cat <<EOF > external-dns-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["route53:ChangeResourceRecordSets"],
      "Resource": ["arn:aws:route53:::hostedzone/*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource"
      ],
      "Resource": ["*"]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ${CLUSTER_NAME}-external-dns-policy \
  --policy-document file://external-dns-policy.json \
  --profile ${ENV}

# Get OIDC ID
OIDC_URL=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text --profile ${ENV})
OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)

# Create trust policy
cat <<EOF > external-dns-trust.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:external-dns-sa"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name ${CLUSTER_NAME}-external-dns-role \
  --assume-role-policy-document file://external-dns-trust.json \
  --profile ${ENV}

aws iam attach-role-policy \
  --role-name ${CLUSTER_NAME}-external-dns-role \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${CLUSTER_NAME}-external-dns-policy \
  --profile ${ENV}
```

### Step 2: Install External DNS

```bash
# Replace YOUR_DOMAIN with your Route53 hosted zone domain
DOMAIN_FILTER=example.com

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

helm install external-dns external-dns/external-dns \
  -n kube-system \
  --set provider=aws \
  --set aws.region=us-east-1 \
  --set domainFilters[0]=${DOMAIN_FILTER} \
  --set policy=sync \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns-sa \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${CLUSTER_NAME}-external-dns-role"
```

### Step 3: Verify Installation

```bash
# Check deployment
kubectl get deployment -n kube-system external-dns

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=20
```

### Usage Example

Add annotation to Ingress:
```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myapp.example.com
```

### Uninstall Command

```bash
helm uninstall external-dns -n kube-system
```

---

## Component 6: cert-manager

Automated TLS certificate management with Let's Encrypt.

### Pre-flight Checklist

- [ ] External DNS is configured (for DNS-01 challenge)
- [ ] Or ALB Controller is configured (for HTTP-01 challenge)

### Step 1: Install cert-manager

```bash
helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set webhook.timeoutSeconds=30
```

### Step 2: Verify Installation

```bash
# Check pods (3 pods should be running)
kubectl get pods -n cert-manager

# Verify CRDs installed
kubectl get crds | grep cert-manager
```

### Step 3: Create ClusterIssuer (Let's Encrypt)

**Staging (for testing):**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
    - http01:
        ingress:
          class: alb
EOF
```

**Production:**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: alb
EOF
```

### Step 4: Verify ClusterIssuer

```bash
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-staging
```

### Usage Example

Add annotations to Ingress:
```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Certificate stuck "Pending" | Check: `kubectl describe certificate <name>` |
| Challenge failed | Check: `kubectl describe challenge -A` |
| Webhook timeout | Increase timeout or check webhook logs |

### Uninstall Command

```bash
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
```

---

## Component 7: Fluent Bit (CloudWatch Logs)

Ships container logs to CloudWatch Logs.

### Pre-flight Checklist

- [ ] CloudWatch log group exists (or will be auto-created)
- [ ] IAM role for Fluent Bit exists

### Step 1: Create IAM Role

```bash
# Create policy
cat <<EOF > fluent-bit-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ${CLUSTER_NAME}-fluent-bit-policy \
  --policy-document file://fluent-bit-policy.json \
  --profile ${ENV}

# Get OIDC ID
OIDC_URL=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text --profile ${ENV})
OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)

# Create trust policy
cat <<EOF > fluent-bit-trust.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:amazon-cloudwatch:fluent-bit-sa"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name ${CLUSTER_NAME}-fluent-bit-role \
  --assume-role-policy-document file://fluent-bit-trust.json \
  --profile ${ENV}

aws iam attach-role-policy \
  --role-name ${CLUSTER_NAME}-fluent-bit-role \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${CLUSTER_NAME}-fluent-bit-policy \
  --profile ${ENV}
```

### Step 2: Install Fluent Bit

```bash
# Create namespace
kubectl create namespace amazon-cloudwatch

# Create service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit-sa
  namespace: amazon-cloudwatch
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/${CLUSTER_NAME}-fluent-bit-role
EOF

# Install Fluent Bit
helm install fluent-bit fluent/fluent-bit \
  -n amazon-cloudwatch \
  --set serviceAccount.create=false \
  --set serviceAccount.name=fluent-bit-sa \
  --set cloudWatch.enabled=true \
  --set cloudWatch.region=us-east-1 \
  --set cloudWatch.logGroupName="/aws/eks/${CLUSTER_NAME}/containers" \
  --set cloudWatch.autoCreateGroup=true
```

### Step 3: Verify Installation

```bash
# Check DaemonSet (should have 1 pod per node)
kubectl get daemonset -n amazon-cloudwatch

# Check pods
kubectl get pods -n amazon-cloudwatch

# Check logs
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=fluent-bit --tail=20
```

### Step 4: Verify in CloudWatch

1. Go to AWS Console → CloudWatch → Log Groups
2. Look for `/aws/eks/${CLUSTER_NAME}/containers`
3. You should see log streams for your pods

### Uninstall Command

```bash
helm uninstall fluent-bit -n amazon-cloudwatch
kubectl delete namespace amazon-cloudwatch
```

---

## Quick Reference: All Components

### Install Order (Recommended)

1. **Metrics Server** - No dependencies
2. **gp3 StorageClass** - No dependencies
3. **AWS Load Balancer Controller** - Needs IRSA
4. **Cluster Autoscaler** - Needs IRSA
5. **Fluent Bit** - Needs IRSA
6. **External DNS** - Needs IRSA + Route53 zone
7. **cert-manager** - Needs LB Controller or External DNS

### Status Check Commands

```bash
# All kube-system deployments
kubectl get deployments -n kube-system

# All pods across monitoring namespaces
kubectl get pods -n kube-system
kubectl get pods -n amazon-cloudwatch
kubectl get pods -n cert-manager

# Storage classes
kubectl get storageclass

# Ingress classes
kubectl get ingressclass
```

### Environment Variables Template

```bash
# Copy and modify for your environment
export ENV=dev
export ACCOUNT_ID=891377046654
export CLUSTER_NAME=d1-${ENV}-cluster
export AWS_PROFILE=${ENV}
export AWS_REGION=us-east-1

# Get VPC ID
export VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=d1-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --profile ${ENV})

# Get OIDC ID
export OIDC_URL=$(aws eks describe-cluster \
  --name ${CLUSTER_NAME} \
  --query "cluster.identity.oidc.issuer" \
  --output text \
  --profile ${ENV})
export OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)

echo "Environment: $ENV"
echo "Account: $ACCOUNT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "VPC: $VPC_ID"
echo "OIDC ID: $OIDC_ID"
```

---

## Cleanup All Components

```bash
# Reverse order of installation
helm uninstall cert-manager -n cert-manager 2>/dev/null
helm uninstall external-dns -n kube-system 2>/dev/null
helm uninstall fluent-bit -n amazon-cloudwatch 2>/dev/null
helm uninstall cluster-autoscaler -n kube-system 2>/dev/null
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null
kubectl delete storageclass gp3 2>/dev/null
kubectl delete namespace cert-manager amazon-cloudwatch 2>/dev/null
kubectl delete ingressclass alb 2>/dev/null
```
