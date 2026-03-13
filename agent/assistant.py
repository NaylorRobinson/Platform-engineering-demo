# ══════════════════════════════════════════════════════════════
# AI AGENT BACKEND — assistant.py
# FastAPI backend that handles chat requests from the web UI.
# Connects to Claude via the Anthropic API, passes MCP tool
# definitions, and executes tool calls by forwarding them to
# the MCP server running on port 8080.
# Start with: python3 agent/assistant.py
# ══════════════════════════════════════════════════════════════

import json
import os
import requests
from pathlib import Path

import anthropic
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# Load environment variables from .env file in the project root
load_dotenv()

# ── FastAPI app setup ─────────────────────────────────────────
app = FastAPI(
    title="Platform Engineering AI Agent",
    description="AI assistant backed by Claude with live MCP tool access",
    version="1.0.0"
)

# Allow browser requests from the same origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"]
)

# Serve the static HTML/CSS/JS web UI from the agent/static directory
app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")

# ── Initialize Anthropic client ───────────────────────────────
# Reads ANTHROPIC_API_KEY from the .env file automatically
client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

# ── MCP Server base URL ───────────────────────────────────────
# The MCP server runs separately on port 8080
MCP_SERVER_URL = "http://localhost:8080"

# ── Load the system prompt from file ─────────────────────────
# This tells Claude its role and how to behave as a platform assistant
SYSTEM_PROMPT_PATH = Path(__file__).parent / "prompts" / "platform_engineer.txt"
with open(SYSTEM_PROMPT_PATH) as f:
    SYSTEM_PROMPT = f.read()

# ── Tool definitions for Claude ───────────────────────────────
# These match the tools registered in the MCP server.
# Claude reads these to decide which tool to call for a given question.
TOOLS = [
    {
        "name": "get_terraform_state",
        "description": "Returns a summary of currently deployed AWS infrastructure for a given environment. Call this when asked what is deployed, what resources exist, or the current state of infrastructure.",
        "input_schema": {
            "type": "object",
            "properties": {
                "environment": {
                    "type": "string",
                    "description": "The environment to check — dev, staging, or prod",
                    "enum": ["dev", "staging", "prod"]
                }
            },
            "required": []
        }
    },
    {
        "name": "get_pipeline_status",
        "description": "Returns the status of recent GitHub Actions CI/CD pipeline runs. Call this when asked if a deployment succeeded, about pipeline health, or recent workflow run results.",
        "input_schema": {
            "type": "object",
            "properties": {
                "workflow_name": {
                    "type": "string",
                    "description": "Optional filter by workflow name. Leave empty to get all recent runs."
                }
            },
            "required": []
        }
    },
    {
        "name": "get_policy_results",
        "description": "Runs OPA policy checks and returns compliance results for the current Terraform plan. Call this when asked about policy violations, compliance status, or whether a configuration is allowed.",
        "input_schema": {
            "type": "object",
            "properties": {
                "plan_path": {
                    "type": "string",
                    "description": "Path to the Terraform plan JSON file. Defaults to tfplan.json"
                }
            },
            "required": []
        }
    }
]


def call_mcp_tool(tool_name: str, tool_input: dict) -> str:
    """
    Calls the MCP server to execute a tool and returns the result as a string.
    Claude receives this result and uses it to formulate its response.

    Args:
        tool_name: The name of the tool to call (must match MCP server registry)
        tool_input: The arguments to pass to the tool

    Returns:
        JSON string of the tool's result
    """
    try:
        # POST to the MCP server's generic tool call endpoint
        response = requests.post(
            f"{MCP_SERVER_URL}/tools/call",
            json={"tool_name": tool_name, "arguments": tool_input},
            timeout=15  # 15 second timeout — AWS calls can be slow
        )
        response.raise_for_status()
        return json.dumps(response.json())
    except requests.exceptions.ConnectionError:
        return json.dumps({
            "error": "MCP server is not running. Start it with: python3 mcp-server/server.py"
        })
    except Exception as e:
        return json.dumps({"error": str(e)})


# ── Request and response models ───────────────────────────────

class ChatMessage(BaseModel):
    """A single message in the conversation."""
    role: str   # 'user' or 'assistant'
    content: str

class ChatRequest(BaseModel):
    """The full request from the web UI."""
    messages: list[ChatMessage]

class ChatResponse(BaseModel):
    """The response sent back to the web UI."""
    response: str
    tool_calls: list[str] = []  # Names of tools that were called — shown in the UI


# ── Main chat endpoint ────────────────────────────────────────

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Handles a chat request from the web UI.

    1. Sends the conversation history to Claude with tool definitions
    2. If Claude decides to call a tool, executes it via the MCP server
    3. Feeds tool results back to Claude
    4. Returns Claude's final text response to the UI
    """

    # Convert request messages to the format Claude expects
    messages = [{"role": m.role, "content": m.content} for m in request.messages]

    tool_calls_made = []  # Track which tools were called for the UI indicator

    # ── Agentic loop ──────────────────────────────────────────
    # Claude may call multiple tools before giving a final answer.
    # We loop until Claude stops requesting tool calls.
    while True:
        # Call Claude with the conversation history and available tools
        response = client.messages.create(
            model="claude-sonnet-4-20250514",  # Use Claude Sonnet 4 — fast and capable
            max_tokens=1024,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages
        )

        # Check if Claude wants to call a tool
        if response.stop_reason == "tool_use":
            # Process all tool calls in this response
            tool_results = []

            for block in response.content:
                if block.type == "tool_use":
                    tool_name = block.name
                    tool_input = block.input

                    # Record which tool was called so the UI can show it
                    tool_calls_made.append(tool_name)

                    # Execute the tool via the MCP server
                    tool_result = call_mcp_tool(tool_name, tool_input)

                    # Collect the result to send back to Claude
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": tool_result
                    })

            # Add Claude's tool-calling response to the message history
            messages.append({
                "role": "assistant",
                "content": response.content
            })

            # Add the tool results so Claude can see what the tools returned
            messages.append({
                "role": "user",
                "content": tool_results
            })

            # Loop back — Claude will now formulate a response using the tool data

        elif response.stop_reason == "end_turn":
            # Claude has finished — extract the final text response
            final_text = ""
            for block in response.content:
                if hasattr(block, "text"):
                    final_text += block.text

            return ChatResponse(
                response=final_text,
                tool_calls=tool_calls_made
            )
        else:
            # Unexpected stop reason — return whatever Claude said
            return ChatResponse(
                response="Unexpected response from Claude. Please try again.",
                tool_calls=tool_calls_made
            )


# ── Serve the web UI ──────────────────────────────────────────

@app.get("/")
def serve_ui():
    """Serves the main web UI HTML file."""
    return FileResponse(Path(__file__).parent / "static" / "index.html")


@app.get("/health")
def health():
    """Health check endpoint."""
    return {"status": "healthy", "agent": "platform-engineering-demo"}


# ── Start the server ──────────────────────────────────────────
if __name__ == "__main__":
    print("🤖 Starting Platform Engineering AI Agent on port 8000...")
    print("🌐 Open your browser at: http://localhost:8000")
    print("🔌 Make sure the MCP server is running on port 8080 first\n")
    uvicorn.run(app, host="0.0.0.0", port=8000)
