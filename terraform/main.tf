# Terraform block specifying required providers and their versions.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws" # AWS provider source.
      version = "~> 5.0"        # AWS provider version constraint.
    }
    http = {
      source  = "hashicorp/http" # HTTP provider source.
      version = "~> 3.0"         # HTTP provider version constraint.
    }
  }
}

# AWS provider configuration with region, access key, and secret key variables.
provider "aws" {
  region     = var.aws_region     # AWS region to deploy resources.
  access_key = var.aws_access_key # AWS access key for authentication.
  secret_key = var.aws_secret_key # AWS secret key for authentication.
}

# Data source to fetch the public IP of the machine running Terraform.
data "http" "my_ip" {
  url = "http://ipv4.icanhazip.com" # URL to fetch the public IP.
}

# Data source to fetch a specific VPC by name if provided.
data "aws_vpc" "selected" {
  count = var.vpc_name == "" ? 0 : 1 # Only fetch if vpc_name is provided.
  filter {
    name   = "tag:Name"       # Filter by VPC name tag.
    values = [var.vpc_name]   # Value of the VPC name to filter.
  }
  filter {
    name   = "state"          # Filter by VPC state.
    values = ["available"]    # Only fetch available VPCs.
  }
}

# Data source to fetch the default VPC if no specific VPC name is provided.
data "aws_vpc" "default" {
  count   = var.vpc_name == "" ? 1 : 0 # Only fetch if no vpc_name is provided.
  default = true                       # Fetch the default VPC.
}

# Local variable to determine the VPC ID to use based on the provided or default VPC.
locals {
  vpc_id = var.vpc_name == "" ? data.aws_vpc.default[0].id : data.aws_vpc.selected[0].id
}

# Data source to fetch a specific subnet by name if provided.
data "aws_subnet" "selected" {
  count = var.subnet_name == "" ? 0 : 1 # Only fetch if subnet_name is provided.
  filter {
    name   = "tag:Name"       # Filter by subnet name tag.
    values = [var.subnet_name] # Value of the subnet name to filter.
  }
  vpc_id = local.vpc_id       # VPC ID to filter subnets within.
}

# Data source to fetch all subnets in the VPC if no specific subnet name is provided.
data "aws_subnets" "default" {
  count = var.subnet_name == "" ? 1 : 0 # Only fetch if no subnet_name is provided.
  filter {
    name   = "vpc-id"         # Filter by VPC ID.
    values = [local.vpc_id]   # VPC ID to filter subnets within.
  }
  filter {
    name   = "state"          # Filter by subnet state.
    values = ["available"]    # Only fetch available subnets.
  }
}

# Local variable to determine the subnet ID to use based on the provided or default subnet.
locals {
  subnet_id = var.subnet_name == "" ? data.aws_subnets.default[0].ids[0] : data.aws_subnet.selected[0].id
}

# Security group resource to allow SSH and Nautobot web access.
resource "aws_security_group" "nautobot" {
  name        = "nautobot-sg"          # Name of the security group.
  description = "Allow SSH and Nautobot Web" # Description of the security group.
  vpc_id      = local.vpc_id           # VPC ID to associate the security group with.

  dynamic "ingress" {
    for_each = [
      "20.205.243.166/32",
      "185.199.108.0/22",
      "140.82.112.0/20",
      "143.55.64.0/20"
    ]
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Allow SSH from GitHub Actions"
    }
  }

  ingress {
    from_port   = 8000                 # Allow Nautobot web traffic.
    to_port     = 8000                 # Allow Nautobot web traffic.
    protocol    = "tcp"                # Protocol for Nautobot web.
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"] # Restrict to the public IP of the user.
  }

  egress {
    from_port   = 0                    # Allow all outbound traffic.
    to_port     = 0                    # Allow all outbound traffic.
    protocol    = "-1"                 # Protocol for all traffic.
    cidr_blocks = ["0.0.0.0/0"]        # Allow outbound to all IPs.
  }
}

# Data source to fetch the latest Ubuntu AMI for the instance.
data "aws_ami" "ubuntu" {
  most_recent = true                   # Fetch the most recent AMI.
  owners      = ["099720109477"]       # Canonical's AWS account ID.
  filter {
    name   = "name"                    # Filter by AMI name.
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] # Ubuntu 22.04 AMI pattern.
  }
  filter {
    name   = "virtualization-type"     # Filter by virtualization type.
    values = ["hvm"]                   # Only HVM AMIs.
  }
}

# EC2 instance resource to host Nautobot.
resource "aws_instance" "nautobot_host" {
  ami                         = data.aws_ami.ubuntu.id # AMI ID for the instance.
  instance_type               = var.instance_type      # Instance type (e.g., t2.micro).
  key_name                    = var.key_name           # Key pair name for SSH access.
  subnet_id                   = local.subnet_id        # Subnet ID for the instance.
  vpc_security_group_ids      = [aws_security_group.nautobot.id] # Security group for the instance.
  associate_public_ip_address = true                   # Assign a public IP to the instance.

  # User data script to install required software and configure Docker.
  user_data = <<-EOF
                #!/bin/bash
                apt-get update
                apt-get install -y software-properties-common
                apt-get install -y ansible git python3-pip docker.io docker-compose
                usermod -aG docker ubuntu
                EOF 

  tags = {
    Name = "chinog-nautobot-demo"             # Tag for the instance.
  }
}

# Null resource to wait for cloud-init to complete on the instance.
resource "null_resource" "wait_for_cloud_init" {
  depends_on = [aws_instance.nautobot_host] # Wait for the instance to be created.

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'", # Log message.
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 5; done", # Wait for cloud-init.
      "echo 'cloud-init complete.'" # Log message.
    ]

    connection {
      type        = "ssh" # SSH connection to the instance.
      user        = "ubuntu" # SSH user.
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem") # Private key for SSH.
      host        = aws_instance.nautobot_host.public_ip # Public IP of the instance.
    }
  }
}

# Null resource to prepare directories on the instance.
resource "null_resource" "prepare_directories" {
  depends_on = [null_resource.wait_for_cloud_init] # Wait for cloud-init to complete.

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/chi-nog-12/ansible", # Create Ansible directory.
      "mkdir -p /home/ubuntu/chi-nog-12/docker/nautobot" # Create Docker directory.
    ]

    connection {
      type        = "ssh" # SSH connection to the instance.
      user        = "ubuntu" # SSH user.
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem") # Private key for SSH.
      host        = aws_instance.nautobot_host.public_ip # Public IP of the instance.
    }
  }
}

# Null resource to copy project files to the instance.
resource "null_resource" "copy_project_files" {
  depends_on = [null_resource.prepare_directories] # Wait for directories to be prepared.

  provisioner "file" {
    source      = "${path.module}/../ansible/deploy_nautobot_lab.yaml" # Local Ansible playbook.
    destination = "/home/ubuntu/chi-nog-12/ansible/deploy_nautobot_lab.yaml" # Remote destination.

    connection {
      type        = "ssh" # SSH connection to the instance.
      user        = "ubuntu" # SSH user.
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem") # Private key for SSH.
      host        = aws_instance.nautobot_host.public_ip # Public IP of the instance.
    }
  }

  provisioner "file" {
    source      = "${path.module}/../ansible/ansible.cfg" # Local Ansible configuration.
    destination = "/home/ubuntu/chi-nog-12/ansible/ansible.cfg" # Remote destination.

    connection {
      type        = "ssh" # SSH connection to the instance.
      user        = "ubuntu" # SSH user.
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem") # Private key for SSH.
      host        = aws_instance.nautobot_host.public_ip # Public IP of the instance.
    }
  }

  provisioner "file" {
    source      = "${path.module}/../docker/nautobot/docker-compose.yml" # Local Docker Compose file.
    destination = "/home/ubuntu/chi-nog-12/docker/nautobot/docker-compose.yml" # Remote destination.

    connection {
      type        = "ssh" # SSH connection to the instance.
      user        = "ubuntu" # SSH user.
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem") # Private key for SSH.
      host        = aws_instance.nautobot_host.public_ip # Public IP of the instance.
    }
  }

  provisioner "file" {
    source      = "${path.module}/../ansible/nautobot-superuser-vars.yml"
    destination = "/home/ubuntu/chi-nog-12/ansible/nautobot-superuser-vars.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }
}

# Null resource to run the Ansible playbook on the instance.
resource "null_resource" "run_remote_ansible" {
  depends_on = [null_resource.copy_project_files] # Wait for project files to be copied.

  provisioner "remote-exec" {
    inline = [
      "cd /home/ubuntu/chi-nog-12", # Change to project directory.
      # "/usr/bin/ansible-playbook --version", # Check Ansible version.
      # "/usr/bin/docker-compose --version", # Check Docker Compose version.
      "/usr/bin/ansible-playbook -i localhost, ansible/deploy_nautobot_lab.yaml --connection=local" # Run Ansible playbook.
    ]

    connection {
      type        = "ssh" # SSH connection to the instance.
      user        = "ubuntu" # SSH user.
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem") # Private key for SSH.
      host        = aws_instance.nautobot_host.public_ip # Public IP of the instance.
    }
  }
}

# Security group for the web server
resource "aws_security_group" "web" {
  name        = "webserver-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = [
      "20.205.243.166/32",
      "185.199.108.0/22",
      "140.82.112.0/20",
      "143.55.64.0/20"
    ]
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Allow SSH from GitHub Actions"
    }
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance acting as a simple web server
resource "aws_instance" "web_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.web_instance_type
  key_name                    = var.key_name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOF
                #!/bin/bash
                apt-get update
                apt-get install -y nginx
                systemctl enable nginx
                systemctl start nginx
                echo "<h1>Web Server Up and Running</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "chinog-web-server"
  }
}

# Output the IP address of the web server
output "web_server_ip" {
  value = aws_instance.web_host.public_ip
  description = "Public IP of the web server"
}

# Output to display the public IP of the Nautobot host instance.
output "instance_ip" {
  value = aws_instance.nautobot_host.public_ip # Public IP of the instance.
}