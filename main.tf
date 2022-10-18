terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.33.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_iam_policy" "cloud_watch_agent" {
  name = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_role" "role" {
  name                = "Minecraft"
  managed_policy_arns = [data.aws_iam_policy.cloud_watch_agent.arn]
  assume_role_policy  = file("scripts/assume_role_policy.json")
}

resource "aws_iam_instance_profile" "profile" {
  name = "Minecraft"
  role = aws_iam_role.role.name
}

data "aws_ami" "amazon_linux_2" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.*"]
  }
}

resource "aws_security_group" "minecraft" {
  name = "Minecraft"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "minecraft" {
  ami                  = data.aws_ami.amazon_linux_2.id
  iam_instance_profile = aws_iam_instance_profile.profile.name
  instance_type        = "t2.medium"
  security_groups      = [aws_security_group.minecraft.name]
  tags = {
    Name = "Minecraft"
  }
  user_data = templatefile(
    "scripts/startup.sh",
    {
      download_url      = var.download_url,
      service           = file("scripts/minecraft.service")
    }
  )
}

resource "aws_eip" "minecraft" {
  instance = aws_instance.minecraft.id
}
