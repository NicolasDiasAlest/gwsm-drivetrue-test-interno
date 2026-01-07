# VPC Principal
resource "google_compute_network" "gwsm_vpc" {
  name                    = "gwsm-vpc"
  auto_create_subnetworks = false
  description             = "VPC para infraestrutura GWSM"
}

# Subnet Privada
resource "google_compute_subnetwork" "gwsm_private" {
  name          = "gwsm-private"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.gwsm_vpc.id
  description   = "Subnet privada para VMs GWSM"
}

# Cloud Router (necessário para Cloud NAT)
resource "google_compute_router" "gwsm_router" {
  name    = "gwsm-router"
  region  = var.region
  network = google_compute_network.gwsm_vpc.id

  bgp {
    asn = 64514
  }
}

# Cloud NAT (permite VMs sem IP público acessarem internet)
resource "google_compute_router_nat" "gwsm_nat" {
  name                               = "gwsm-nat"
  router                             = google_compute_router.gwsm_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rule: Permitir comunicação interna
resource "google_compute_firewall" "allow_internal" {
  name    = "gwsm-allow-internal"
  network = google_compute_network.gwsm_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16"]
  description   = "Permite toda comunicação interna na VPC"
}

# Firewall Rule: Permitir RDP via IAP
resource "google_compute_firewall" "allow_iap_rdp" {
  name    = "gwsm-allow-iap-rdp"
  network = google_compute_network.gwsm_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["35.235.240.0/20"]
  description   = "Permite acesso RDP via Identity-Aware Proxy"
}

# Firewall Rule: Permitir MySQL
resource "google_compute_firewall" "allow_mysql" {
  name    = "gwsm-allow-mysql"
  network = google_compute_network.gwsm_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["database"]
  description   = "Permite acesso MySQL ao Database Node"
}

# Firewall Rule: Permitir CouchDB
resource "google_compute_firewall" "allow_couchdb" {
  name    = "gwsm-allow-couchdb"
  network = google_compute_network.gwsm_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5984"]
  }

  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["database"]
  description   = "Permite acesso CouchDB ao Database Node"
}

# Firewall Rule: Permitir callback GWSM
resource "google_compute_firewall" "allow_callback" {
  name    = "gwsm-allow-callback"
  network = google_compute_network.gwsm_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5131"]
  }

  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["worker"]
  description   = "Permite comunicação Master -> Workers (porta 5131)"
}

# Firewall Rule: Bloquear todo tráfego de entrada externo (deny-by-default)
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "gwsm-deny-all-ingress"
  network  = google_compute_network.gwsm_vpc.name
  priority = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Bloqueia todo tráfego de entrada externo (deny-by-default)"
}