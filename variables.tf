variable "project_id" {
  description = "ID do projeto Google Cloud"
  type        = string
}

variable "region" {
  description = "Região do Google Cloud"
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "Zona do Google Cloud"
  type        = string
  default     = "us-east1-b"
}
# Variáveis de rede

variable "vpc_name" {
  description = "Nome da VPC"
  type        = string
  default     = "gwsm-vpc"
}

variable "subnet_cidr" {
  description = "CIDR da subnet privada"
  type        = string
  default     = "10.0.1.0/24"
}
