provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

resource "aws_instance" "nautobot_host" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "nautobot-demo"
  }
}

output "instance_ip" {
  value = aws_instance.nautobot_host.public_ip
}