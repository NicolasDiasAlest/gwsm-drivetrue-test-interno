# ==============================================================================
# VARIÁVEIS DO PROJETO GWSM
# ==============================================================================

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

variable "master_machine_type" {
  description = "Machine type for Master Node"
  type        = string
  default     = "n1-standard-4"
}

variable "worker_machine_type" {
  description = "Machine type for Worker Nodes"
  type        = string
  default     = "n1-standard-16"
}

variable "database_machine_type" {
  description = "Machine type for Database Nodes (MySQL and CouchDB servers) - PRODUCTION: 16 vCPU, 64GB RAM"
  type        = string
  default     = "n1-standard-16"
}
