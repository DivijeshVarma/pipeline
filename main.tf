terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

# Create a Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main.id # Same VPC as the security group
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  map_public_ip_on_launch = true # This ensures instances in this subnet get a public IP by default

  tags = {
    Name = "public_subnet"
  }
}

# Create a Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private_subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

# Associate the Route Table with the Public Subnet
resource "aws_route_table_association" "public_sub_assc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a Security Group
resource "aws_security_group" "open_sg" {
  name        = "open_sg"
  description = "Security group with open ingress and egress rules"
  vpc_id      = aws_vpc.main.id
}

# Allow HTTP (port 80)
resource "aws_vpc_security_group_ingress_rule" "open_ingress_rule_http" {
  security_group_id = aws_security_group.open_sg.id
  description       = "Allow HTTP traffic"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  tags = {
    Name = "tf_ig_http"
  }
}

# Allow HTTP (port 80)
resource "aws_vpc_security_group_ingress_rule" "open_ingress_rule_jen" {
  security_group_id = aws_security_group.open_sg.id
  description       = "Allow HTTP traffic"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"

  tags = {
    Name = "tf_ig_http"
  }
}


# Allow HTTPS (port 443)
resource "aws_vpc_security_group_ingress_rule" "open_ingress_rule_https" {
  security_group_id = aws_security_group.open_sg.id
  description       = "Allow HTTPS traffic"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = {
    Name = "tf_ig_https"
  }
}

# Allow SSH (port 22)
resource "aws_vpc_security_group_ingress_rule" "open_ingress_rule_ssh" {
  security_group_id = aws_security_group.open_sg.id
  description       = "Allow SSH traffic"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  tags = {
    Name = "tf_ig_ssh"
  }
}

# Allow All Egress Traffic (to anywhere)
resource "aws_vpc_security_group_egress_rule" "allow_egress_to_anywhere" {
  security_group_id = aws_security_group.open_sg.id
  description       = "Allow all egress traffic"
  cidr_ipv4         = "0.0.0.0/0"
  #from_port         = 0
  #to_port           = 0
  ip_protocol       = -1

  tags = {
    Name = "tf_egress"
  }
}

# Create an EC2 instance in the Public Subnet
resource "aws_instance" "web" {
  ami                         = "ami-0c50b6f7dc3701ddd" # Amazon Linux 2023 // ap-south-1
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.open_sg.id]
  key_name                    = "docker"
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true # Automatically associates a public IP address

  # Install Jenkins
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install docker -y
              sudo systemctl enable --now docker
              sudo groupadd docker
              sudo usermod -a -G docker ec2-user
              newgrp docker
            EOF

  # Adding 20GB of EBS storage
  root_block_device {
    volume_size           = 10    # Size in GB
    volume_type           = "gp2" # General Purpose SSD
    delete_on_termination = true  # Ensures that the volume is deleted when the instance is terminated
  }

  tags = {
    Name = "Jenkins"
  }
}

# Output the public IP and public DNS of the EC2 instance
output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
