# ══════════════════════════════════════════════════════════════
# Makefile — platform-engineering-demo
# Simple commands to manage the full project lifecycle
# ══════════════════════════════════════════════════════════════

# The environment to target — defaults to dev
ENV ?= dev

# The path to the environment's Terraform config
TF_DIR = terraform/environments/$(ENV)

# ── Bring everything up ────────────────────────────────────────
# Initializes Terraform, provisions all AWS infrastructure,
# starts the MCP server, and launches the web UI
up:
	@echo "🚀 Bringing up platform-engineering-demo (env=$(ENV))..."
	cd $(TF_DIR) && terraform init && terraform apply -auto-approve
	@echo "✅ Infrastructure provisioned. Starting services..."
	python3 mcp-server/server.py &
	python3 agent/assistant.py

# ── Tear everything down ───────────────────────────────────────
# Destroys all AWS infrastructure Terraform created
# NOTE: Does NOT destroy the S3 state bucket or DynamoDB lock table
# Those are needed to recreate the environment next session
down:
	@echo "💥 Destroying all infrastructure (env=$(ENV))..."
	cd $(TF_DIR) && terraform destroy -auto-approve
	@echo "✅ All resources destroyed. Billing stopped."

# ── Show what would change without applying ───────────────────
# Safe to run anytime — reads current state and compares to config
plan:
	@echo "📋 Running Terraform plan (env=$(ENV))..."
	cd $(TF_DIR) && terraform init -reconfigure && terraform plan

# ── Run OPA policy checks locally ─────────────────────────────
# Generates a plan and validates it against all Rego policies
# Useful for catching violations before pushing a PR
validate:
	@echo "🔍 Running OPA policy validation..."
	cd $(TF_DIR) && terraform init -reconfigure && terraform plan -out=tfplan.binary
	cd $(TF_DIR) && terraform show -json tfplan.binary > ../../../tfplan.json
	conftest test tfplan.json --policy ./policies
	@echo "✅ OPA validation complete."

# ── Initialize Terraform only ──────────────────────────────────
# Downloads providers and connects to the S3 backend
init:
	@echo "🔧 Initializing Terraform (env=$(ENV))..."
	cd $(TF_DIR) && terraform init

# ── Format all Terraform files ────────────────────────────────
# Applies standard formatting across all .tf files
fmt:
	terraform fmt -recursive terraform/

# ── Start only the MCP server ─────────────────────────────────
mcp:
	@echo "🔌 Starting MCP server..."
	python3 mcp-server/server.py

# ── Start only the AI agent web UI ───────────────────────────
agent:
	@echo "🤖 Starting AI agent web UI..."
	python3 agent/assistant.py

.PHONY: up down plan validate init fmt mcp agent
