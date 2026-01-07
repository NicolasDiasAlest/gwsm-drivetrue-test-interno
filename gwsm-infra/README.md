# GWSM Infrastructure - Terraform IaC

Infraestrutura como Código (IaC) para provisionamento do cluster Google Workspace Migrate (GWSM) no Google Cloud Platform.

## 📋 Sumário

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Recursos Provisionados](#recursos-provisionados)
- [Pré-requisitos](#pré-requisitos)
- [Configuração](#configuração)
- [Deploy](#deploy)
- [Segurança](#segurança)
- [Custos](#custos)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

Este projeto provisiona uma infraestrutura completa para o Google Workspace Migrate, incluindo:

- **Rede isolada** (VPC customizada com subnet privada)
- **Cloud NAT** (acesso à internet sem IPs públicos)
- **Firewall seguro** (deny-by-default com segmentação por tags)
- **4 VMs Windows Server 2019** (1 Master + 1 Worker + 2 Database Servers)

### Princípios de Design

✅ **Zero Trust Security** - Deny-by-default, segmentação por network tags  
✅ **Least Privilege** - Apenas Master Node tem IP público  
✅ **Cost Optimized** - NAT compartilhado, logs otimizados  
✅ **Production Ready** - Dependências explícitas, lifecycle management  

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ (IP Público)
                     ▼
            ┌────────────────┐
            │  Master Node   │ (n1-standard-4, 200GB SSD)
            │  gwsm-master   │ Tag: master-node
            └────────┬───────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
    │     VPC: gwsm-vpc (REGIONAL)   │
    │     Subnet: 10.0.1.0/24        │
    │     Private Google Access: ON   │
    │                │                │
    ├────────────────┼────────────────┤
    │                │                │
    │                ▼                │
    │         ┌──────────┐            │
    │         │ Worker 1 │ (n1-standard-16, 200GB SSD)
    │         │ worker-1 │ Tag: worker-node
    │         └────┬─────┘            │
    │              │                  │
    │    ┌─────────┴─────────┐       │
    │    │                   │       │
    │    ▼                   ▼       │
    │ ┌─────────────┐  ┌──────────────┐
    │ │ MySQL DB    │  │ CouchDB      │ (n1-standard-16, 1TB SSD)
    │ │ database-   │  │ database-    │ Tag: database-node
    │ │ mysql       │  │ couchdb      │
    │ └─────────────┘  └──────────────┘
    │         │              │         │
    └─────────┼──────────────┼─────────┘
              │              │
              └──────┬───────┘
                     ▼
             ┌──────────────┐
             │  Cloud NAT   │ (Acesso à internet)
             └──────────────┘
```

### Matriz de Comunicação

| Origem | Destino | Porta | Protocolo | Firewall Rule |
|--------|---------|-------|-----------|---------------|
| Master | Worker | 5131 | TCP | `allow-gwsm-callback` |
| Subnet | MySQL DB | 3306 | TCP | `allow-mysql-internal` |
| Subnet | CouchDB | 5984 | TCP | `allow-couchdb-internal` |
| Subnet | Todas | 445 | TCP | `allow-smb-internal` |
| IAP (35.235.240.0/20) | Todas | 3389 | TCP | `allow-iap-rdp` |
| Todas | Internet | 443 | TCP | `allow-https-egress` |
| Internet | Todas | 22 | TCP | **DENY** `deny-ssh-from-internet` |

---

## 📦 Recursos Provisionados

### Rede (11 recursos)

#### VPC e Subnet
- **`google_compute_network.gwsm_vpc`** - VPC customizada, modo REGIONAL
- **`google_compute_subnetwork.gwsm_private_subnet`** - Subnet 10.0.1.0/24 com Private Google Access

#### NAT Gateway
- **`google_compute_router.gwsm_router`** - Cloud Router (ASN 64514)
- **`google_compute_router_nat.gwsm_nat`** - NAT Gateway para VMs sem IP público

#### Firewall Rules (7 regras)
1. **`allow-mysql-internal`** - MySQL (3306/TCP) → database-node
2. **`allow-couchdb-internal`** - CouchDB (5984/TCP) → database-node
3. **`allow-gwsm-callback`** - Callback (5131/TCP) master → worker
4. **`allow-smb-internal`** - SMB (445/TCP) intracluster
5. **`allow-https-egress`** - HTTPS (443/TCP) → internet (EGRESS)
6. **`allow-iap-rdp`** - RDP (3389/TCP) via IAP
7. **`deny-ssh-from-internet`** - **BLOQUEIA** SSH (22/TCP) da internet

### Compute (5 recursos)

#### Data Source
- **`data.google_compute_image.windows_2019`** - Imagem Windows Server 2019 Datacenter

#### VMs (4 instâncias)

| VM | Machine Type | vCPUs | RAM | Disco | IP Público | Tags |
|----|--------------|-------|-----|-------|------------|------|
| **gwsm-master** | n1-standard-4 | 4 | 15 GB | 200 GB SSD | ✅ SIM | `master-node` |
| **gwsm-worker-1** | n1-standard-16 | 16 | 60 GB | 200 GB SSD | ❌ NÃO | `worker-node` |
| **gwsm-database-mysql** | n1-standard-16 | 16 | 64 GB | 1 TB SSD | ❌ NÃO | `database-node`, `mysql-server` |
| **gwsm-database-couchdb** | n1-standard-16 | 16 | 64 GB | 1 TB SSD | ❌ NÃO | `database-node`, `couchdb-server` |

**Total: 16 recursos**

---

## 🔧 Pré-requisitos

### Ferramentas Necessárias

```bash
# Terraform >= 1.0
terraform --version

# Google Cloud SDK
gcloud --version

# Autenticação GCP
gcloud auth application-default login
```

### Permissões GCP Necessárias

- `roles/compute.admin` - Criar VMs, redes e firewall
- `roles/iam.serviceAccountUser` - Usar service accounts

---

## ⚙️ Configuração

### 1. Clonar o Repositório

```bash
git clone <repository-url>
cd gwsm-infra
```

### 2. Criar `terraform.tfvars`

```hcl
# terraform.tfvars
project_id = "seu-projeto-gcp"
region     = "us-east1"
zone       = "us-east1-b"

# Opcional: customizar machine types
# master_machine_type   = "n1-standard-4"
# worker_machine_type   = "n1-standard-16"
# database_machine_type = "n1-standard-4"
```

### 3. Variáveis Disponíveis

| Variável | Tipo | Default | Descrição |
|----------|------|---------|-----------|
| `project_id` | string | **(obrigatório)** | ID do projeto GCP |
| `region` | string | `us-east1` | Região GCP |
| `zone` | string | `us-east1-b` | Zona GCP |
| `vpc_name` | string | `gwsm-vpc` | Nome da VPC |
| `subnet_cidr` | string | `10.0.1.0/24` | CIDR da subnet |
| `master_machine_type` | string | `n1-standard-4` | Machine type do Master |
| `worker_machine_type` | string | `n1-standard-16` | Machine type do Worker |
| `database_machine_type` | string | `n1-standard-16` | Machine type dos Database Nodes (PROD: 16 vCPU, 64GB RAM) |

---

## 🚀 Deploy

### 1. Inicializar Terraform

```bash
terraform init
```

### 2. Validar Configuração

```bash
# Validar sintaxe
terraform validate

# Formatar código
terraform fmt -recursive

# Revisar plano
terraform plan
```

### 3. Aplicar Infraestrutura

```bash
# Gerar plano
terraform plan -out=plan.tfplan

# Aplicar (requer confirmação)
terraform apply plan.tfplan
```

### 4. Verificar Outputs

```bash
# IP público do Master
terraform output master_node_external_ip

# IP interno do Worker
terraform output worker_node_internal_ip

# IPs internos dos Database Nodes
terraform output database_nodes_internal_ips

# Resumo completo
terraform output all_instances_summary
```

---

## 🔒 Segurança

### Princípios Implementados

#### 1. **Deny-by-Default**
- Apenas tráfego explicitamente permitido passa
- SSH (porta 22) bloqueado da internet

#### 2. **Network Segmentation**
- Tags de rede para controle granular
- Firewall rules específicas por função

#### 3. **Least Privilege**
- Apenas Master Node tem IP público
- Workers e Database usam Cloud NAT

#### 4. **IAP (Identity-Aware Proxy)**
- Acesso RDP via IAP (sem exposição direta)
- Range autorizado: `35.235.240.0/20`

### Acesso às VMs

#### Master Node (com IP público)

```bash
# Via IAP (recomendado)
gcloud compute start-iap-tunnel gwsm-master 3389 \
  --local-host-port=localhost:3389 \
  --zone=us-east1-b

# Conectar RDP em localhost:3389
```

#### Worker Node (sem IP público)

```bash
# Worker via IAP
gcloud compute start-iap-tunnel gwsm-worker-1 3389 \
  --local-host-port=localhost:3390 \
  --zone=us-east1-b
```

#### Database Nodes (sem IP público)

```bash
# MySQL Database via IAP
gcloud compute start-iap-tunnel gwsm-database-mysql 3389 \
  --local-host-port=localhost:3391 \
  --zone=us-east1-b

# CouchDB Database via IAP
gcloud compute start-iap-tunnel gwsm-database-couchdb 3389 \
  --local-host-port=localhost:3392 \
  --zone=us-east1-b
```

### Obter Senha do Windows

```bash
# Resetar senha (se necessário)
gcloud compute reset-windows-password gwsm-master \
  --zone=us-east1-b \
  --user=admin
```

---

## 💰 Custos

### Estimativa Mensal (us-east1) - PRODUÇÃO

| Recurso | Especificação | Custo Mensal (USD) |
|---------|---------------|-------------------|
| Master Node | n1-standard-4 + 200GB SSD | ~$160 |
| Worker Node | n1-standard-16 + 200GB SSD | ~$300 |
| MySQL Database | **n1-standard-16 + 1TB SSD** | **~$450** |
| CouchDB Database | **n1-standard-16 + 1TB SSD** | **~$450** |
| Cloud NAT | NAT Gateway + Egress | ~$50 |
| **TOTAL** | | **~$1,410/mês** |

> **⚠️ Nota**: Database Nodes dimensionados conforme especificações oficiais do Google GWSM para produção (2 servidores: 16 vCPU, 64GB RAM, 1TB storage cada).

### Otimizações Implementadas

✅ **NAT Compartilhado** - Um NAT para todas as VMs privadas  
✅ **Logs Otimizados** - Apenas erros (`ERRORS_ONLY`)  
✅ **Machine Types Right-Sized** - Dimensionamento adequado por workload  
✅ **Discos SSD** - Performance onde necessário  

### Reduzir Custos

```bash
# Parar VMs quando não estiverem em uso
gcloud compute instances stop gwsm-worker-1 gwsm-database-mysql gwsm-database-couchdb --zone=us-east1-b

# Iniciar VMs novamente
gcloud compute instances start gwsm-worker-1 gwsm-database-mysql gwsm-database-couchdb --zone=us-east1-b
```

---

## 🧪 Testes e Validação

### Verificar Recursos Criados

```bash
# Listar VMs
gcloud compute instances list --project=PROJECT_ID

# Listar regras de firewall
gcloud compute firewall-rules list --project=PROJECT_ID

# Verificar VPC
gcloud compute networks describe gwsm-vpc --project=PROJECT_ID
```

### Testar Conectividade

#### 1. Master → Worker (porta 5131)

```powershell
# No Master Node
Test-NetConnection -ComputerName <worker_internal_ip> -Port 5131
```

#### 2. Master/Worker → MySQL Database

```powershell
# Em qualquer VM
Test-NetConnection -ComputerName <mysql_internal_ip> -Port 3306
```

#### 3. Master/Worker → CouchDB Database

```powershell
# Em qualquer VM
Test-NetConnection -ComputerName <couchdb_internal_ip> -Port 5984
```

#### 4. SMB Intracluster (porta 445)

```powershell
# Entre quaisquer VMs
Test-NetConnection -ComputerName <target_internal_ip> -Port 445
```

#### 5. Acesso à Internet (via NAT)

```powershell
# Em Worker ou Database Nodes (sem IP público)
Test-NetConnection -ComputerName google.com -Port 443
```

---

## 🔧 Troubleshooting

### Problema: Terraform init falha

```bash
# Verificar autenticação
gcloud auth application-default login

# Verificar projeto ativo
gcloud config get-value project
```

### Problema: VMs não conseguem acessar internet

```bash
# Verificar Cloud NAT
gcloud compute routers nats describe gwsm-nat \
  --router=gwsm-router \
  --region=us-east1

# Verificar logs do NAT
gcloud logging read "resource.type=nat_gateway" --limit=50
```

### Problema: Não consigo conectar via RDP

```bash
# Verificar firewall IAP
gcloud compute firewall-rules describe allow-iap-rdp

# Testar IAP tunnel
gcloud compute start-iap-tunnel gwsm-master 3389 \
  --local-host-port=localhost:3389 \
  --zone=us-east1-b
```

### Problema: Firewall bloqueando tráfego

```bash
# Listar regras aplicadas a uma VM
gcloud compute instances describe gwsm-master \
  --zone=us-east1-b \
  --format="get(tags.items)"

# Verificar regra específica
gcloud compute firewall-rules describe allow-gwsm-callback
```

### Problema: Custo muito alto

```bash
# Analisar custos por recurso
gcloud billing accounts list
gcloud billing projects describe PROJECT_ID

# Parar VMs não utilizadas
gcloud compute instances stop gwsm-worker-1 gwsm-database-mysql gwsm-database-couchdb \
  --zone=us-east1-b
```

---

## 📁 Estrutura de Arquivos

```
gwsm-infra/
├── README.md              # Este arquivo
├── main.tf                # VPC, Subnet, NAT, Firewall
├── compute.tf             # VMs Windows Server 2019
├── variables.tf           # Variáveis de entrada
├── terraform.tfvars       # Valores das variáveis (não versionado)
├── .gitignore             # Arquivos ignorados
└── .terraform/            # Diretório Terraform (não versionado)
```

---

## 🔄 Manutenção

### Atualizar Infraestrutura

```bash
# Após modificar arquivos .tf
terraform plan
terraform apply
```

### Destruir Infraestrutura

```bash
# CUIDADO: Remove TODOS os recursos
terraform destroy
```

### Backup de Estado

```bash
# Fazer backup do estado
cp terraform.tfstate terraform.tfstate.backup

# Considerar usar remote state (GCS)
# terraform {
#   backend "gcs" {
#     bucket = "seu-bucket-terraform-state"
#     prefix = "gwsm-infra"
#   }
# }
```

---

## 📚 Referências

- [Google Workspace Migrate Documentation](https://support.google.com/workspacemigrate)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP VPC Documentation](https://cloud.google.com/vpc/docs)
- [GCP Cloud NAT Documentation](https://cloud.google.com/nat/docs)
- [Identity-Aware Proxy (IAP)](https://cloud.google.com/iap/docs)

---

## 📝 Notas Importantes

### Network Tags

As network tags são **críticas** para o funcionamento correto do firewall:

- `master-node` - Master Node (gerenciamento)
- `worker-node` - Worker Nodes (processamento)
- `database-node` - Database Node (MySQL + CouchDB)

### Startup Scripts

Cada VM possui um script PowerShell de inicialização que:
- Configura timezone (E. South America)
- Desabilita firewall Windows temporariamente
- Habilita portas específicas por tipo de node

Os scripts podem ser modificados sem recriar as VMs (lifecycle ignore_changes).

### Service Accounts

Todas as VMs usam o service account padrão do projeto com scope `cloud-platform` (acesso completo às APIs Google).

Para produção, considere criar service accounts dedicadas com permissões específicas.

---

## 🤝 Contribuindo

1. Faça fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Add nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

---

## 📄 Licença

Este projeto é proprietário e confidencial.

---

## ✅ Checklist de Deploy

- [ ] Terraform instalado e configurado
- [ ] Google Cloud SDK instalado
- [ ] Autenticação GCP configurada
- [ ] `terraform.tfvars` criado com `project_id`
- [ ] `terraform init` executado com sucesso
- [ ] `terraform validate` sem erros
- [ ] `terraform plan` revisado
- [ ] `terraform apply` executado
- [ ] Outputs verificados
- [ ] Conectividade testada (Master → Workers → Database)
- [ ] Acesso RDP via IAP funcionando
- [ ] Senhas Windows obtidas
- [ ] Documentação atualizada

---

**Última Atualização**: 2026-01-07  
**Versão**: 1.0.0  
**Autor**: Nicolas Dias  
**Status**: ✅ Production Ready
