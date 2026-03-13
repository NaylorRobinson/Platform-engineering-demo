# ══════════════════════════════════════════════════════════════
# MCP TOOL — pipeline_status.py
# Calls the GitHub Actions API to get the status of the most
# recent workflow run on the repository.
# The AI agent calls this when asked "did the last pipeline succeed?"
# ══════════════════════════════════════════════════════════════

import requests
import os
from datetime import datetime


def get_pipeline_status(workflow_name: str = None) -> dict:
    """
    Fetches the status of recent GitHub Actions workflow runs.

    Args:
        workflow_name: Optional filter — e.g. "Terraform PR Validation"
                       If None, returns the most recent run of any workflow

    Returns:
        A dict containing run status, conclusion, and timing information
    """

    # GitHub repo and token from environment variables
    repo = os.getenv("GITHUB_REPO")
    token = os.getenv("GITHUB_TOKEN")

    if not repo or not token:
        return {
            "status": "error",
            "message": "GITHUB_REPO and GITHUB_TOKEN must be set in .env"
        }

    # GitHub API endpoint for workflow runs
    url = f"https://api.github.com/repos/{repo}/actions/runs"

    # Authentication header — GitHub requires a token for API calls
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    }

    # Request the 5 most recent workflow runs
    params = {"per_page": 5}

    try:
        response = requests.get(url, headers=headers, params=params)

        # Raise an exception if the API returned an error status code
        response.raise_for_status()

        data = response.json()
        runs = data.get("workflow_runs", [])

        if not runs:
            return {
                "status": "no_runs",
                "message": "No workflow runs found for this repository."
            }

        # Format each run into a readable summary
        formatted_runs = []
        for run in runs:
            # Parse the ISO timestamp into a readable format
            created_at = run.get("created_at", "")
            try:
                dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
                formatted_time = dt.strftime("%Y-%m-%d %H:%M UTC")
            except Exception:
                formatted_time = created_at

            formatted_runs.append({
                "workflow_name": run.get("name"),
                # status = queued, in_progress, or completed
                "status": run.get("status"),
                # conclusion = success, failure, cancelled, skipped (only set when status=completed)
                "conclusion": run.get("conclusion"),
                "branch": run.get("head_branch"),
                "commit_message": run.get("head_commit", {}).get("message", "")[:100],
                "triggered_by": run.get("triggering_actor", {}).get("login"),
                "run_at": formatted_time,
                # Link to the run in the GitHub UI
                "url": run.get("html_url")
            })

        # Determine the overall health based on the most recent run
        latest = formatted_runs[0]
        overall_health = "unknown"
        if latest["status"] == "completed":
            overall_health = "healthy" if latest["conclusion"] == "success" else "failing"
        elif latest["status"] == "in_progress":
            overall_health = "running"

        return {
            "status": "success",
            "overall_health": overall_health,
            "recent_runs": formatted_runs,
            "repository": repo
        }

    except requests.exceptions.HTTPError as e:
        return {
            "status": "error",
            "message": f"GitHub API error: {str(e)}"
        }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e)
        }
