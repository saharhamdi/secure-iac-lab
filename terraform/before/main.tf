# ⚠️ CODE VOLONTAIREMENT VULNÉRABLE - SUPPORT PÉDAGOGIQUE - NE JAMAIS DÉPLOYER
# Toutes les valeurs (noms, AMI, identifiants) sont fictives.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# --- S3 : bucket public, non chiffré, sans versioning ni journalisation ---
resource "aws_s3_bucket" "data" {
  bucket = "lab-data-bucket-before-example"
  acl    = "public-read"
}

# --- Security group : tout ouvert à Internet ---
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Open to the world"

  ingress {
    from_port   = 0
    to_port     = 65535
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

# --- EC2 : IMDSv1, disque non chiffré, IP publique, pas de monitoring ---
resource "aws_instance" "app" {
  ami                         = "ami-0123456789abcdef0"
  instance_type               = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  root_block_device {
    encrypted   = false
    volume_size = 20
  }
}

# --- IAM : politique *:* ---
resource "aws_iam_policy" "admin" {
  name = "admin-everything"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}
