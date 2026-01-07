# ==============================================================================
# GOOGLE WORKSPACE MIGRATE (GWSM) - COMPUTE INSTANCES
# ==============================================================================
# Provisiona 4 VMs Windows Server 2019 para cluster GWSM:
# - 1 Master Node (com IP público)
# - 2 Worker Nodes (sem IP público, usa Cloud NAT)
# - 1 Database Node (sem IP público, usa Cloud NAT)
# ==============================================================================

# ==============================================================================
# DATA SOURCE - WINDOWS SERVER 2019 IMAGE
# ==============================================================================
# Busca a imagem mais recente do Windows Server 2019 Datacenter

data "google_compute_image" "windows_2019" {
  family  = "windows-2019"
  project = "windows-cloud"
}

# ==============================================================================
# MASTER NODE
# ==============================================================================
# Master Node com IP público para gerenciar o cluster GWSM
# Comunica-se com Workers via porta 5131 (callback)

resource "google_compute_instance" "master" {
  name         = "gwsm-master"
  machine_type = var.master_machine_type
  zone         = var.zone

  tags = ["master-node"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = data.google_compute_image.windows_2019.self_link
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.gwsm_vpc.id
    subnetwork = google_compute_subnetwork.gwsm_private_subnet.id

    access_config {
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    windows-startup-script-ps1 = <<-EOT
      # Configuração inicial do Master Node
      Write-Host "Iniciando configuração do GWSM Master Node..."
      
      # Desabilitar firewall do Windows temporariamente para setup
      Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
      
      # Configurar timezone
      Set-TimeZone -Id "E. South America Standard Time"
      
      Write-Host "Configuração inicial concluída."
    EOT
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_network.gwsm_vpc,
    google_compute_subnetwork.gwsm_private_subnet,
    google_compute_router_nat.gwsm_nat
  ]

  lifecycle {
    ignore_changes = [
      metadata["windows-startup-script-ps1"]
    ]
  }
}

# ==============================================================================
# WORKER NODE 1
# ==============================================================================
# Worker Node 1 - processa migrações de dados
# Sem IP público, usa Cloud NAT para acesso à internet

resource "google_compute_instance" "worker_1" {
  name         = "gwsm-worker-1"
  machine_type = var.worker_machine_type
  zone         = var.zone

  tags = ["worker-node"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = data.google_compute_image.windows_2019.self_link
      size  = 200
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.gwsm_vpc.id
    subnetwork = google_compute_subnetwork.gwsm_private_subnet.id
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    windows-startup-script-ps1 = <<-EOT
      # Configuração inicial do Worker Node 1
      Write-Host "Iniciando configuração do GWSM Worker Node 1..."
      
      # Desabilitar firewall do Windows temporariamente para setup
      Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
      
      # Configurar timezone
      Set-TimeZone -Id "E. South America Standard Time"
      
      # Habilitar porta 5131 para callback do Master
      New-NetFirewallRule -DisplayName "GWSM Callback" -Direction Inbound -LocalPort 5131 -Protocol TCP -Action Allow
      
      Write-Host "Configuração inicial concluída."
    EOT
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_network.gwsm_vpc,
    google_compute_subnetwork.gwsm_private_subnet,
    google_compute_router_nat.gwsm_nat
  ]

  lifecycle {
    ignore_changes = [
      metadata["windows-startup-script-ps1"]
    ]
  }
}

# ==============================================================================
# WORKER NODE 2
# ==============================================================================
# Worker Node 2 - processa migrações de dados
# Sem IP público, usa Cloud NAT para acesso à internet

resource "google_compute_instance" "worker_2" {
  name         = "gwsm-worker-2"
  machine_type = var.worker_machine_type
  zone         = var.zone

  tags = ["worker-node"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = data.google_compute_image.windows_2019.self_link
      size  = 200
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.gwsm_vpc.id
    subnetwork = google_compute_subnetwork.gwsm_private_subnet.id
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    windows-startup-script-ps1 = <<-EOT
      # Configuração inicial do Worker Node 2
      Write-Host "Iniciando configuração do GWSM Worker Node 2..."
      
      # Desabilitar firewall do Windows temporariamente para setup
      Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
      
      # Configurar timezone
      Set-TimeZone -Id "E. South America Standard Time"
      
      # Habilitar porta 5131 para callback do Master
      New-NetFirewallRule -DisplayName "GWSM Callback" -Direction Inbound -LocalPort 5131 -Protocol TCP -Action Allow
      
      Write-Host "Configuração inicial concluída."
    EOT
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_network.gwsm_vpc,
    google_compute_subnetwork.gwsm_private_subnet,
    google_compute_router_nat.gwsm_nat
  ]

  lifecycle {
    ignore_changes = [
      metadata["windows-startup-script-ps1"]
    ]
  }
}

# ==============================================================================
# DATABASE NODE
# ==============================================================================
# Database Node - hospeda MySQL e CouchDB
# Sem IP público, usa Cloud NAT para acesso à internet
# Disco maior (500 GB) para armazenar dados de migração

resource "google_compute_instance" "database" {
  name         = "gwsm-database"
  machine_type = var.database_machine_type
  zone         = var.zone

  tags = ["database-node"]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = data.google_compute_image.windows_2019.self_link
      size  = 500
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.gwsm_vpc.id
    subnetwork = google_compute_subnetwork.gwsm_private_subnet.id
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    windows-startup-script-ps1 = <<-EOT
      # Configuração inicial do Database Node
      Write-Host "Iniciando configuração do GWSM Database Node..."
      
      # Desabilitar firewall do Windows temporariamente para setup
      Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
      
      # Configurar timezone
      Set-TimeZone -Id "E. South America Standard Time"
      
      # Habilitar portas MySQL (3306) e CouchDB (5984)
      New-NetFirewallRule -DisplayName "MySQL" -Direction Inbound -LocalPort 3306 -Protocol TCP -Action Allow
      New-NetFirewallRule -DisplayName "CouchDB" -Direction Inbound -LocalPort 5984 -Protocol TCP -Action Allow
      
      Write-Host "Configuração inicial concluída."
    EOT
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_network.gwsm_vpc,
    google_compute_subnetwork.gwsm_private_subnet,
    google_compute_router_nat.gwsm_nat
  ]

  lifecycle {
    ignore_changes = [
      metadata["windows-startup-script-ps1"]
    ]
  }
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "master_node_external_ip" {
  description = "External IP of Master Node"
  value       = google_compute_instance.master.network_interface[0].access_config[0].nat_ip
}

output "master_node_internal_ip" {
  description = "Internal IP of Master Node"
  value       = google_compute_instance.master.network_interface[0].network_ip
}

output "worker_nodes_internal_ips" {
  description = "Internal IPs of Worker Nodes"
  value = [
    google_compute_instance.worker_1.network_interface[0].network_ip,
    google_compute_instance.worker_2.network_interface[0].network_ip
  ]
}

output "database_node_internal_ip" {
  description = "Internal IP of Database Node"
  value       = google_compute_instance.database.network_interface[0].network_ip
}

output "all_instances_summary" {
  description = "Summary of all GWSM instances"
  value = {
    master = {
      name        = google_compute_instance.master.name
      external_ip = google_compute_instance.master.network_interface[0].access_config[0].nat_ip
      internal_ip = google_compute_instance.master.network_interface[0].network_ip
      machine_type = google_compute_instance.master.machine_type
      tags        = google_compute_instance.master.tags
    }
    worker_1 = {
      name        = google_compute_instance.worker_1.name
      internal_ip = google_compute_instance.worker_1.network_interface[0].network_ip
      machine_type = google_compute_instance.worker_1.machine_type
      tags        = google_compute_instance.worker_1.tags
    }
    worker_2 = {
      name        = google_compute_instance.worker_2.name
      internal_ip = google_compute_instance.worker_2.network_interface[0].network_ip
      machine_type = google_compute_instance.worker_2.machine_type
      tags        = google_compute_instance.worker_2.tags
    }
    database = {
      name        = google_compute_instance.database.name
      internal_ip = google_compute_instance.database.network_interface[0].network_ip
      machine_type = google_compute_instance.database.machine_type
      tags        = google_compute_instance.database.tags
    }
  }
}

# ==============================================================================
# INSTANCE REFERENCE
# ==============================================================================
# Master Node:
#   - Nome: gwsm-master
#   - IP Público: SIM (para gerenciamento)
#   - Machine Type: n1-standard-4 (4 vCPUs, 15 GB RAM)
#   - Disco: 100 GB SSD
#   - Tags: ["master-node"]
#
# Worker Node 1:
#   - Nome: gwsm-worker-1
#   - IP Público: NÃO (usa Cloud NAT)
#   - Machine Type: n1-standard-16 (16 vCPUs, 60 GB RAM)
#   - Disco: 200 GB SSD
#   - Tags: ["worker-node"]
#
# Worker Node 2:
#   - Nome: gwsm-worker-2
#   - IP Público: NÃO (usa Cloud NAT)
#   - Machine Type: n1-standard-16 (16 vCPUs, 60 GB RAM)
#   - Disco: 200 GB SSD
#   - Tags: ["worker-node"]
#
# Database Node:
#   - Nome: gwsm-database
#   - IP Público: NÃO (usa Cloud NAT)
#   - Machine Type: n1-standard-4 (4 vCPUs, 15 GB RAM)
#   - Disco: 500 GB SSD (MySQL + CouchDB)
#   - Tags: ["database-node"]
# ==============================================================================
