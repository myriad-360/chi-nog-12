import os
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

# Load from .env file
load_dotenv()

EMAIL = os.getenv("JIRA_EMAIL")
API_TOKEN = os.getenv("JIRA_TOKEN")
BASE_URL = "https://myriad360-sandbox.atlassian.net"

# Authenticate
auth = HTTPBasicAuth(EMAIL, API_TOKEN)
headers = { "Accept": "application/json" }

# Step 1: Confirm basic connection
url = f"{BASE_URL}/rest/api/3/project/search"
response = requests.get(url, headers=headers, auth=auth)

if response.status_code == 200:
    print("✅ Connected to Jira! Project list:")
    for project in response.json().get("values", []):
        print(f"- {project['name']} (key: {project['key']})")
else:
    print(f"❌ Error connecting to Jira: {response.status_code}")
    exit()

# Step 2: Get specific ticket details
ticket_key = "JTEJ-3"  # <-- Your ticket ID from the portal URL
ticket_url = f"{BASE_URL}/rest/api/3/issue/{ticket_key}"

ticket_response = requests.get(ticket_url, headers=headers, auth=auth)

if ticket_response.status_code == 200:
    print(f"✅ Successfully retrieved ticket {ticket_key}")
    ticket_data = ticket_response.json()

    # Print high-level info
    fields = ticket_data.get("fields", {})
    print(f"Summary: {fields.get('summary')}")
    print(f"Status: {fields.get('status', {}).get('name')}")
    print(f"Reporter: {fields.get('reporter', {}).get('displayName')}")
    print(f"Created: {fields.get('created')}")

    # Debug full payload if you want
    # import json
    # print(json.dumps(ticket_data, indent=2))
else:
    print(f"❌ Failed to retrieve ticket {ticket_key}: {ticket_response.status_code}")
    print(ticket_response.text)