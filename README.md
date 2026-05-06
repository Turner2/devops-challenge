# DevOps Challenge — Product Catalog Microservice

> Production-ready microservice deployed on AWS EKS using Terraform, Docker, Jenkins CI/CD, and CloudWatch monitoring.

![Infrastructure](https://img.shields.io/badge/IaC-Terraform-purple)
![Platform](https://img.shields.io/badge/Platform-AWS_EKS-orange)
![CI/CD](https://img.shields.io/badge/CI%2FCD-Jenkins-red)
![Container](https://img.shields.io/badge/Container-Docker-blue)
![Tests](https://img.shields.io/badge/Tests-5_Passing_|_90.9%25_Coverage-brightgreen)
![Live](https://img.shields.io/badge/Live-ngrok_tunnel-green)

---

## 🌐 Live Endpoints

> The service is deployed and accessible via a public ngrok tunnel (NodePort + port-forward workaround — see [Known Limitations](#known-limitations)).

| Endpoint | URL | Expected Response |
|---|---|---|
| **Health Check** | [`https://daybed-portfolio-dumping.ngrok-free.dev/health`](https://daybed-portfolio-dumping.ngrok-free.dev/health) | `200 { status: "healthy" }` |
| **Products API** | [`https://daybed-portfolio-dumping.ngrok-free.dev/api/v1/products`](https://daybed-portfolio-dumping.ngrok-free.dev/api/v1/products) | `200 { count, products[] }` |

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CI/CD FLOW                               │
│                                                                 │
│   Developer                                                     │
│      │                                                          │
│      ▼                                                          │
│   GitHub ──────► Jenkins Pipeline                               │
│                       │                                         │
│          ┌────────────┼────────────┐                            │
│          ▼            ▼            ▼                            │
│       Install       Test          Build                         │
│       (npm)        (Jest)        (Docker)                       │
│                                    │                            │
│                                    ▼                            │
│                              Push to ECR                        │
│                                    │                            │
│                                    ▼                            │
│                           kubectl set image                     │
│                                    │                            │
└────────────────────────────────────┼────────────────────────────┘
                                     │
┌────────────────────────────────────▼────────────────────────────┐
│                     AWS INFRASTRUCTURE                          │
│                                                                 │
│   ┌─────────── VPC 10.0.0.0/16 ───────────┐                     │
│   │                                        │                    │
│   │  us-east-1a          us-east-1b        │                    │
│   │  ┌────────────┐   ┌────────────┐       │                    │
│   │  │Public /24  │   │Public /24  │       │◄── Internet        │
│   │  │  NAT GW    │   │  NAT GW    │       │    Gateway         │
│   │  └────────────┘   └────────────┘       │                    │
│   │  ┌────────────┐   ┌────────────┐       │                    │
│   │  │Private /24 │   │Private /24 │       │                    │
│   │  │ EKS Node 1 │   │ EKS Node 2 │       │                    │
│   │  │ t3.medium  │   │ t3.medium  │       │                    │
│   │  └─────┬──────┘   └─────┬──────┘       │                    │
│   └────────┼────────────────┼──────────────┘                    │
│            └────────┬───────┘                                   │
│                     ▼                                           │
│          ┌─── production namespace ───┐                         │
│          │  ┌─────────┐ ┌─────────┐  │                          │
│          │  │  Pod 1  │ │  Pod 2  │  │◄── HPA (2-6 pods)        │
│          │  │  :3000  │ │  :3000  │  │    scales at 70% CPU     │
│          │  └─────────┘ └─────────┘  │                          │
│          │     NodePort :31500        │◄── port-forward :8080   │
│          └────────────────────────────┘         │               │
│                                                 ▼               │
│                                         ngrok tunnel            │
│                                    (public HTTPS URL)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## AWS Resources Provisioned

| Resource | Details |
|---|---|
| **VPC** | 10.0.0.0/16, DNS enabled |
| **Subnets** | 2 public + 2 private across us-east-1a and us-east-1b |
| **Internet Gateway** | Public internet access |
| **NAT Gateways** | 2x — one per AZ for private subnet egress |
| **EKS Cluster** | Kubernetes 1.31, API + audit + authenticator logs enabled |
| **Node Group** | 2x t3.medium (min: 1, max: 4) in private subnets |
| **ECR Repository** | Private, image scanning on push, lifecycle: keep last 10 |
| **IAM Roles** | Cluster role + node role with least-privilege policies |
| **CloudWatch** | FluentBit daemonset shipping container logs |

---

## Project Structure

```
devops-challenge/
├── app/
│   ├── src/
│   │   ├── index.js                 # Express server + health endpoint
│   │   ├── routes/products.js       # Route definitions
│   │   └── controllers/products.js  # Business logic
│   ├── tests/
│   │   └── products.test.js         # 5 Jest tests, 90.9% coverage
│   ├── Dockerfile                   # Multi-stage, linux/amd64, non-root
│   ├── .dockerignore
│   └── package.json
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/                     # VPC, subnets, IGW, NAT, route tables
│   │   ├── ecr/                     # ECR repo + lifecycle policy
│   │   └── eks/                     # EKS cluster, node group, IAM roles
│   └── environments/
│       └── prod/                    # Production entry point
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── k8s/
│   ├── namespace.yaml               # production namespace
│   ├── configmap.yaml               # environment variables
│   ├── deployment.yaml              # 2 replicas, rolling update strategy
│   ├── service.yaml                 # NodePort on port 31500
│   ├── hpa.yaml                     # Auto-scale 2–6 pods at 70% CPU
│   └── monitoring/
│       └── cloudwatch-configmap.yaml
│
├── Jenkinsfile                      # 7-stage pipeline with auto-rollback
└── README.md
```

---

## API Endpoints

| Method | Endpoint | Description | Response |
|---|---|---|---|
| `GET` | `/health` | Health check — used by EKS liveness + readiness probes | `200 { status: "healthy" }` |
| `GET` | `/api/v1/products` | List all products | `200 { count, products[] }` |
| `GET` | `/api/v1/products?category=electronics` | Filter by category | `200 { count, products[] }` |
| `GET` | `/api/v1/products/:id` | Get single product by ID | `200 product` or `404` |

---

## 🚀 Deployment Steps

### Prerequisites

```bash
aws --version        # AWS CLI configured with credentials
terraform --version  # >= 1.0
kubectl version      # any recent version
docker --version     # Docker Desktop running
```

### 1 — Provision Infrastructure

```bash
cd terraform/environments/prod
terraform init
terraform apply
```

> ⏱ Takes ~15 minutes. Creates VPC, EKS cluster, ECR repo, and all IAM roles.

### 2 — Connect kubectl to EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name devops-challenge-eks
kubectl get nodes   # should show 2x Ready
```

### 3 — Build and Push Docker Image

```bash
cd app
docker buildx build --platform linux/amd64 -t product-catalog:latest --load .

# Tag and push to ECR
ECR_URL=$(cd ../terraform/environments/prod && terraform output -raw ecr_repository_url)
docker tag product-catalog:latest $ECR_URL:latest
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL
docker push $ECR_URL:latest
```

### 4 — Deploy Application

```bash
cd ..
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
```

### 5 — Enable CloudWatch Monitoring

```bash
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

kubectl apply -f k8s/monitoring/cloudwatch-configmap.yaml

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
```

### 6 — Expose the Service Publicly (NodePort + ngrok)

> **Note:** The service runs as NodePort (port 31500) due to an AWS account-level ELB restriction on this account. The service is exposed publicly via `kubectl port-forward` + ngrok tunnel.

```bash
# Terminal 1 — port-forward to the service
kubectl port-forward svc/product-catalog-service 8080:80 -n production --pod-running-timeout=48h

# Terminal 2 — expose via ngrok
ngrok config add-authtoken <YOUR_TOKEN>
ngrok http 8080
```

The app will be live at your ngrok URL:
```
https://<your-ngrok-subdomain>.ngrok-free.dev/health
https://<your-ngrok-subdomain>.ngrok-free.dev/api/v1/products
```

### 7 — Verify Everything

```bash
kubectl get all -n production
kubectl get pods -n amazon-cloudwatch
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS
pod/product-catalog-xxx-xxx         1/1     Running   0
pod/product-catalog-xxx-xxx         1/1     Running   0

NAME                          TYPE        PORT(S)
product-catalog-service       NodePort    80:31500/TCP
```

### 8 — Teardown (after review)

```bash
cd terraform/environments/prod
terraform destroy
```

---

## 🔄 CI/CD Pipeline (Jenkins)

The `Jenkinsfile` defines a 7-stage pipeline:

```
Checkout → Install → Test → Build Image → Push to ECR → Deploy to EKS → Verify
```

| Stage | Action |
|---|---|
| **Checkout** | Pulls latest code from GitHub |
| **Install Dependencies** | Runs `npm install` |
| **Test** | Runs Jest with coverage — pipeline fails if tests fail |
| **Build Docker Image** | Multi-stage build targeting `linux/amd64` |
| **Push to ECR** | Authenticates via AWS CLI, pushes with build number tag |
| **Deploy to EKS** | `kubectl set image` + waits for rollout to complete |
| **Verify** | Confirms pod and service status post-deploy |

**Auto-rollback:** The `post { failure }` block runs `kubectl rollout undo` if any stage fails — the previous working version is automatically restored.

---

## 🏗️ Design Decisions

### Why EKS over ECS or EC2?
EKS provides native Kubernetes, meaning the solution is portable across cloud providers (GKE, AKS) without rearchitecting. It also unlocks production features like HPA, rolling deployments with zero downtime, namespace isolation, and fine-grained RBAC — all of which would require significant custom work on EC2.

### Why a multi-stage Dockerfile?
The three-stage build (deps → test → production) enforces a hard rule: **broken code cannot produce a deployable image**. If tests fail in stage 2, the build stops and nothing is pushed to ECR. The final image is ~45MB and runs as a non-root user (`appuser`) — two security best practices for production containers.

### Why modular Terraform?
Each module (`vpc`, `ecr`, `eks`) is independently reusable. Adding a staging environment requires only a new `environments/staging/` directory that calls the same modules with different variable values — no code duplication. This follows the DRY principle and mirrors how production Terraform is structured in real teams.

### Why FluentBit over the CloudWatch Agent?
FluentBit consumes significantly less CPU and memory per node than the full CloudWatch Agent. It is the AWS-recommended solution for EKS log forwarding and ships as a DaemonSet, ensuring every node's container logs are captured regardless of pod scheduling.

### Why Node.js + Express?
Lightweight, fast to set up, and immediately testable with Jest and Supertest. The goal of this challenge is to demonstrate DevOps capability, not application complexity — a simple, well-tested service communicates that more clearly than a complex one.

---

## ⚠️ Assumptions

- AWS account has sufficient service limits for EKS, NAT Gateways (2), and EIPs (2)
- Jenkins server has AWS CLI, Docker (with buildx), and kubectl installed and configured
- Jenkins execution role has IAM permissions for: `ecr:*`, `eks:DescribeCluster`, and `sts:GetCallerIdentity`
- `terraform apply` is run by a user with sufficient IAM permissions (AdministratorAccess or equivalent)

---

## 🔧 Known Limitations & Planned Improvements

| Limitation | Root Cause | Current Workaround | Planned Fix |
|---|---|---|---|
| **LoadBalancer pending** | AWS account-level ELB restriction (`OperationNotPermitted`) | Service runs as **NodePort :31500**, exposed via `kubectl port-forward` + ngrok | Install AWS Load Balancer Controller via Helm or contact AWS Support to lift restriction |
| No Terraform remote state | Local state only | — | Add S3 backend + DynamoDB locking in `backend.tf` |
| Jenkins runs locally | No dedicated CI server | — | Deploy Jenkins on EC2 or as an EKS pod |
| No TLS/HTTPS on cluster | No certificate configured | ngrok provides HTTPS termination | Add ACM certificate + Route53 + ingress controller |
| In-memory data store | Stateless by design | — | Replace with RDS (PostgreSQL) or DynamoDB |
| No image vulnerability gate | ECR scanning enabled but not blocking | — | Add pipeline step: fail build if CRITICAL CVEs found |
| Single region | No disaster recovery plan | — | Add multi-region ECR replication + Route53 failover |

---

## 📊 Monitoring & Logging

CloudWatch Container Insights is enabled via FluentBit DaemonSet running on all nodes.

**What is collected:**
- All container stdout/stderr logs from every namespace
- Node-level CPU and memory utilisation
- Pod restart counts and failure events

**Where to view logs:**
```
AWS Console → CloudWatch → Log Groups
→ /aws/containerinsights/devops-challenge-eks/application
→ /aws/containerinsights/devops-challenge-eks/host
```

---

## 📋 Test Coverage

```
File                  | % Stmts | % Branch | % Funcs | % Lines
----------------------|---------|----------|---------|--------
src/index.js          |   78.57 |    83.33 |   33.33 |   78.57
src/controllers/      |     100 |      100 |     100 |     100
src/routes/           |     100 |      100 |     100 |     100
----------------------|---------|----------|---------|--------
All files             |    90.9 |       90 |   71.42 |   90.62
```

5 tests — Health check, list all products, category filter, get by ID, 404 handling.
````