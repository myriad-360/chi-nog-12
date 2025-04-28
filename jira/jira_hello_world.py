import os
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

# Load from .env file
load_dotenv()

EMAIL = os.getenv("JIRA_EMAIL")
API_TOKEN = os.getenv("JIRA_TOKEN")
BASE_URL = "https://myriad360-sandbox.atlassian.net"

# Debug: Print to confirm values are loaded
print(f"📧 Email: {EMAIL}")
print(f"🔐 Token starts with: {API_TOKEN[:10]}...")

url = f"{BASE_URL}/rest/api/3/project/search"
auth = HTTPBasicAuth(EMAIL, API_TOKEN)
headers = { "Accept": "application/json" }

response = requests.get(url, headers=headers, auth=auth)

if response.status_code == 200:
    print("✅ Connected to Jira! Project list:")
    for project in response.json().get("values", []):
        print(f"- {project['name']} (key: {project['key']})")
        if project["name"] == "JSM Test Env - JH":
            print("🎯 Found target project!")
else:
    print(f"❌ Error: {response.status_code}")
    print(response.text)