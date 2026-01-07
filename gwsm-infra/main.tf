# ==============================================================================
# GOOGLE WORKSPACE MIGRATE (GWSM) - INFRAESTRUTURA DE REDE E SEGURANÇA
# ==============================================================================
# Terraform configuration para criar VPC, Subnet, NAT e Firewall Rules
# seguindo princípios de segurança Zero Trust e segmentação por network tags
# ==============================================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ==============================================================================
# VPC NETWORK
# ==============================================================================
# VPC customizada com modo REGIONAL para otimizar custos e latência
# Auto-create desabilitado para controle total sobre subnets

resource "google_compute_network" "gwsm_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC dedicada para infraestrutura Google Workspace Migrate"
}

# ==============================================================================
# SUBNET PRIVADA
# ==============================================================================
# Subnet privada com Private Google Access habilitado
# Permite VMs sem IP público acessarem APIs Google (Cloud Storage, etc)

resource "google_compute_subnetwork" "gwsm_private_subnet" {
  name          = "${var.vpc_name}-private-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.gwsm_vpc.id
  
  # CRÍTICO: Habilita acesso a APIs Google sem IP público
  private_ip_google_access = true
  
  description = "Subnet privada para Master, Workers e Database Node"
}

# ==============================================================================
# CLOUD ROUTER
# ==============================================================================
# Router necessário para Cloud NAT funcionar
# ASN privado para BGP (64512-65534 são reservados para uso privado)

resource "google_compute_router" "gwsm_router" {
  name    = "gwsm-router"
  region  = var.region
  network = google_compute_network.gwsm_vpc.id
  
  bgp {
    asn = 64514
  }
  
  description = "Cloud Router para NAT Gateway"
}

# ==============================================================================
# CLOUD NAT
# ==============================================================================
# NAT Gateway para permitir Workers e Database Node acessarem internet
# sem necessidade de IP público (segurança + economia)

resource "google_compute_router_nat" "gwsm_nat" {
  name   = "gwsm-nat"
  router = google_compute_router.gwsm_router.name
  region = var.region
  
  # Aloca IPs automaticamente para NAT
  nat_ip_allocate_option = "AUTO_ONLY"
  
  # Aplica NAT apenas para VMs SEM IP público
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.gwsm_private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  
  # Logging apenas para erros (reduz custos)
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ==============================================================================
# FIREWALL RULES - SEGURANÇA POR NETWORK TAGS
# ==============================================================================

# ------------------------------------------------------------------------------
# REGRA 1: MySQL Database (3306/TCP)
# ------------------------------------------------------------------------------
# Permite acesso ao MySQL apenas de dentro da subnet
# Target: database-node tag

resource "google_compute_firewall" "allow_mysql_internal" {
  name    = "allow-mysql-internal"
  network = google_compute_network.gwsm_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
  
  source_ranges = [var.subnet_cidr]
  target_tags   = ["database-node"]
  
  description = "Permite acesso MySQL ao Database Node apenas da subnet interna"
  priority    = 1000
}

# ------------------------------------------------------------------------------
# REGRA 2: CouchDB (5984/TCP)
# ------------------------------------------------------------------------------
# Permite acesso ao CouchDB apenas de dentro da subnet
# Target: database-node tag

resource "google_compute_firewall" "allow_couchdb_internal" {
  name    = "allow-couchdb-internal"
  network = google_compute_network.gwsm_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["5984"]
  }
  
  source_ranges = [var.subnet_cidr]
  target_tags   = ["database-node"]
  
  description = "Permite acesso CouchDB ao Database Node apenas da subnet interna"
  priority    = 1000
}

# ------------------------------------------------------------------------------
# REGRA 3: Callback GWSM (5131/TCP)
# ------------------------------------------------------------------------------
# Permite Master Node chamar Workers via porta 5131
# Source: master-node tag | Target: worker-node tag

resource "google_compute_firewall" "allow_gwsm_callback" {
  name    = "allow-gwsm-callback"
  network = google_compute_network.gwsm_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["5131"]
  }
  
  source_tags = ["master-node"]
  target_tags = ["worker-node"]
  
  description = "Permite Master Node comunicar com Workers via porta 5131"
  priority    = 1000
}

# ------------------------------------------------------------------------------
# REGRA 4: HTTPS Egress (443/TCP)
# ------------------------------------------------------------------------------
# Permite todas as VMs acessarem internet via HTTPS
# Necessário para downloads, updates e APIs externas

resource "google_compute_firewall" "allow_https_egress" {
  name      = "allow-https-egress"
  network   = google_compute_network.gwsm_vpc.name
  direction = "EGRESS"
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  destination_ranges = ["0.0.0.0/0"]
  
  description = "Permite saída HTTPS para todas as VMs (APIs, updates, downloads)"
  priority    = 1000
}

# ------------------------------------------------------------------------------
# REGRA 5: IAP for RDP (3389/TCP)
# ------------------------------------------------------------------------------
# Permite acesso RDP via Identity-Aware Proxy (IAP)
# Range oficial do IAP: 35.235.240.0/20

resource "google_compute_firewall" "allow_iap_rdp" {
  name    = "allow-iap-rdp"
  network = google_compute_network.gwsm_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  
  source_ranges = ["35.235.240.0/20"]
  
  description = "Permite acesso RDP via Identity-Aware Proxy (IAP)"
  priority    = 1000
}

# ------------------------------------------------------------------------------
# REGRA 6: DENY SSH from Internet (EXPLÍCITA)
# ------------------------------------------------------------------------------
# BLOQUEIA SSH (porta 22) vindo da internet
# Prioridade alta (1000) para garantir que seja aplicada antes de regras permissivas

resource "google_compute_firewall" "deny_ssh_from_internet" {
  name     = "deny-ssh-from-internet"
  network  = google_compute_network.gwsm_vpc.name
  priority = 1000
  
  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  
  description = "BLOQUEIA SSH da internet - usar IAP para acesso administrativo"
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "vpc_id" {
  description = "ID da VPC criada"
  value       = google_compute_network.gwsm_vpc.id
}

output "vpc_name" {
  description = "Nome da VPC criada"
  value       = google_compute_network.gwsm_vpc.name
}

output "subnet_id" {
  description = "ID da subnet privada"
  value       = google_compute_subnetwork.gwsm_private_subnet.id
}

output "subnet_name" {
  description = "Nome da subnet privada"
  value       = google_compute_subnetwork.gwsm_private_subnet.name
}

output "subnet_cidr" {
  description = "CIDR da subnet privada"
  value       = google_compute_subnetwork.gwsm_private_subnet.ip_cidr_range
}

output "nat_ip_addresses" {
  description = "Endereços IP do NAT Gateway (para whitelist externa se necessário)"
  value       = google_compute_router_nat.gwsm_nat.nat_ips
}

output "router_name" {
  description = "Nome do Cloud Router"
  value       = google_compute_router.gwsm_router.name
}

# ==============================================================================
# NETWORK TAGS REFERENCE (para uso nas VMs)
# ==============================================================================
# Ao criar as VMs, usar as seguintes tags:
#
# Master Node:
#   - tags = ["master-node"]
#   - Terá IP público
#   - Pode chamar Workers via porta 5131
#
# Worker Nodes:
#   - tags = ["worker-node"]
#   - SEM IP público (usa NAT)
#   - Recebe callbacks do Master na porta 5131
#
# Database Node:
#   - tags = ["database-node"]
#   - SEM IP público (usa NAT)
#   - Expõe MySQL (3306) e CouchDB (5984) apenas internamente
# ==============================================================================
