# Nautobot Demo Deployment (AWS + Terraform + Ansible)

This repository provisions an AWS EC2 instance using Terraform and installs Nautobot via Docker using Ansible. It's designed as a fast, demo-friendly environment for network automation labs and workshops.

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

## 🚀 Usage

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/nautobot-demo.git
cd nautobot-demo
```

### 2. Initialize and Apply Terraform

```bash
terraform init
terraform apply
```

> **Note:** This will output the EC2 instance's public IP. Save it.

### 3. Create Ansible Inventory

Create a file named `inventory.ini`:

```ini
[nautobot]
<instance_ip> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

Replace `<instance_ip>` with the IP output from Terraform.

### 4. Run the Ansible Playbook

```bash
ansible-playbook -i inventory.ini install_docker_and_nautobot.yaml
```

## 🌐 Access Nautobot

Once the playbook completes, access Nautobot at:

```
http://<instance_ip>:8000
```

Default credentials (for demo only):

- **Username:** admin
- **Password:** admin

## 🧼 Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

## 📝 Notes

- This setup is intended for demo and development use only.
- For production use, secure credentials, configure volumes, and enable TLS.
- The playbook can be extended to include custom Nautobot plugins, data imports, or integrations.

## 📂 File Structure

```
.
├── main.tf                          # Terraform config for EC2
├── install_docker_and_nautobot.yaml # Ansible playbook to install Docker & Nautobot
├── inventory.ini.tmpl              # Template inventory (to be filled with TF output)
├── README.md
```

## 🙋‍♂️ Maintainer

Jon Howe – Principal Solutions Architect - jhowe@myriad360.com
[Myriad360](https://www.myriad360.com/)