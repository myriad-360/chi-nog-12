provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "nautobot_host" {
  ami                         = "ami-0c02fb55956c7d316" # Ubuntu 22.04 LTS (update as needed)
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y python3-pip"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "nautobot-demo"
  }
}

output "instance_ip" {
  value = aws_instance.nautobot_host.public_ip
}