#!/usr/bin/env python3
import os
import sys
import json
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

def main():
    load_dotenv()

    # ── 1) Load & validate env vars ────────────────────────────────────────
    email   = os.getenv("JIRA_EMAIL")
    token   = os.getenv("JIRA_TOKEN")
    site    = os.getenv("JIRA_SITE")
    project = os.getenv("JIRA_PROJECT", "JTEJ")
    status  = os.getenv("JIRA_STATUS", "Ready for Build")

    if not all([email, token, site]):
        sys.exit("Missing one of: JIRA_EMAIL, JIRA_TOKEN or JIRA_SITE")

    auth = HTTPBasicAuth(email, token)

    # ── 2) Discover cloudId ───────────────────────────────────────────────
    tenant_url = f"https://{site}/_edge/tenant_info"
    resp       = requests.get(tenant_url, auth=auth)
    try:
        resp.raise_for_status()
    except requests.HTTPError:
        print("🚨 Failed to fetch tenant_info:")
        print(" URL→", tenant_url)
        print(" Status→", resp.status_code)
        print(" Body→", resp.text)
        sys.exit(1)

    t     = resp.json()
    cloud = t.get("cloudId") or t.get("tenantId")
    if not cloud:
        sys.exit("Unable to determine cloudId from tenant_info")

    # ── 3) JQL search for matching tickets ────────────────────────────────
    jql        = f'project = "{project}" AND status = "{status}"'
    search_url = f"https://{site}/rest/api/3/search"
    resp       = requests.get(
                    search_url,
                    auth=auth,
                    params={"jql": jql, "fields": "key", "maxResults": 100}
                )

    if resp.status_code != 200:
        print("🚨 Jira search failed!")
        print(" URL→", resp.url)
        print(" Status→", resp.status_code)
        print(" Body→", resp.text)
        sys.exit(1)

    issues = resp.json().get("issues", [])
    keys   = [i["key"] for i in issues]

    # ── 4) Load memory of processed keys ──────────────────────────────────
    mem_file = ".processed_issues"
    seen     = set()
    if os.path.exists(mem_file):
        with open(mem_file) as f:
            seen = {line.strip() for line in f if line.strip()}

    new_keys = [k for k in keys if k not in seen]
    if not new_keys:
        print("No new tickets; exiting.")
        return

    os.makedirs("artifacts", exist_ok=True)

    # ── 5) For each new ticket: fetch forms, answers, issue fields ───────
    for key in new_keys:
        ticket = {"issueKey": key}

        # 5a) forms metadata
        forms_url = (
            f"https://api.atlassian.com/jira/forms/cloud/{cloud}"
            f"/issue/{key}/form"
        )
        fr = requests.get(forms_url, auth=auth)
        if not fr.ok:
            print(f"⚠️  Could not fetch forms for {key}: {fr.status_code}")
        else:
            for form in fr.json():
                fid               = form.get("id")
                ticket["formId"]   = fid
                ticket["formName"] = form.get("name", "")

                # 5b) answers for each form
                ans_url = (
                    f"https://api.atlassian.com/jira/forms/cloud/{cloud}"
                    f"/issue/{key}/form/{fid}/format/answers"
                )
                ar = requests.get(ans_url, auth=auth)
                if ar.ok:
                    for e in ar.json():
                        question = (
                            e.get("label")
                            or e.get("question", {}).get("name", "")
                        )
                        ticket[question] = e.get("answer", "")

        # 5c) issue fields
        issue_url = f"https://{site}/rest/api/3/issue/{key}"
        ir        = requests.get(issue_url, auth=auth)
        try:
            ir.raise_for_status()
        except requests.HTTPError:
            print(f"⚠️  Could not fetch issue fields for {key}: {ir.status_code}")
            fields = {}
        else:
            fields = ir.json().get("fields", {})

        # normalize description
        desc = fields.get("description")
        if isinstance(desc, dict):
            desc = desc.get("plain") or desc.get("text") or ""
        ticket.update({
            "summary":     fields.get("summary", ""),
            "status":      fields.get("status", {}).get("name", ""),
            "created":     fields.get("created", ""),
            "updated":     fields.get("updated", ""),
            "description": desc or ""
        })

        # 5d) write JSON to artifacts/
        out_path = f"artifacts/{key}.json"
        with open(out_path, "w") as fp:
            json.dump(ticket, fp, indent=2)
        print(f"✔️  Wrote {out_path}")

    # ── 6) Append new keys to memory ───────────────────────────────────────
    with open(mem_file, "a") as fp:
        for k in new_keys:
            fp.write(k + "\n")
    print(f"Appended {new_keys} to {mem_file}")

if __name__ == "__main__":
    main()