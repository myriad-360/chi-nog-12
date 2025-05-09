# chi-nog-12

This project automates the provisioning, configuration, and CI/CD-driven deployment of a [Nautobot](https://nautobot.readthedocs.io/) lab and firewall rules using [Terraform](https://www.terraform.io/), [Ansible](https://www.ansible.com/), [Docker Compose](https://docs.docker.com/compose/), and [GitHub Actions](https://docs.github.com/en/actions). It includes:

- **Terraform**: Spins up an AWS EC2 instance, installs Docker & Ansible, and copies project files.  
- **Ansible**: Brings up the Nautobot Docker Compose stack, bootstraps a superuser, and applies Palo Alto firewall configurations based on ticket data.  
- **Docker Compose**: Runs the `networktocode/nautobot-lab` stack for Nautobot.  
- **Python Jira Automation**: The [`jira_polling_script.py`](./jira/jira_polling_script.py) polls the [Jira Cloud API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/) to fetch new firewall request tickets and renders them as JSON artifacts, while the [`jira_update_ticket.py`](./jira/jira_update_ticket.py) script transitions processed tickets.  
- **GitHub Actions**: Orchestrates the Jira polling, artifact upload, EC2 deployment, Ansible execution, and Jira status updates on a schedule or manual dispatch.  

# Demo Video
[![Watch the video](https://img.youtube.com/vi/rEISJXbu_cU/maxresdefault.jpg)](https://www.youtube.com/watch?v=rEISJXbu_cU)

<details>
<summary>Repository Structure</summary>

```
.
├── LICENSE                                        # MIT license governing this project
├── README.md                                      # Project overview, setup, and usage instructions
├── ansible/                                       # Ansible playbooks, roles, and configs
│   ├── ansible.cfg                                # Custom Ansible configuration (inventory paths, defaults)
│   ├── archive/                                   # Archived/legacy playbooks for reference
│   │   ├── ansible-hello-world-via-actions.yml    # Demo playbook showing Ansible “Hello World” via GitHub Actions  
│   │   ├── print-artifact.yml                     # Example to print uploaded CI artifact contents  
│   │   └── print_json_vars.yml                    # Example to load and display JSON vars in playbook  
│   ├── deploy_nautobot_lab.yaml                   # Main playbook to bring up Nautobot stack on EC2  
│   ├── nautobot-superuser-vars.yml                # Vaulted vars file for Nautobot superuser credentials  
│   └── palo/                                      # Palo Alto firewall automation playbooks
│       ├── archive/                               # Legacy Palo Alto examples
│       │   ├── hello-world/                       # Basic “hello world” against firewall
│       │   │   ├── host_vars/          
│       │   │   │   └── palo-secrets.yml           # Credentials for the simple hello-world test  
│       │   │   ├── inventory.txt                  # Static inventory for hello-world test  
│       │   │   └── palo-hello-world.yml           # Simple playbook creating a test object/rule  
│       │   ├── hello-world-nautobot/              # Hello-world example using Nautobot inventory
│       │   │   ├── ansible.cfg                    # Config pointing to Nautobot plugin  
│       │   │   ├── inventory/          
│       │   │   │   └── nautobot.yml               # Dynamic inventory config for Nautobot  
│       │   │   ├── inventory.txt                  # Fallback static inventory  
│       │   │   └── palo-hello-world.yml           # Playbook using Nautobot inventory  
│       │   └── object-and-nat/                    # Legacy object+NAT without Nautobot
│       │       ├── create-object-and-nat.yml      # Creates address object and NAT rule on Palo Alto 
│       │       ├── inventory.txt                  # Static inventory for this flow  
│       │       └── vars/               
│       │           ├── input-variables.yml        # Input variables for object+NAT  
│       │           └── palo-secrets.yml           # Secrets file for firewall creds  
│       └── object-and-nat-nautobot/               # Current object+NAT playbooks via GH artifacts
│           ├── ansible.cfg                        # Config for this specific playbook  
│           ├── create-object-and-nat-viaGH.yml    # Main playbook: loads JSON from GitHub Actions, creates object/NAT  
│           ├── create-object-and-nat.yml          # Variant playbook without GH-specific logic
│           ├── inventory/              
│           │   └── nautobot.yml                   # Dynamic inventory using Nautobot plugin  
│           └── inventory.txt                      # Static fallback inventory  
├── docker/                                        # Docker Compose definitions
│   └── nautobot/                      
│       └── docker-compose.yml                     # Docker Compose v1 file for Nautobot stack  
├── jira/                                          # Python scripts & artifacts for Jira integration
│   ├── archive/                                   # Older Jira integration examples
│   │   ├── jira_hello_world.py                    # Demo script to hit Jira API  
│   │   └── jira_ticket_to_json.py                 # Early version of ticket→JSON conversion  
│   ├── artifacts/                                 # JSON files generated by polling script  
│   ├── jira_polling_script.py                     # Polls Jira Cloud API ⇒ writes per-ticket JSON  
│   └── jira_update_ticket.py                      # Moves tickets through Jira transitions  
├── terraform/                                     # Terraform IaC for EC2 + Ansible bootstrapping
│   ├── chinog12.auto.tfvars                       # Terraform input variables (gitignored)  
│   ├── main.tf                                    # Provisions EC2, installs Docker/Ansible, syncs files  
│   ├── terraform.tfstate                          # Current Terraform state (gitignored)  
│   ├── terraform.tfstate.backup                   # Backup of previous state (gitignored)  
│   └── variables.tf                               # Variable declarations for Terraform  
└── terraform.tfstate                              # Root-level link to state (if used)  
```
</details>

## Prerequisites

- Terraform ≥ 1.5  
- Ansible ≥ 2.15  
- Docker Compose v1 (`docker-compose` CLI)  
- Local SSH keypair registered in AWS  

**GitHub Secrets**  
Configure each under **Repository Settings -> Secrets and variables -> Actions -> New repository secret**:

| Secret Name             | Description                                                    | How to Create / Notes                                                                                 |
|-------------------------|----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `JIRA_EMAIL`            | Email for Jira API authentication                              | Your Atlassian account email                                                                          |
| `JIRA_TOKEN`            | API token for Jira                                            | Generate at https://id.atlassian.com/manage-profile/security/api-tokens                              |
| `JIRA_SITE`             | Domain of your Jira instance                                  | e.g. `your-sandbox.atlassian.net`                                                                |
| `JIRA_PROJECT`          | Jira project key to poll                                      | e.g. `JTEJ`                                                                                            |
| `JIRA_STATUS`           | Jira issue status filter (e.g., `Ready for Build`)            | Must match your Jira workflow status name                                                             |
| `AWS_ACCESS_KEY_ID`     | AWS access key for Terraform and AWS CLI                      | Create an IAM user in AWS IAM                                                                         |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for Terraform and AWS CLI                      | Create an IAM user in AWS IAM                                                                         |
| `AWS_REGION`            | AWS region for resource deployment                            | e.g. `us-east-2`                                                                                       |
| `EC2_SSH_KEY`           | Private SSH key for EC2 instance                              | Paste your PEM file contents (keep it secure)                                                         |
| `EC2_USER`              | SSH username for EC2 instance                                 | e.g. `ubuntu`, `ec2-user`                                                                             |
| `EC2_INSTANCE_NAME`     | `Name` tag of the EC2 instance to target                      | Must match the tag assigned in Terraform                                                              |
| `PALO_ADMIN_USER`       | Palo Alto firewall admin username                             | Configure on the firewall or store in your vault                                                      |
| `PALO_ADMIN_PW`         | Palo Alto firewall admin password   

## Setup & Deployment

1. **Clone the repo**  
   ```bash
   git clone https://github.com/myriad-360/chi-nog-12.git
   cd chi-nog-12
   ```

2. **Configure Terraform variables**  
   Create `terraform/chinog12.auto.tfvars` with your AWS credentials and settings:
   ```hcl
   aws_region     = "us-east-2"
   aws_access_key = "YOUR_ACCESS_KEY"
   aws_secret_key = "YOUR_SECRET_KEY"
   instance_type  = "t3.small"
   key_name       = "your-keypair-name"
   vpc_name       = ""  #  This is optional - the default VPC will be used if not provided
   subnet_name    = ""  #  This is optional - the default subnet will be used if not provided
   ```

3. **Configure Ansible superuser vars**  
   Create `ansible/nautobot-superuser-vars.yml` (gitignored):
   ```yaml
   nautobot_superuser_name: admin
   nautobot_superuser_email: admin@example.com
   nautobot_superuser_password: admin
   ```

4. **Initialize & apply Terraform**  
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```  
   Terraform will provision the EC2 instance and copy Ansible playbooks. This will result in a vanilla environment with nautobot deployed but lacking full configuration.

5. **Review GitHub Actions**  
   The `jira-to-ec2-ansible-nautobot-palo.yml` workflow (in `.github/workflows`) runs every 5 minutes (or manually):  
   - **Poll Jira**: Identifies new tickets, writes JSON with ticket details into `artifacts/`.  
   - **Deploy to EC2**: Opens SSH, installs PAN‑OS requirements, copies playbooks & artifacts. It's important to note that palo alto requires that we have the ansible on a machine with connectivity to the palo alto. By default, we'll be running this via github actions, which does not have connectivity
   - **Ansible Run**: Executes the firewall playbook via dynamic inventory that's provided by Nautobot.  
   - **Update Jira**: Transitions each processed ticket to “Confirmed Deployed.”  
   - **Cleanup**: Revokes SSH ingress from the GitHub runner.

6. **Access Nautobot**  
   After Terraform finishes, note the public IP output and open:
   ```
   http://<public-ip>:8000
   ```

## Key Files & Scripts

- `jira/jira_polling_script.py`: Polls Jira via Cloud API, fetches form answers & issue fields, and writes per-issue JSON.  
- `jira/jira_update_ticket.py`: Fetches available transitions and moves the issue to the specified state.  
- `ansible/palo/object-and-nat-viaGH.yml`: Reads ticket JSON, creates address object & NAT rule, commits on a Palo Alto firewall.  
- `inventory/nautobot.yml`: Nautobot dynamic inventory plugin configuration.

## Notes

- All automation runs inside the EC2 instance via Terraform and GitHub Actions.  
- Uses Docker Compose v1; update commands if you switch to v2.

## License

This project is licensed under the MIT License.
