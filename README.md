# rag-qa-bot-iac

Terraform Code for infrastructure of rag-qa-bot.

## 目錄結構

```yaml
iac-demo/
├── versions.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── network.vpc.tf          # Default VPC + 子網/路由/IGW（單 AZ）
├── security_groups.tf      # EC2/RDS/Redis SG
├── ec2.app.tf              # EC2（公有子網、無公網 IP、EBS gp3 30GB、SSM）
├── rds.postgres.tf         # RDS PostgreSQL（私有子網、Free Tier）
├── redis.elasticache.tf    # ElastiCache Redis（私有子網、Free Tier）
├── secrets.rds.tf          # Secrets Manager：RDS 用
├── secrets.redis.tf        # Secrets Manager：ElastiCache 用
└── secrets.app.tf          # Secrets Manager：後端應用用
```

## Infra 架構圖 (TODO 內容待修)

```mermaid
flowchart TB
 subgraph CF["Cloudflare Zero Trust"]
    direction TB
        ACC["Access - 身份驗證"]
        PAGES["Pages - Frontend Hosting"]
        WORKER["Workers - API Proxy"]
        TUN["Tunnel - 安全連線"]
  end
 subgraph GH["GitHub"]
    direction TB
        SRC["Source Repo - Private"]
        ACT["Actions - CI CD"]
        REG["GHCR Registry - Container Images"]
  end
 subgraph PUB["Public Subnet ap-northeast-1a"]
        APP["EC2 t4g.small\nEBS gp3 30GB\nNo Public IP"]
        SSM["SSM Agent"]
  end
 subgraph PRI["Private Subnet ap-northeast-1a"]
        RDS["RDS PostgreSQL\ndb.t3.micro\n20GB"]
        REDIS["ElastiCache Redis\nt4g.micro"]
  end
 subgraph VPC["VPC"]
        IGW["Internet Gateway"]
        PUB
        PRI
  end
 subgraph AWS["AWS ap-northeast-1"]
    direction TB
        VPC
        SM["Secrets Manager\n3 secrets: RDS Redis App"]
        CW["CloudWatch\nLogs and Metrics"]
  end
 subgraph EXT["External Services"]
        OAI["OpenAI API"]
        GRAF["Grafana Cloud\nDashboard"]
  end
 subgraph COSTS["Cost Hotspots"]
        DTO["Data Transfer Out\n$0.09 per GB"]
        CWL["CloudWatch Logs\n$0.50 per GB"]
        SNAP["RDS Snapshots\n$0.095 per GB per month"]
  end
    U["User"] -- HTTPS --> ACC
    ACC --> PAGES
    PAGES -- API call --> WORKER
    WORKER -- via Tunnel --> TUN
    TUN -- Secure connection --> APP
    APP -- API call --> OAI
    APP -- Database query --> RDS
    APP -- Cache ops --> REDIS
    APP -. Fetch secrets .-> SM
    SRC --> ACT
    ACT --> REG
    ACT -- SSM SendCommand --> SSM
    SSM -. Deploy app .-> APP
    APP -- Metrics Logs --> CW
    APP -- Optional metrics --> GRAF
    IGW -- Internet egress --- PUB
    PUB -. Internal route .-> PRI
    APP -. Egress traffic .-> DTO
    APP -. Application logs .-> CWL
    RDS -. Auto backups .-> SNAP

     U:::user
     ACC:::cloudflare
     PAGES:::cloudflare
     WORKER:::cloudflare
     TUN:::cloudflare
     SRC:::github
     ACT:::github
     REG:::github
     IGW:::aws
     APP:::service
     SSM:::service
     RDS:::service
     REDIS:::service
     SM:::service
     CW:::service
     OAI:::external
     GRAF:::external
     DTO:::cost
     DTO:::cost
     CWL:::cost
     CWL:::cost
     SNAP:::cost
     SNAP:::cost
     PUB:::aws
     PRI:::aws
    classDef user fill:#e3f2fd,stroke:#1976d2,stroke-width:3px,color:#0d47a1
    classDef cloudflare fill:#fff8e1,stroke:#f57c00,stroke-width:2px,color:#e65100
    classDef github fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#1b5e20
    classDef aws fill:#ede7f6,stroke:#7b1fa2,stroke-width:2px,color:#4a148c
    classDef service fill:#fce4ec,stroke:#c2185b,stroke-width:2px,color:#880e4f
    classDef external fill:#f3e5f5,stroke:#8e24aa,stroke-width:2px,color:#4a148c
    classDef cost fill:#ffebee,stroke:#d32f2f,stroke-width:3px,color:#b71c1c
```

## 執行步驟

```bash
aws configure --profile demo
AWS Access Key ID [None]: <你的 IAM 使用者 Access Key>
AWS Secret Access Key [None]: <你的 IAM 使用者 Secret Key>
Default region name [None]: ap-northeast-1
Default output format [None]: json
```

```hcl
# 設定 profile
provider "aws" {
  region  = "ap-northeast-1"
  profile = "demo"
}

# 跑 tf
terraform init

terraform validate

terraform plan
```
