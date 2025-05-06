#!/usr/bin/env python3
import os
import sys
import requests
import json
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

# Load credentials and site from .env
load_dotenv()
EMAIL     = os.getenv("JIRA_EMAIL")
API_TOKEN = os.getenv("JIRA_TOKEN")
SITE      = os.getenv("JIRA_SITE")  # e.g. "myriad360-sandbox.atlassian.net"

if not all([EMAIL, API_TOKEN, SITE]):
    print("Missing one of JIRA_EMAIL, JIRA_TOKEN, or JIRA_SITE in environment.", file=sys.stderr)
    sys.exit(1)

auth    = HTTPBasicAuth(EMAIL, API_TOKEN)
headers = {"Accept": "application/json"}

# Discover cloudId
tenant_url = f"https://{SITE}/_edge/tenant_info"
resp = requests.get(tenant_url, auth=auth, headers=headers)
resp.raise_for_status()
tenant   = resp.json()
cloud_id = tenant.get("cloudId") or tenant.get("tenantId")
if not cloud_id:
    print(f"Could not determine cloudId from tenant_info: {tenant}", file=sys.stderr)
    sys.exit(1)

# Issue key to dump
issue_key = "JTEJ-3"

output = {"issueKey": issue_key}

# 1) Fetch and flatten form answers (if any)
forms_index = (
    f"https://api.atlassian.com/jira/forms/cloud/{cloud_id}"
    f"/issue/{issue_key}/form"
)
resp = requests.get(forms_index, auth=auth, headers=headers)
resp.raise_for_status()
forms = resp.json()

for form in forms:
    form_id   = form.get("id")
    form_name = form.get("name", "")
    # include form metadata
    output["formId"]   = form_id
    output["formName"] = form_name

    # fetch simplified answers
    answers_url = (
        f"https://api.atlassian.com/jira/forms/cloud/{cloud_id}"
        f"/issue/{issue_key}/form/{form_id}/format/answers"
    )
    resp_ans = requests.get(answers_url, auth=auth, headers=headers)
    resp_ans.raise_for_status()
    answers = resp_ans.json()

    for entry in answers:
        # question label or name
        question = entry.get("label") or entry.get("question", {}).get("name", "")
        answer   = entry.get("answer", "")
        output[question] = answer

# 2) Fetch and flatten issue fields
issue_url  = f"https://{SITE}/rest/api/3/issue/{issue_key}"
resp_issue = requests.get(issue_url, auth=auth, headers=headers)
resp_issue.raise_for_status()
fields     = resp_issue.json().get("fields", {})

desc = fields.get("description")
if isinstance(desc, dict):
    # ADF plain text fallback
    desc_text = desc.get("plain") or desc.get("text") or ""
else:
    desc_text = desc or ""

output.update({
    "summary":     fields.get("summary", ""),
    "status":      fields.get("status", {}).get("name", ""),
    "created":     fields.get("created", ""),
    "updated":     fields.get("updated", ""),
    "description": desc_text
})

# print flat JSON
print(json.dumps(output, indent=2))