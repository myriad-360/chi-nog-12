#!/usr/bin/env python3

# Usage:
#   jira_update_ticket.py <issue_key> [-t <transition_name>]
#   ./jira_update_ticket.py JTEJ-42 --transition "Release to Prod"
import os
import sys
import requests
import json
import argparse
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

def load_env():
    load_dotenv()
    email = os.getenv("JIRA_EMAIL")
    token = os.getenv("JIRA_TOKEN")
    site  = os.getenv("JIRA_SITE")  # e.g. "mydomain.atlassian.net"
    if not all([email, token, site]):
        sys.exit("Error: Set JIRA_EMAIL, JIRA_TOKEN, and JIRA_SITE in your environment.")
    return email, token, site

def get_transitions(site, issue, auth, headers):
    url  = f"https://{site}/rest/api/3/issue/{issue}/transitions"
    resp = requests.get(url, auth=auth, headers=headers)
    resp.raise_for_status()
    return resp.json().get("transitions", [])

def do_transition(site, issue, transition_id, auth, headers):
    url     = f"https://{site}/rest/api/3/issue/{issue}/transitions"
    payload = {"transition": {"id": transition_id}}
    resp    = requests.post(url, auth=auth, headers=headers, json=payload)
    resp.raise_for_status()

def main():
    email, token, site = load_env()
    auth    = HTTPBasicAuth(email, token)
    headers = {"Accept": "application/json", "Content-Type": "application/json"}

    parser = argparse.ArgumentParser(description="Move a Jira issue via transition")
    parser.add_argument("issue_key", help="Key of the issue to transition (e.g. JTEJ-123)")
    parser.add_argument(
        "-t", "--transition",
        default=os.getenv("JIRA_TRANSITION", "Deployed"),
        help="Name of the transition to perform (default: %(default)s)"
    )
    args = parser.parse_args()

    # fetch available transitions
    try:
        transitions = get_transitions(site, args.issue_key, auth, headers)
    except requests.HTTPError as e:
        sys.exit(f"🚨 Failed to fetch transitions: {e}")

    # find requested transition
    tid = next(
        (t["id"] for t in transitions
         if t.get("name", "").lower() == args.transition.lower()),
        None
    )

    if not tid:
        print(f"No transition named '{args.transition}' found. Available:")
        for t in transitions:
            print(f"  • {t['name']} (id={t['id']})")
        sys.exit(1)

    # perform it
    try:
        do_transition(site, args.issue_key, tid, auth, headers)
        print(f"✅ {args.issue_key} moved to '{args.transition}'")
    except requests.HTTPError as e:
        sys.exit(f"🚨 Transition failed: {e}")

if __name__ == "__main__":
    main()