```markdown
# CHI-NOG 12: Network Automation Demo - From Zero to Hero in 30 Minutes

This repo demonstrates a modern network automation pipeline using **Terraform**, **Ansible**, **Docker**, and **Nautobot** — all deployed automatically into AWS for rapid iteration and demo readiness.

## 🔧 What It Does

- Provisions an EC2 instance using Terraform
- Dynamically uses your public IP for:
  - SSH access
  - Nautobot's `ALLOWED_HOSTS` setting
- Installs Docker and Ansible via cloud-init and Ansible
- Deploys Nautobot using Docker Compose
  - With Postgres and Redis dependencies
  - Port 8000 exposed via AWS Security Group
- Runs a templated Ansible playbook that:
  - Copies in a rendered `docker-compose.yml`
  - Boots up the full Nautobot stack
  - Validates your IP automatically

## 🧰 Tech Stack

- **Terraform**: Infra provisioning (EC2, SG, subnet selection)
- **Ansible**: Instance configuration and app orchestration
- **Docker Compose**: Multi-container deployment (Nautobot, Redis, Postgres)
- **AWS**: Hosted environment using defaults or custom VPC/subnet

## 🚀 Usage

### 1. Configure your variables

In `terraform/chinog12.auto.tfvars`:

```hcl
aws_access_key    = "YOUR_KEY"
aws_secret_key    = "YOUR_SECRET"
key_name          = "jonhowe-chinogdemo12"
aws_region        = "us-east-2"
instance_type     = "t3.medium"
vpc_name          = ""  # leave empty to use default VPC
subnet_name       = ""  # leave empty to use first subnet in selected VPC
```

### 2. Deploy with Terraform

```bash
cd terraform
terraform init
terraform apply
```

Your public IP is dynamically used to:
- Allow SSH (port 22)
- Allow HTTP access to Nautobot (port 8000)
- Set Nautobot's `ALLOWED_HOSTS` correctly

### 3. Access Nautobot

After deployment:

```bash
terraform output instance_ip
```

Visit in your browser:

```
http://<instance_ip>:8000
```

Default credentials:
- **Username**: `admin`
- **Password**: `admin`

## 📂 File Structure

```
.
├── ansible
│   ├── docker-compose.yml.j2
│   └── install_docker_and_nautobot.yaml
├── terraform
│   ├── chinog12.auto.tfvars
│   ├── main.tf
│   ├── variables.tf
│   └── ...
└── README.md
```

## 🧠 Tips

- To reapply updated compose or playbook logic:

```bash
terraform taint null_resource.copy_playbook
terraform taint null_resource.run_ansible
terraform apply
```

- Use `docker ps` and `docker logs` on the instance to debug
- Use `curl -I http://localhost:8000` on the instance to verify service status

---

This is a complete demo framework for showcasing infrastructure-as-code and DevOps principles applied to network automation.

Happy automating!
```