# platform-engineering-demo

> **A production-pattern golden path platform** built with Terraform, OPA, GitHub Actions, and an MCP-connected AI agent — demonstrating self-service infrastructure provisioning, automated compliance enforcement, and AI-powered platform operations on AWS.

---

## 📋 Table of Contents

- [The Story — SOART](#the-story--soart)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [The Golden Path in Action](#the-golden-path-in-action)
- [OPA Compliance Policies](#opa-compliance-policies)
- [AI Agent & MCP Server](#ai-agent--mcp-server)
- [CI/CD Pipeline](#cicd-pipeline)
- [Phase 2 Roadmap](#phase-2-roadmap)
- [Troubleshooting Notes](#troubleshooting-notes)

---

## The Story — SOART

### Scenario

Large engineering organizations face a common scaling problem. As the number of engineering teams grows, every team needs cloud infrastructure — VPCs, Kubernetes clusters, IAM roles, security groups. Without a standardized approach, each team builds their own way. Infrastructure looks different across teams. Security policies are inconsistently applied. The platform team becomes a bottleneck, fielding tickets and manually provisioning resources. There is no single source of truth for what is deployed, who owns it, or whether it meets compliance standards.

This is the reality at enterprise firms operating at scale — financial services, healthcare, technology. The cost is slow delivery, security risk, and engineering teams spending time on undifferentiated infrastructure work instead of building products.

### Obstacle

The challenge is giving engineering teams self-service access to infrastructure without sacrificing governance, security, or operational visibility. Specifically:

- How do you enforce security and compliance policy automatically before infrastructure reaches production?
- How do you maintain a human approval gate without making it a bottleneck?
- How do you give platform engineers and developers instant visibility into what is deployed, whether pipelines are healthy, and whether configurations are compliant — without manually digging through consoles and logs?

### Action

Built a complete golden path platform that addresses all three challenges:

**Infrastructure as Code** — Reusable Terraform modules for VPC, EKS, IAM, and security groups. Modules encode organizational standards by default — private subnets for worker nodes, least-privilege IAM roles, no open inbound ports. A dev environment configuration wires the modules together with remote state stored in S3 and state locking via DynamoDB.

**Policy as Code** — Four OPA Rego policies enforce compliance on every Terraform plan before anything reaches AWS. Encryption, tagging, networking, and IAM policies run automatically via Conftest in the CI/CD pipeline. A policy test suite validates the policies themselves.

**Governed CI/CD Pipeline** — GitHub Actions workflow triggers on every pull request. Terraform plan runs, OPA validates the plan, and a bot posts results directly on the PR as a comment. Violations block the merge. Compliant code proceeds to a manual approval gate before Terraform apply runs.

**AI-Powered Platform Operations** — A Python MCP server exposes three tools to an AI agent: Terraform state from S3, GitHub Actions pipeline status, and OPA policy results. A FastAPI backend connects Claude to the MCP server and serves a web UI where engineers and developers can query the platform in plain English and get answers backed by live infrastructure data.

### Result

A fully working golden path platform demonstrated end to end:

- A pull request with an open SSH security group and missing tags was automatically blocked by OPA with 11 violations listed in a bot comment on the PR
- A compliant pull request passed all policy checks, received a green bot comment, and deployed 23 AWS resources through the approved pipeline including an EKS cluster, VPC with public and private subnets, NAT gateways, IAM roles, and security groups
- The AI agent queried live Terraform state from S3 and summarized all deployed resources by type
- The AI agent called the GitHub Actions API and reported pipeline health including the last successful apply and currently running workflows
- The AI agent ran OPA policy checks and confirmed compliance status in plain English
- All infrastructure was provisioned and destroyed within a single session at a total AWS cost under $5

### Troubleshoot

**Rego syntax compatibility** — The OPA policies were initially written using the older `deny[msg] { }` syntax. When the pipeline downloaded Conftest v0.66.0 the policies failed with `var cannot be used for rule name`. Updated all policies to use `deny contains msg if { }` syntax which is compatible with Rego v1. Lesson: pin your Conftest version in the pipeline to match your local version.

**Conftest namespace resolution** — OPA initially returned 0 tests, 0 passed across all policies despite the plan file containing the target resources. Root cause was that the pipeline was not passing `--all-namespaces` to Conftest, so policies in namespaces other than `main` were not being evaluated. Adding `--all-namespaces` to both Conftest commands resolved the issue and all policies fired correctly.

**Tagging policy false positives** — The tagging policy initially flagged `aws_iam_role_policy_attachment` and `aws_route_table_association` resources for missing tags. These resource types do not support tags in AWS. Updated the policy to include an `untaggable_resources` set that excludes resource types that the AWS provider does not support tagging on.

**PowerShell encoding** — Windows PowerShell adds a UTF-8 BOM character when redirecting output with `>` which caused JSON parsing failures in OPA and Python. Resolved by using `Set-Content` with explicit encoding for local development. In the pipeline this is not an issue as the Linux runner handles encoding correctly.

**Anthropic SDK version** — Initial install of `anthropic==0.18.1` was incompatible with the installed version of httpx, throwing `TypeError: Client.__init__() got an unexpected keyword argument 'proxies'`. Resolved by upgrading to `anthropic==0.84.0`.

---

## Architecture

```
Developer (or Backstage portal)
        │
        ▼
  GitHub Pull Request
        │
        ▼
  GitHub Actions Pipeline
  ├── Terraform Init
  ├── Terraform Plan
  ├── OPA Policy Check (Conftest)
  ├── Bot comment on PR (pass/fail + violation details)
  └── Manual approval gate
        │
        ▼
  Terraform Apply
        │
        ▼
  AWS Infrastructure
  ├── VPC (public + private subnets, NAT gateways)
  ├── EKS Cluster + Node Group
  ├── IAM Roles + Policies (least privilege)
  └── Security Groups (no open inbound ports)
        │
        ▼
  Terraform State → S3 (encrypted, versioned)
  State Locking   → DynamoDB
        │
        ▼
  MCP Server (Python / FastAPI)
  ├── get_terraform_state   → reads S3 state
  ├── get_pipeline_status   → calls GitHub Actions API
  └── get_policy_results    → runs Conftest locally
        │
        ▼
  AI Agent (Claude via Anthropic API)
        │
        ▼
  Web UI (FastAPI + HTML/CSS/JS)
```

### Note on AI Model Selection

This project uses Claude via the Anthropic API for local development and portfolio demonstration. In a production enterprise environment the recommended path is **AWS Bedrock**, which runs Claude inside your existing AWS infrastructure under your VPC, IAM policies, and compliance controls — satisfying SOC 2, FedRAMP, and financial services regulatory requirements. The MCP server is model-agnostic and requires only a configuration change to switch between API providers.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Cloud | AWS (EKS, VPC, IAM, S3, DynamoDB) |
| IaC | Terraform 1.7+ |
| Policy | OPA / Conftest / Rego |
| Pipeline | GitHub Actions |
| AI Model | Claude (Anthropic API / AWS Bedrock in production) |
| AI Protocol | MCP (Model Context Protocol) |
| Backend | Python / FastAPI / Uvicorn |
| Frontend | HTML / CSS / JavaScript |
| State Backend | S3 + DynamoDB |

---

## Project Structure

```
platform-engineering-demo/
├── .github/
│   └── workflows/
│       ├── terraform-pr.yml          # PR validation — plan + OPA + bot comment
│       └── terraform-apply.yml       # Apply on merge with approval gate
├── agent/
│   ├── assistant.py                  # FastAPI backend + Claude agentic loop
│   ├── prompts/
│   │   └── platform_engineer.txt     # Claude system prompt
│   └── static/
│       └── index.html                # Web UI
├── mcp-server/
│   ├── server.py                     # MCP server — registers and serves tools
│   └── tools/
│       ├── terraform_state.py        # Tool: reads Terraform state from S3
│       ├── pipeline_status.py        # Tool: calls GitHub Actions API
│       └── policy_results.py         # Tool: runs OPA policy checks
├── policies/
│   ├── aws/
│   │   ├── encryption.rego           # S3 encryption enforcement
│   │   ├── tagging.rego              # Required tags enforcement
│   │   ├── networking.rego           # No open inbound ports
│   │   └── iam.rego                  # No wildcard IAM actions
│   └── tests/
│       └── policy_test.rego          # OPA policy unit tests
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── backend.tf            # S3 remote state config
│   │       ├── main.tf               # Environment entry point
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── modules/
│       ├── vpc/                      # VPC, subnets, NAT, routing
│       ├── eks/                      # EKS cluster + node group
│       ├── iam/                      # Roles, policies, attachments
│       └── security-groups/          # EKS security groups
├── .env.example                      # Environment variable template
├── .gitignore
└── Makefile                          # make up / make down / make validate
```

---

## Quick Start

### Prerequisites

- AWS CLI configured with credentials
- Terraform 1.7+
- Conftest 0.66+
- Python 3.11+
- Node.js 18+

### 1. Bootstrap AWS Backend

```bash
# Create S3 bucket for Terraform state — replace nkr-2026 with your suffix
aws s3api create-bucket --bucket platform-demo-tfstate-nkr-2026 --region us-east-1
aws s3api put-bucket-versioning --bucket platform-demo-tfstate-nkr-2026 --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name platform-demo-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Configure Environment

```bash
cp .env.example .env
# Fill in ANTHROPIC_API_KEY, GITHUB_TOKEN, TF_STATE_BUCKET, GITHUB_REPO
```

### 3. Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
terraform validate
```

### 4. Run OPA Policy Tests

```bash
conftest verify --policy ./policies
# Expected: 5 tests, 5 passed
```

### 5. Start the Platform

```bash
# Terminal 1 — MCP Server
python mcp-server/server.py

# Terminal 2 — AI Agent
python agent/assistant.py

# Open browser at http://localhost:8000
```

### 6. Tear Down

```bash
cd terraform/environments/dev
terraform destroy -auto-approve
```

---

## The Golden Path in Action

### Failing PR — Policy Violation Blocked

A pull request containing a security group with SSH open to `0.0.0.0/0` is automatically blocked by OPA. The GitHub Actions pipeline posts a bot comment listing every violation with the exact resource address and remediation instruction. The PR cannot be merged until violations are resolved.

### Passing PR — Compliant Infrastructure

A compliant pull request passes all OPA checks. The bot posts a green confirmation comment. A platform engineer reviews the Terraform plan and approves. The apply workflow runs and infrastructure deploys to AWS.

---

## OPA Compliance Policies

| Policy | File | What it enforces |
|--------|------|-----------------|
| Encryption | `encryption.rego` | S3 buckets must have server-side encryption configured |
| Tagging | `tagging.rego` | All resources must have `team`, `environment`, and `owner` tags |
| Networking | `networking.rego` | No security group may open port 22 or 3389 to `0.0.0.0/0` |
| IAM | `iam.rego` | No IAM policy may use wildcard `*` actions in Allow statements |

All policies are tested with `conftest verify --policy ./policies` before being wired into the pipeline.

---

## AI Agent & MCP Server

The AI agent exposes three MCP tools that Claude calls in real time during a conversation:

| Tool | Data Source | Example Query |
|------|------------|---------------|
| `get_terraform_state` | S3 Terraform state file | "What is deployed in dev?" |
| `get_pipeline_status` | GitHub Actions API | "Did the last pipeline succeed?" |
| `get_policy_results` | Conftest / OPA | "Are there any policy violations?" |

The web UI shows live infrastructure status in the left panel and a chat interface in the right panel. Tool calls are visible in real time as the agent works — showing exactly which data source was queried before each response.

---

## CI/CD Pipeline

### PR Validation (`terraform-pr.yml`)

Triggers on every pull request targeting `main` that touches `terraform/**` or `policies/**`.

1. Configure AWS credentials
2. Terraform init and validate
3. Terraform plan — saved as binary and converted to JSON
4. Conftest runs OPA policies against the plan JSON
5. Bot posts results as a PR comment — violations listed by resource with remediation guidance
6. Job fails if any violations found — PR is blocked

### Apply (`terraform-apply.yml`)

Triggers on merge to `main`. Requires approval from the `production` environment protection rule before Terraform apply runs.

---

## Phase 2 Roadmap

- **Backstage** — self-service developer portal where teams request infrastructure through a form instead of writing Terraform directly. Backstage scaffolder creates the PR automatically.
- **Multi-environment pipeline** — dedicated branches and pipelines for dev, staging, and production. Same modules, same policies, different configurations per environment.
- **Terraform Cloud or Atlantis** — PR-based Terraform workflow management with scheduled drift detection. Alerts when infrastructure has drifted from desired state between deployments.
- **AWS Config** — continuous compliance monitoring with rules that mirror the OPA policies. Catches manual changes made outside the pipeline after deployment. Closes the loop that OPA opens at deploy time.
- **Vault** — secrets management as a golden path service. Replaces environment variables and hardcoded credentials across all platform consumers.
- **Slack integration** — AI agent accessible via Slack so developers can query platform status without opening a browser.
- **Palo Alto VM-Series + Panorama** — Terraform configuration for network security policy pushed through Panorama, bringing firewall governance into the golden path alongside cloud infrastructure.
- **AWS Bedrock** — replace Anthropic direct API with Bedrock for enterprise deployment. Same Claude model running inside AWS under VPC and IAM controls with full compliance posture.

---

## Troubleshooting Notes

See the [Troubleshoot section](#troubleshoot) of the SOART story above for detailed notes on issues encountered during development and how they were resolved. Key issues covered:

- Rego syntax compatibility between Conftest versions
- Conftest namespace resolution with `--all-namespaces`
- Tagging policy false positives on untaggable resource types
- Windows PowerShell UTF-8 BOM encoding issues
- Anthropic SDK version compatibility

---

*Built by Naylor K. Robinson — Senior Network & Cloud Security Engineer / Platform Engineer*  
*[LinkedIn](https://linkedin.com/in/naylorkrobinson) | [GitHub](https://github.com/NaylorRobinson)*
