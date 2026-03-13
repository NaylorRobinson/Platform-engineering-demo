# ══════════════════════════════════════════════════════════════
# MCP TOOL — terraform_state.py
# Reads Terraform state from S3 and returns a summary of
# what infrastructure is currently deployed in the environment.
# The AI agent calls this when asked "what is deployed?"
# ══════════════════════════════════════════════════════════════

import boto3
import json
import os


def get_terraform_state(environment: str = "dev") -> dict:
    """
    Fetches the Terraform state file from S3 and returns a
    human-readable summary of deployed resources.

    Args:
        environment: The environment to check — dev, staging, or prod

    Returns:
        A dict containing resource counts and key infrastructure details
    """

    # Read configuration from environment variables set in .env
    bucket_name = os.getenv("TF_STATE_BUCKET")
    region = os.getenv("AWS_REGION", "us-east-1")

    # The key path matches what we set in backend.tf
    state_key = f"{environment}/terraform.tfstate"

    try:
        # Create an S3 client using credentials from environment variables
        s3 = boto3.client("s3", region_name=region)

        # Download the state file content from S3
        response = s3.get_object(Bucket=bucket_name, Key=state_key)

        # Read and parse the JSON state file
        state_content = response["Body"].read().decode("utf-8")
        state = json.loads(state_content)

        # Extract the list of managed resources from the state
        # Each resource in state has type, name, and attributes
        resources = state.get("resources", [])

        # Build a summary grouped by resource type
        summary = {}
        for resource in resources:
            resource_type = resource.get("type", "unknown")

            # Count how many instances of each type exist
            if resource_type not in summary:
                summary[resource_type] = []

            # Pull the name of each resource instance
            for instance in resource.get("instances", []):
                attrs = instance.get("attributes", {})
                summary[resource_type].append({
                    "name": resource.get("name"),
                    # Get the most useful identifier for each resource type
                    "id": attrs.get("id", "unknown"),
                    "arn": attrs.get("arn", None),
                })

        return {
            "environment": environment,
            "total_resources": len(resources),
            "resources_by_type": summary,
            "terraform_version": state.get("terraform_version", "unknown"),
            "serial": state.get("serial", 0),
            "status": "success"
        }

    except s3.exceptions.NoSuchKey:
        # State file doesn't exist — environment hasn't been deployed yet
        return {
            "environment": environment,
            "status": "no_state",
            "message": f"No Terraform state found for environment '{environment}'. Has it been deployed?"
        }
    except Exception as e:
        return {
            "environment": environment,
            "status": "error",
            "message": str(e)
        }
