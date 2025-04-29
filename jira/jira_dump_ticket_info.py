import os
import requests
import json
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv

# Load credentials
load_dotenv()

EMAIL = os.getenv("JIRA_EMAIL")
API_TOKEN = os.getenv("JIRA_TOKEN")
BASE_URL = "https://myriad360-sandbox.atlassian.net"

auth = HTTPBasicAuth(EMAIL, API_TOKEN)
headers = {"Accept": "application/json"}

# Specify your ticket key
ticket_key = "JTEJ-3"

# Request ticket details
url = f"{BASE_URL}/rest/api/3/issue/{ticket_key}"
response = requests.get(url, headers=headers, auth=auth)

if response.status_code == 200:
    print("Full ticket JSON response:")
    print(json.dumps(response.json(), indent=2))
    data = response.json()
    fields = data.get("fields", {})
    
    # Print basic summary information
    summary = fields.get("summary", "(No summary)")
    description = fields.get("description", "(No description)")
    print(f"📝 Summary: {summary}")
    print(f"🧾 Description: {description}")

    # Try to extract the JSM request ID
    request_metadata = fields.get("customfield_10010")
    if not request_metadata:
        print("❌ No JSM request metadata found.")
    else:
        request_links = request_metadata.get("_links", {})
        request_self_url = request_links.get("self")

        print(f"Extracted request_self_url: {request_self_url}")

        if not request_self_url:
            print("❌ No 'self' link found in request metadata.")
        else:
            import re
            match = re.search(r'/request/(\d+)', request_self_url)
            if match:
                request_id = match.group(1)
                print(f"🔎 Found JSM Request ID: {request_id}")

                # Now fetch the forms using the correct request_id as per correct API endpoint
                forms_url = f"{BASE_URL}/rest/servicedeskapi/request/{request_id}/form"
                print(f"Fetching forms from URL: {forms_url}")
                forms_response = requests.get(forms_url, headers=headers, auth=auth)

                if forms_response.status_code == 200:
                    forms_data = forms_response.json()
                    forms = forms_data.get("values", [])
                    if not forms:
                        print("⚠️ No forms found for this request.")
                    else:
                        for form in forms:
                            form_id = form.get("id")
                            form_name = form.get("name", "Unnamed Form")
                            if not form_id:
                                print(f"Form {form_name} has no ID, skipping.")
                                continue

                            print(f"\n📋 Form: {form_name} (ID: {form_id})")

                            # Fetch fields for this form using the ticket_key
                            fields_url = f"{BASE_URL}/rest/servicedeskapi/request/{ticket_key}/form/{form_id}/field"
                            print(f"Fetching fields from URL: {fields_url}")
                            fields_response = requests.get(fields_url, headers=headers, auth=auth)

                            if fields_response.status_code == 200:
                                fields_data = fields_response.json()
                                form_fields = fields_data.get("values", [])
                                if not form_fields:
                                    print(f"  ⚠️ No fields found for form {form_name}.")
                                else:
                                    for field in form_fields:
                                        field_name = field.get("name", "Unnamed Field")
                                        field_value = field.get("value")
                                        if field_value is None:
                                            field_value = "(No value entered)"
                                        elif isinstance(field_value, (dict, list)):
                                            field_value = json.dumps(field_value, indent=2)
                                        print(f"  ➤ {field_name}: {field_value}")
                            else:
                                print(f"  ❌ Error fetching fields for form {form_name}: HTTP {fields_response.status_code}")
                                print(f"  Response body: {fields_response.text}")
                else:
                    print(f"❌ Error fetching forms: HTTP {forms_response.status_code}")
                    print(f"Response body: {forms_response.text}")
            else:
                print("❌ Could not extract request ID from self link.")
else:
    print(f"❌ Error fetching ticket: {response.status_code}")
    print(f"Response body: {response.text}")