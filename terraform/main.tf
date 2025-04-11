terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "http" "my_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_vpc" "selected" {
  count = var.vpc_name == "" ? 0 : 1
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "default" {
  count   = var.vpc_name == "" ? 1 : 0
  default = true
}

locals {
  vpc_id = var.vpc_name == "" ? data.aws_vpc.default[0].id : data.aws_vpc.selected[0].id
}

data "aws_subnet" "selected" {
  count = var.subnet_name == "" ? 0 : 1
  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
  vpc_id = local.vpc_id
}

data "aws_subnets" "default" {
  count = var.subnet_name == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  subnet_id = var.subnet_name == "" ? data.aws_subnets.default[0].ids[0] : data.aws_subnet.selected[0].id
}

resource "aws_security_group" "nautobot" {
  name        = "nautobot-sg"
  description = "Allow SSH and Nautobot Web"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "nautobot_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.nautobot.id]
  associate_public_ip_address = true

  user_data = <<-EOF
                #!/bin/bash
                apt-get update
                apt-get install -y software-properties-common
                apt-get install -y ansible git python3-pip docker.io docker-compose
                usermod -aG docker ubuntu
                EOF

  tags = {
    Name = "nautobot-demo"
  }
}

resource "null_resource" "wait_for_cloud_init" {
  depends_on = [aws_instance.nautobot_host]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 5; done",
      "echo 'cloud-init complete.'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }
}

resource "null_resource" "prepare_directories" {
  depends_on = [null_resource.wait_for_cloud_init]

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/chi-nog-12/ansible",
      "mkdir -p /home/ubuntu/chi-nog-12/docker/nautobot"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }
}

resource "null_resource" "copy_project_files" {
  depends_on = [null_resource.prepare_directories]

  provisioner "file" {
    source      = "${path.module}/../ansible/deploy_nautobot_lab.yaml"
    destination = "/home/ubuntu/chi-nog-12/ansible/deploy_nautobot_lab.yaml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/../ansible/ansible.cfg"
    destination = "/home/ubuntu/chi-nog-12/ansible/ansible.cfg"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/../docker/nautobot/docker-compose.yml"
    destination = "/home/ubuntu/chi-nog-12/docker/nautobot/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }
}

resource "null_resource" "run_remote_ansible" {
  depends_on = [null_resource.copy_project_files]

  provisioner "remote-exec" {
    inline = [
      "cd /home/ubuntu/chi-nog-12",
      "/usr/bin/ansible-playbook --version",
      "/usr/bin/docker-compose --version",
      "/usr/bin/ansible-playbook -i localhost, ansible/deploy_nautobot_lab.yaml --connection=local"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }
}

output "instance_ip" {
  value = aws_instance.nautobot_host.public_ip
}
