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
              apt update
              apt install -y software-properties-common
              add-apt-repository --yes --update ppa:ansible/ansible
              apt install -y ansible docker.io python3-pip
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "nautobot-demo"
  }
}

resource "null_resource" "copy_playbook" {
  depends_on = [aws_instance.nautobot_host]

  provisioner "file" {
    source      = "${path.module}/../ansible/install_docker_and_nautobot.yaml"
    destination = "/home/ubuntu/install_docker_and_nautobot.yaml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/../ansible/docker-compose.yml.j2"
    destination = "/home/ubuntu/docker-compose.yml.j2"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/jonhowe-chinogdemo12.pem")
      host        = aws_instance.nautobot_host.public_ip
    }
  }
}

resource "null_resource" "run_ansible" {
  depends_on = [null_resource.copy_playbook]

  provisioner "remote-exec" {
    inline = [
      "until command -v ansible-playbook >/dev/null 2>&1; do sleep 5; done",
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done",
      "sudo ansible-playbook -i localhost, /home/ubuntu/install_docker_and_nautobot.yaml --connection=local -e nautobot_allowed_hosts=${chomp(data.http.my_ip.response_body)}"
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
