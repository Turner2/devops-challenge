# DevOps Challenge — Product Catalog Microservice

A production-ready microservice deployed on AWS EKS using Terraform, Docker, Jenkins, and CloudWatch.

---

## Architecture Overview

Developer Push → GitHub → Jenkins Pipeline
│
┌──────────┼──────────┐
│ │ │
Build Test Push
(Docker) (Jest) (ECR)
│
kubectl apply
│
EKS Cluster (us-east-1)
┌─────────────────────┐
│ production namespace│
│ ┌───────┐ ┌───────┐│
│ │ Pod 1 │ │ Pod 2 ││
│ └───────┘ └───────┘│
│ LoadBalancer Service│
└─────────────────────┘
│
CloudWatch
(Logs + Metrics)

### AWS Resources

- **VPC** — 10.0.0.0/16 with 2 public + 2 private subnets across 2 AZs
- **EKS** — Kubernetes 1.31, 2x t3.medium worker nodes
- **ECR** — Private container registry with image scanning enabled
- **NAT Gateways** — 2x for private subnet internet access
- **CloudWatch** — FluentBit daemonset for container log aggregation

---

## Application

A Node.js REST API (Product Catalog microservice) built with Express.

### Endpoints

| Method | Path                                  | Description                                          |
| ------ | ------------------------------------- | ---------------------------------------------------- |
| GET    | /health                               | Health check (used by EKS liveness/readiness probes) |
| GET    | /api/v1/products                      | List all products                                    |
| GET    | /api/v1/products?category=electronics | Filter by category                                   |
| GET    | /api/v1/products/:id                  | Get product by ID                                    |

---

## Project Structure

devops-challenge/
├── app/ # Node.js microservice
│ ├── src/
│ │ ├── index.js # Express server
│ │ ├── routes/products.js # API routes
│ │ └── controllers/products.js
│ ├── tests/products.test.js # Jest tests (5 tests, 90%+ coverage)
│ ├── Dockerfile # Multi-stage, linux/amd64
│ └── package.json
├── terraform/
│ ├── modules/
│ │ ├── vpc/ # VPC, subnets, NAT, IGW
│ │ ├── ecr/ # ECR repository + lifecycle policy
│ │ └── eks/ # EKS cluster + node group + IAM
│ └── environments/prod/ # Production entry point
├── k8s/
│ ├── namespace.yaml
│ ├── configmap.yaml
│ ├── deployment.yaml # 2 replicas, rolling update
│ ├── service.yaml # LoadBalancer
│ ├── hpa.yaml # Auto-scales 2-6 pods at 70% CPU
│ └── monitoring/
│ └── cloudwatch-configmap.yaml
├── Jenkinsfile # 7-stage CI/CD pipeline
└── README.md

---

## Deployment Steps

### Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- kubectl
- Docker Desktop

### 1. Provision Infrastructure

```bash
cd terraform/environments/prod
terraform init
terraform apply
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name devops-challenge-eks
```

### 3. Build and Push Docker Image

```bash
cd app
docker buildx build --platform linux/amd64 -t product-catalog:latest --load .
docker tag product-catalog:latest <ECR_URL>:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_URL>
docker push <ECR_URL>:latest
```

### 4. Deploy to EKS

```bash
kubectl apply -f k8s/
kubectl apply -f k8s/monitoring/
```

### 5. Verify

```bash
kubectl get all -n production
kubectl get pods -n amazon-cloudwatch
```

---

## CI/CD Pipeline (Jenkins)

The Jenkinsfile defines 7 stages:

| Stage                | What it does                          |
| -------------------- | ------------------------------------- |
| Checkout             | Pulls source code from GitHub         |
| Install Dependencies | Runs npm install                      |
| Test                 | Runs Jest tests with coverage         |
| Build Docker Image   | Multi-stage build for linux/amd64     |
| Push to ECR          | Authenticates and pushes image        |
| Deploy to EKS        | Updates deployment, waits for rollout |
| Verify               | Confirms pods and service status      |

**Rollback:** If any stage fails, the `post { failure }` block automatically runs `kubectl rollout undo`.

---

## Design Decisions

### Why EKS over ECS or EC2?

EKS provides full Kubernetes compatibility, making the solution portable across cloud providers. It also enables advanced features like HPA, rolling deployments, and namespace isolation that align with production best practices.

### Why multi-stage Dockerfile?

Three stages (deps → test → production) ensure:

- Tests run inside the build process — broken code cannot be pushed
- Production image contains only runtime dependencies (~45MB)
- Non-root user (`appuser`) reduces security attack surface

### Why modular Terraform?

Each module (vpc, ecr, eks) is independently reusable. The `environments/prod` directory acts as the entry point, making it trivial to add `environments/staging` later by reusing the same modules with different variables.

### Why FluentBit over CloudWatch Agent?

FluentBit is lighter (uses less CPU/memory per node) and is the AWS-recommended solution for EKS log forwarding to CloudWatch.

---

## Assumptions

- AWS account has sufficient limits for EKS, NAT Gateways, and EIPs
- Jenkins server has AWS CLI, Docker, and kubectl installed
- Jenkins IAM role has permissions for ECR push and EKS deploy

---

## Known Limitations & Improvements

| Limitation                                   | Improvement                                     |
| -------------------------------------------- | ----------------------------------------------- |
| LoadBalancer pending (missing LB controller) | Install AWS Load Balancer Controller via Helm   |
| No Terraform remote state                    | Add S3 backend + DynamoDB state locking         |
| Jenkins runs locally                         | Deploy Jenkins on EC2 or use EKS-hosted Jenkins |
| No HTTPS                                     | Add ACM certificate + Route53                   |
| In-memory data store                         | Replace with RDS or DynamoDB                    |
| No image vulnerability gate                  | Add ECR scan results check in pipeline          |

---

## Monitoring

CloudWatch Container Insights collects:

- Container logs from all pods in all namespaces
- Node-level CPU and memory metrics
- Pod restart and failure events

View logs: **AWS Console → CloudWatch → Log Groups → `/aws/containerinsights/devops-challenge-eks/application`**
