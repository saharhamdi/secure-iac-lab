variable "region" {
  description = "Region AWS"
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Nom du bucket de donnees (les logs utilisent le suffixe -logs)"
  type        = string
  default     = "lab-data-bucket-after-example"
}

variable "vpc_id" {
  description = "Identifiant du VPC (fictif)"
  type        = string
  default     = "vpc-0123456789abcdef0"
}

variable "subnet_id" {
  description = "Identifiant du sous-reseau prive (fictif)"
  type        = string
  default     = "subnet-0123456789abcdef0"
}

variable "ami_id" {
  description = "Identifiant de l'AMI (fictif)"
  type        = string
  default     = "ami-0123456789abcdef0"
}

variable "allowed_cidr" {
  description = "CIDR autorise a joindre l'application en HTTPS (jamais 0.0.0.0/0)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = var.allowed_cidr != "0.0.0.0/0"
    error_message = "Le CIDR 0.0.0.0/0 est interdit pour l'acces entrant."
  }
}
