# Nautobot Demo Deployment (AWS + Terraform + Ansible)

This project provisions an AWS EC2 instance using Terraform and installs Nautobot via Docker using Ansible. It's designed as a fast, demo-friendly environment for network automation pipelines and toolchain demonstrations.

## 🔧 Components

- **Terraform** – Provisions an Ubuntu-based EC2 instance on AWS.
- **Ansible** – Installs Docker and deploys Nautobot using Docker Compose.
- **Nautobot** – Runs in a container, exposed on port `8000`.

## ✅ Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- An AWS account and access credentials
- SSH key pair (`~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)
- Ubuntu-compatible base image (AMI used: `ami-0c02fb55956c7d316`)

## 🔒 AWS Credentials Setup

This demo uses a `.auto.tfvars` file to pass credentials and variable inputs. **This file must never be committed to version control.**

Inside `terraform/chinog12.auto.tfvars`:

```hcl
aws_access_key = "AKIAEXAMPLE123456"
aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
aws_region     = "us-east-1"

instance_type  = "t3.medium"
key_name       = "deployer-key"
```

Then, make sure `.gitignore` includes the credentials file:

```bash
echo "terraform/chinog12.auto.tfvars" >> .gitignore
```

## 🚀 Usage

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/chi-nog-12.git
cd chi-nog-12
```

### 2. Initialize and Apply Terraform

```bash
cd terraform
terraform init
terraform apply
```

Terraform will automatically load `chinog12.auto.tfvars` and provision the EC2 instance. On success, it will output the public IP of the instance.

### 3. Create Ansible Inventory

From the `terraform/` directory, create a new file called `inventory.ini`:

```ini
[nautobot]
<instance_ip> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

Replace `<instance_ip>` with the IP address output from Terraform.

### 4. Run the Ansible Playbook

```bash
cd ../ansible
ansible-playbook -i ../terraform/inventory.ini install_docker_and_nautobot.yaml
```

## 🌐 Access Nautobot

Once the playbook completes, open a browser and go to:

```
http://<instance_ip>:8000
```

Default credentials (for demo only):

- **Username:** admin
- **Password:** admin

## 🧼 Cleanup

To destroy the infrastructure:

```bash
cd terraform
terraform destroy
```

## 📝 Notes

- This setup is intended for demos and lab environments.
- Do not reuse the access keys or passwords in production.
- Extend the Ansible role to include custom plugins or data initialization as needed.

## 📂 File Structure

```
.
├── LICENSE
├── README.md
├── ansible
│   └── install_docker_and_nautobot.yaml
└── terraform
    ├── chinog12.auto.tfvars
    ├── inventory.ini.tmpl
    ├── main.tf
    └── variables.tf
```

## 🙋‍♂️ Maintainer

Jon Howe – Principal Solutions Architect  
[Myriad360](https://www.myriad360.com/)