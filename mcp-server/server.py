# ══════════════════════════════════════════════════════════════
# MCP SERVER — server.py
# The bridge between Claude and your platform's live data.
# Registers three tools and exposes them over HTTP so the
# AI agent can call them during a conversation.
# Start with: python3 mcp-server/server.py
# ══════════════════════════════════════════════════════════════

import json
import os
import sys
from pathlib import Path

# Add project root to Python path so we can import tool modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv

# Import our three MCP tool functions
from mcp_server.tools.terraform_state import get_terraform_state
from mcp_server.tools.pipeline_status import get_pipeline_status
from mcp_server.tools.policy_results import get_policy_results

# Load environment variables from .env file
load_dotenv()

# Create the FastAPI application
app = FastAPI(
    title="Platform Engineering MCP Server",
    description="Exposes platform infrastructure data as tools for the AI agent",
    version="1.0.0"
)

# Allow the AI agent (running on a different port) to call this server
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8000"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"]
)


# ── Tool Registry ─────────────────────────────────────────────
# This is what the AI agent reads to discover available tools.
# Each tool has a name, description, and parameter schema.
# Claude uses the description to decide WHEN to call each tool.
TOOL_REGISTRY = [
    {
        "name": "get_terraform_state",
        "description": "Returns a summary of currently deployed AWS infrastructure for a given environment. Use this when asked what is deployed, what resources exist, or the current state of infrastructure.",
        "parameters": {
            "type": "object",
            "properties": {
                "environment": {
                    "type": "string",
                    "description": "The environment to check — dev, staging, or prod",
                    "enum": ["dev", "staging", "prod"],
                    "default": "dev"
                }
            }
        }
    },
    {
        "name": "get_pipeline_status",
        "description": "Returns the status of recent GitHub Actions CI/CD pipeline runs. Use this when asked if the last deployment succeeded, about pipeline health, or recent workflow runs.",
        "parameters": {
            "type": "object",
            "properties": {
                "workflow_name": {
                    "type": "string",
                    "description": "Optional — filter by workflow name. Leave empty to get all recent runs."
                }
            }
        }
    },
    {
        "name": "get_policy_results",
        "description": "Runs OPA policy checks against the current Terraform plan and returns compliance results. Use this when asked about policy violations, compliance status, or whether a configuration is allowed.",
        "parameters": {
            "type": "object",
            "properties": {
                "plan_path": {
                    "type": "string",
                    "description": "Path to the Terraform plan JSON file",
                    "default": "tfplan.json"
                }
            }
        }
    }
]


# ── API Endpoints ─────────────────────────────────────────────

@app.get("/tools")
def list_tools():
    """Returns the list of available tools and their schemas."""
    return {"tools": TOOL_REGISTRY}


@app.get("/tools/terraform_state")
def terraform_state_endpoint(environment: str = "dev"):
    """Calls the Terraform state tool and returns results."""
    result = get_terraform_state(environment=environment)
    return result


@app.get("/tools/pipeline_status")
def pipeline_status_endpoint(workflow_name: str = None):
    """Calls the pipeline status tool and returns results."""
    result = get_pipeline_status(workflow_name=workflow_name)
    return result


@app.get("/tools/policy_results")
def policy_results_endpoint(plan_path: str = "tfplan.json"):
    """Calls the OPA policy check tool and returns results."""
    result = get_policy_results(plan_path=plan_path)
    return result


class ToolCallRequest(BaseModel):
    """Request body for calling a tool by name with arguments."""
    tool_name: str
    arguments: dict = {}


@app.post("/tools/call")
def call_tool(request: ToolCallRequest):
    """
    Generic endpoint — the AI agent calls this to invoke any tool by name.
    Claude sends the tool name and arguments, this routes to the right function.
    """
    tool_name = request.tool_name
    args = request.arguments

    if tool_name == "get_terraform_state":
        return get_terraform_state(**args)
    elif tool_name == "get_pipeline_status":
        return get_pipeline_status(**args)
    elif tool_name == "get_policy_results":
        return get_policy_results(**args)
    else:
        raise HTTPException(status_code=404, detail=f"Tool '{tool_name}' not found")


@app.get("/health")
def health_check():
    """Simple health check endpoint — confirms the server is running."""
    return {"status": "healthy", "server": "platform-engineering-mcp"}


# ── Start the server ──────────────────────────────────────────
if __name__ == "__main__":
    print("🔌 Starting Platform Engineering MCP Server on port 8080...")
    print("📋 Available tools:")
    for tool in TOOL_REGISTRY:
        print(f"   - {tool['name']}: {tool['description'][:60]}...")
    print("\nAPI docs available at: http://localhost:8080/docs\n")

    uvicorn.run(app, host="0.0.0.0", port=8080)
