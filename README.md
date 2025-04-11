# chi-nog-12

This project provisions and configures a fully automated Nautobot lab using Terraform and Ansible. The stack consists of an AWS EC2 instance, Docker Compose-based Nautobot deployment, and a bootstrapped superuser.

## Project Structure

\```
.
├── LICENSE
├── README.md
├── ansible
│   ├── ansible-hello-world-via-actions.yml           # Example workflow
│   ├── ansible.cfg                                   # Custom Ansible config
│   ├── deploy_nautobot_lab.yaml                      # Main playbook to deploy Nautobot
│   └── nautobot-superuser-vars.yml                   # Superuser credentials (NOT checked in)
├── docker
│   └── nautobot
│       └── docker-compose.yml                        # Docker Compose file for Nautobot
├── terraform
│   ├── chinog12.auto.tfvars                          # Input variables (e.g. keys, instance type)
│   ├── main.tf                                       # Main Terraform logic (provision EC2 + run Ansible)
│   ├── terraform.tfstate                             # Terraform state file
│   ├── terraform.tfstate.backup                      # State backup
│   └── variables.tf                                  # Terraform input variable declarations
└── terraform.tfstate                                 # Root-level TF state link
\```

## Overview

This project automates the provisioning and configuration of a Nautobot instance using:

- **Terraform**: Creates an EC2 instance, installs Docker, Ansible, and copies project files.
- **Ansible**: Brings up the Docker Compose stack and creates a Nautobot superuser.
- **Docker Compose**: Launches the Nautobot container using `networktocode/nautobot-lab`.

## Prerequisites

- Terraform 1.5+
- Ansible 2.15+
- AWS access key and secret key
- SSH keypair registered in AWS
- Docker Compose v1 (`docker-compose` CLI) is used in this setup

## Setup Instructions

1. **Clone the repo**

   \```bash
   git clone https://github.com/your-org/chi-nog-12.git
   cd chi-nog-12
   \```

2. **Create `terraform/chinog12.auto.tfvars`**

   Example:

   \```hcl
   aws_region     = "us-east-2"
   aws_access_key = "your-access-key"
   aws_secret_key = "your-secret-key"
   instance_type  = "t3.small"
   key_name       = "your-keypair-name"
   vpc_name       = ""
   subnet_name    = ""
   \```

3. **Create `ansible/nautobot-superuser-vars.yml`**

   This file should not be checked into version control. Example:

   \```yaml
   nautobot_superuser_name: admin
   nautobot_superuser_email: admin@example.com
   nautobot_superuser_password: admin
   \```

4. **Initialize and apply Terraform**

   \```bash
   cd terraform
   terraform init
   terraform apply
   \```

5. **Access Nautobot**

   After deployment, Terraform will output the instance's public IP. Open:

   \```
   http://<public-ip>:8000
   \```

## Notes

- All automation runs from inside the EC2 instance.
- Ansible playbooks are copied to and executed remotely by Terraform.
- `docker-compose` is used directly (v1 CLI). If using Docker Compose v2, updates are required.

## License

This project is licensed under the MIT License.