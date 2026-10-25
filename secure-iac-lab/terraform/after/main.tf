terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# KMS : clé de chiffrement partagée (rotation activée)
# ---------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "Cle de chiffrement du lab secure-iac"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AdministrationDuCompte"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

# ---------------------------------------------------------------------------
# S3 : privé, chiffré KMS, versionné, journalisé, cycle de vie
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV_AWS_144: Replication inter-region hors perimetre du lab
  # checkov:skip=CKV2_AWS_62: Notifications d'evenements hors perimetre du lab
  # checkov:skip=CKV_AWS_18: Bucket de journalisation, pas de journalisation en cascade
  bucket = "${var.bucket_name}-logs"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expiration"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket" "data" {
  # checkov:skip=CKV_AWS_144: Replication inter-region hors perimetre du lab
  # checkov:skip=CKV2_AWS_62: Notifications d'evenements hors perimetre du lab
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

resource "aws_s3_bucket_logging" "data" {
  bucket        = aws_s3_bucket.data.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/"
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "nettoyage"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Réseau : security group restreint (HTTPS depuis un CIDR autorisé uniquement)
# ---------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "HTTPS entrant depuis un CIDR autorise, sortie HTTPS uniquement"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS depuis le CIDR autorise"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "HTTPS sortant"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# EC2 : IMDSv2, disque chiffré, pas d'IP publique, monitoring détaillé
# ---------------------------------------------------------------------------
resource "aws_iam_role" "app" {
  name = "app-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "app-instance-profile"
  role = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.app.name
  monitoring                  = true
  ebs_optimized               = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 obligatoire
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    kms_key_id  = aws_kms_key.main.arn
    volume_size = 20
  }
}

# ---------------------------------------------------------------------------
# IAM : moindre privilège (lecture seule sur le bucket de données)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "app_read" {
  statement {
    sid       = "LectureBucketDonnees"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
  }

  statement {
    sid       = "DechiffrementKMS"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_policy" "app_read" {
  name   = "app-read-data-bucket"
  policy = data.aws_iam_policy_document.app_read.json
}

resource "aws_iam_role_policy_attachment" "app_read" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app_read.arn
}
