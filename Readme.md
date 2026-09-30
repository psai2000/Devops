# DevOps Assignment

Production-grade Kubernetes platform on AWS EKS with a Python (Flask) microservice, Helm-based deployment, Prometheus/Grafana observability, and GitHub Actions CI/CD.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [End-to-End Setup Guide](#end-to-end-setup-guide)
  - [1. Provision EKS Cluster](#1-provision-eks-cluster)
  - [2. Build and Push the Docker Image](#2-build-and-push-the-docker-image)
  - [3. Deploy the Microservice](#3-deploy-the-microservice)
  - [4. Install Monitoring Stack](#4-install-monitoring-stack)
  - [5. Set Up CI/CD](#5-set-up-cicd)
- [Verifying the Deployment](#verifying-the-deployment)
- [Design Decisions and Trade-offs](#design-decisions-and-trade-offs)
- [Known Limitations](#known-limitations)
- [Cleanup](#cleanup)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Cloud (ap-south-1)                   │
│                                                                 │
│  ┌───────────────────── VPC 10.0.0.0/16 ─────────────────────┐ │
│  │                                                            │ │
│  │  ┌─────────────────┐        ┌─────────────────┐           │ │
│  │  │  Public Subnet   │        │  Public Subnet   │          │ │
│  │  │  10.0.101.0/24   │        │  10.0.102.0/24   │          │ │
│  │  │  (AZ-a)          │        │  (AZ-b)          │          │ │
│  │  │  ┌─────────┐     │        │                  │          │ │
│  │  │  │ NAT GW  │     │        │  [LoadBalancers]  │          │ │
│  │  │  └─────────┘     │        │                  │          │ │
│  │  └─────────────────┘        └─────────────────┘           │ │
│  │                                                            │ │
│  │  ┌─────────────────┐        ┌─────────────────┐           │ │
│  │  │ Private Subnet   │        │ Private Subnet   │          │ │
│  │  │ 10.0.1.0/24      │        │ 10.0.2.0/24      │          │ │
│  │  │ (AZ-a)           │        │ (AZ-b)           │          │ │
│  │  │                  │        │                  │          │ │
│  │  │  ┌────────────┐  │        │  ┌────────────┐  │          │ │
│  │  │  │ EKS Node   │  │        │  │ EKS Node   │  │          │ │
│  │  │  │ ┌────────┐ │  │        │  │ ┌────────┐ │  │          │ │
│  │  │  │ │Hello   │ │  │        │  │ │Hello   │ │  │          │ │
│  │  │  │ │World   │ │  │        │  │ │World   │ │  │          │ │
│  │  │  │ │Pod     │ │  │        │  │ │Pod     │ │  │          │ │
│  │  │  │ └────────┘ │  │        │  │ └────────┘ │  │          │ │
│  │  │  │ ┌────────┐ │  │        │  │ ┌────────┐ │  │          │ │
│  │  │  │ │Prom +  │ │  │        │  │ │Grafana │ │  │          │ │
│  │  │  │ │Alert   │ │  │        │  │ │        │ │  │          │ │
│  │  │  │ │Manager │ │  │        │  │ │        │ │  │          │ │
│  │  │  │ └────────┘ │  │        │  │ └────────┘ │  │          │ │
│  │  │  └────────────┘  │        │  └────────────┘  │          │ │
│  │  └─────────────────┘        └─────────────────┘           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────┐  ┌────────────┐  ┌──────────────────────┐    │
│  │ EKS Control  │  │    ECR     │  │ CloudWatch Logs      │    │
│  │ Plane        │  │ Registry   │  │ (control plane logs) │    │
│  └──────────────┘  └────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

        GitHub Actions CI/CD
        ┌─────────┐  ┌──────────┐  ┌────────┐  ┌──────────┐
        │  Test   │→ │Build+Push│→ │ Deploy │→ │  Smoke   │
        │(Python) │  │  (ECR)   │  │ (Helm) │  │  Test    │
        └─────────┘  └──────────┘  └────────┘  └──────────┘
```

**Key components:**

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Infrastructure | Terraform | VPC, EKS cluster, IAM, security groups, EBS CSI |
| Microservice | Python 3.12 (Flask) | HTTP server returning `{"message":"Hello World"}` |
| Containerisation | Docker (slim) | Multi-stage build with gunicorn, non-root user |
| Deployment | Helm v3 | Templated Kubernetes manifests with HPA, PDB |
| Monitoring | Prometheus + Grafana | Metrics collection, dashboards, alerting |
| CI/CD | GitHub Actions | Test → Build → Push → Deploy → Smoke test |

---

## Repository Structure

```
.
├── .github/workflows/
│   ├── ci-cd.yaml              # App CI/CD: test, build, push, deploy, smoke test
│   └── terraform.yaml          # Infra CI/CD: plan on PR, apply on merge
├── app/
│   ├── app.py                  # Flask HTTP server with Prometheus instrumentation
│   ├── test_app.py             # Unit tests (pytest)
│   ├── requirements.txt        # Python dependencies
│   ├── Dockerfile              # Multi-stage build with gunicorn
│   └── .dockerignore
├── helm/hello-world/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl        # Template helpers
│       ├── deployment.yaml     # Deployment with rolling updates
│       ├── service.yaml        # LoadBalancer service
│       ├── serviceaccount.yaml
│       ├── hpa.yaml            # Horizontal Pod Autoscaler (2-10 pods)
│       ├── pdb.yaml            # Pod Disruption Budget
│       ├── ingress.yaml        # Optional ALB Ingress
│       ├── servicemonitor.yaml # Prometheus ServiceMonitor
│       └── NOTES.txt
├── monitoring/
│   ├── values-prometheus-stack.yaml   # kube-prometheus-stack configuration
│   ├── storageclass.yaml              # gp3 EBS StorageClass
│   ├── hello-world-dashboard-configmap.yaml  # Custom Grafana dashboard
│   ├── alerts.yaml                    # PrometheusRule alert definitions
│   └── install.sh                     # One-command monitoring install
├── terraform/
│   ├── provider.tf             # AWS provider with default tags
│   ├── versions.tf             # Terraform and provider version constraints
│   ├── variables.tf            # All configurable inputs
│   ├── terraform.tfvars        # Default values for dev environment
│   ├── locals.tf               # Computed local values
│   ├── vpc.tf                  # VPC, subnets, NAT, route tables
│   ├── iam.tf                  # Cluster, node, OIDC, EBS CSI IAM roles
│   ├── security-groups.tf      # Cluster and node security groups
│   ├── eks.tf                  # EKS cluster, node group, add-ons
│   ├── data.tf                 # Data sources
│   ├── outputs.tf              # Useful outputs (endpoint, kubeconfig cmd)
│   └── .gitignore
└── README.md
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [AWS CLI](https://aws.amazon.com/cli/) | v2+ | AWS authentication |
| [Terraform](https://www.terraform.io/) | ≥ 1.5 | Infrastructure provisioning |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | v1.29+ | Kubernetes management |
| [Helm](https://helm.sh/) | v3.15+ | Chart deployment |
| [Docker](https://www.docker.com/) | v24+ | Image building |
| [Python](https://python.org/) | 3.12+ | Local development (optional) |

Ensure your AWS CLI is configured with credentials that have permissions to create VPCs, EKS clusters, IAM roles, and ECR repositories.

```bash
aws configure
aws sts get-caller-identity  # verify
```

---

## End-to-End Setup Guide

### 1. Provision EKS Cluster

```bash
cd terraform

# Initialise Terraform
terraform init

# Review the plan
terraform plan

# Apply (creates VPC, EKS cluster, node group — ~15 minutes)
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name lucidity-dev-eks

# Verify
kubectl get nodes
```

> **Note:** The Terraform output includes the exact `aws eks update-kubeconfig` command.

### 2. Build and Push the Docker Image

```bash
# Create ECR repository (one-time)
aws ecr create-repository \
  --repository-name lucidity/hello-world \
  --region ap-south-1

# Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com

# Build
cd app
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  -t <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/lucidity/hello-world:1.0.0 .

# Push
docker push <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/lucidity/hello-world:1.0.0
```

### 3. Deploy the Microservice

```bash
helm upgrade --install hello-world ./helm/hello-world \
  --set image.repository=<ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/lucidity/hello-world \
  --set image.tag=1.0.0 \
  --wait

# Check deployment
kubectl get pods -l app.kubernetes.io/name=hello-world
kubectl get svc hello-world

# Test
curl http://<EXTERNAL-IP>/hello
# Expected: {"message":"Hello World"}
```

### 4. Install Monitoring Stack

```bash
cd monitoring

# Run the install script (installs Prometheus, Grafana, dashboards, alerts)
chmod +x install.sh
./install.sh

# Access Grafana
kubectl get svc -n monitoring monitoring-grafana
# Open the EXTERNAL-IP in your browser
# Login: admin / lucidity-admin

# Access Prometheus (port-forward)
kubectl port-forward -n monitoring svc/monitoring-prometheus 9090:9090
# Open http://localhost:9090
```

The custom "Hello World Service" dashboard is auto-provisioned in Grafana under the "Custom" folder.

### 5. Set Up CI/CD

1. **Create an IAM OIDC identity provider** for GitHub Actions in your AWS account ([GitHub docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services))

2. **Create an IAM role** with permissions for ECR, EKS, and Terraform, and configure it to trust the GitHub OIDC provider

3. **Add the repository secret:**
   - `AWS_ROLE_ARN` — ARN of the IAM role created above

4. **Trigger the pipeline** by pushing to `main`:
   ```bash
   git push origin main
   ```

The CI/CD pipeline will:
- **On PR:** Run tests + Terraform plan
- **On merge to main:** Test → Build → Push to ECR → Deploy via Helm → Smoke test

---

## Verifying the Deployment

```bash
# 1. Check all pods are running
kubectl get pods -A

# 2. Test the Hello World endpoint
curl http://<SERVICE-EXTERNAL-IP>/hello
# {"message":"Hello World"}

# 3. Test health endpoints
curl http://<SERVICE-EXTERNAL-IP>/healthz
# {"status":"alive"}

curl http://<SERVICE-EXTERNAL-IP>/readyz
# {"status":"ready"}

# 4. Check Prometheus metrics
curl http://<SERVICE-EXTERNAL-IP>/metrics

# 5. Verify HPA is active
kubectl get hpa hello-world

# 6. Open Grafana and check the "Hello World Service" dashboard
```

---

## Design Decisions and Trade-offs

### Infrastructure

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **Single NAT Gateway** | Reduces cost in dev (~$32/month saved vs per-AZ NAT) | Single point of failure for outbound traffic; use one NAT per AZ in production |
| **Private subnets for nodes** | Worker nodes are not directly exposed to the internet | Requires NAT gateway for outbound access (ECR pulls, etc.) |
| **EKS managed node group** | AWS handles AMI updates, drains, and replacements | Less flexibility than self-managed or Karpenter; suitable for predictable workloads |
| **EBS CSI driver via IRSA** | Least-privilege IAM via service account instead of node-level permissions | Requires OIDC provider setup |
| **Control-plane logging enabled** | Full audit trail for API, authenticator, scheduler | Incurs CloudWatch costs; disable specific log types if not needed |

### Application

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **Python (Flask)** | Widely known, fast development, rich ecosystem | Higher memory footprint than Go; mitigated by gunicorn worker model |
| **Gunicorn (4 workers)** | Production-grade WSGI server with pre-fork worker model, handles concurrent requests | More memory per pod than a single-threaded server; tune worker count per resources |
| **Slim image (non-root)** | Smaller than full Python image, runs as non-root user | Slightly larger than distroless (~120 MB vs ~2 MB); acceptable for Python ecosystem |
| **Built-in Prometheus metrics** | Native instrumentation via `prometheus_client` avoids sidecar overhead | Couples metrics library to the app; acceptable for this scope |
| **Graceful shutdown** | Gunicorn's `--graceful-timeout` ensures in-flight requests complete before pod termination | 30s timeout must be shorter than `terminationGracePeriodSeconds` |

### Deployment

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **HPA (2-10 replicas)** | Auto-scales on CPU/memory to handle traffic spikes | Requires metrics-server (included with kube-prometheus-stack); cold-start delay |
| **PDB (minAvailable: 1)** | Guarantees availability during voluntary disruptions (node upgrades) | May slow down rolling updates if only 2 replicas are running |
| **Topology spread across AZs** | Distributes pods evenly for AZ failure resilience | Pods may remain Pending if one AZ has insufficient capacity |
| **RollingUpdate (maxSurge: 1, maxUnavailable: 0)** | Zero-downtime deployments | Requires enough cluster capacity for the extra pod |
| **LoadBalancer service type** | Simple external access without Ingress controller setup | Creates one AWS NLB per service; use Ingress for multi-service setups |

### Monitoring

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **kube-prometheus-stack** | Batteries-included: Prometheus, Grafana, Alertmanager, node-exporter | Heavy chart (~100 CRDs); overkill for a single service but production-ready |
| **ServiceMonitor** | Declarative scrape config, auto-discovered by Prometheus Operator | Requires Prometheus Operator CRDs |
| **gp3 storage** | 20% cheaper than gp2, better baseline IOPS | Requires EBS CSI driver |
| **15-day retention** | Balances storage cost with useful history | Increase for production; consider Thanos/Cortex for long-term storage |
| **Custom alerts** | Proactive detection: error rate, latency, pod restarts, service down | Alertmanager receivers (Slack, PagerDuty) not configured — add per team needs |

### CI/CD

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **OIDC federation** | No long-lived AWS credentials stored in GitHub | Requires one-time IAM OIDC provider setup |
| **Path-based triggers** | Only runs pipeline when relevant files change | May miss cross-cutting changes; add manual trigger if needed |
| **Smoke tests post-deploy** | Validates the live deployment, not just the image | Adds ~30s to pipeline; worth it for confidence |
| **Concurrency control** | Prevents overlapping deployments to the same environment | Queues deployments instead of cancelling; avoids partial states |
| **Terraform apply with environment gate** | Prevents accidental infra changes on push | Requires GitHub environment approval configuration |

---

## Known Limitations

1. **Single NAT Gateway** — Not HA. For production, deploy one NAT gateway per AZ by modifying `vpc.tf`.

2. **Grafana password in plain text** — The default password is in `values-prometheus-stack.yaml`. In production, use a Kubernetes Secret or external secret manager (e.g., AWS Secrets Manager + External Secrets Operator).

3. **No TLS termination** — The LoadBalancer serves plain HTTP. Add an ACM certificate and configure the ALB Ingress for HTTPS in production.

4. **No remote Terraform state** — State is stored locally by default. Uncomment the S3 backend in `versions.tf` and create the S3 bucket + DynamoDB table for team collaboration.

5. **Cluster Autoscaler not installed** — The node group supports scaling (min: 1, max: 5), but the Kubernetes Cluster Autoscaler or Karpenter must be installed separately to trigger node scaling.

6. **ECR repository creation is manual** — The ECR repo is not in Terraform to keep the infra and app lifecycle separate. Add it to Terraform if preferred.

7. **No network policies** — Pod-to-pod traffic is unrestricted. Add Calico or Cilium network policies for zero-trust networking.

---

## Cleanup

```bash
# 1. Remove the application
helm uninstall hello-world

# 2. Remove monitoring stack
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring

# 3. Destroy infrastructure (removes VPC, EKS, IAM roles, etc.)
cd terraform
terraform destroy

# 4. Delete ECR repository
aws ecr delete-repository \
  --repository-name lucidity/hello-world \
  --region ap-south-1 --force
```

---

## License

This project was created as part of the Lucidity DevOps take-home assignment.

