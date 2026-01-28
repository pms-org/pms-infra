# PMS Infrastructure - Docker Compose

Complete local development environment for the PMS platform using Docker Compose.

## 📁 Location

All Docker Compose files are in the `docker-compose/` directory.

## 🚀 Quick Start

```bash
cd pms-infra/docker-compose
make setup
```

Or use the interactive wizard:
```bash
cd docker-compose
./scripts/quick-start.sh
```

## 📖 Documentation

- **[Quick Reference](DOCKER-COMPOSE-QUICKSTART.md)** - One-page cheat sheet
- **[Complete Guide](docker-compose/README.md)** - Full documentation
- **[Secrets Reference](secrets.env)** - AWS Secrets Manager values

## 🏗️ Repository Structure

```
pms-infra/
├── docker-compose/              # 🆕 Local development environment
│   ├── README.md               # Complete documentation
│   ├── Makefile                # Convenient commands
│   ├── docker-compose.yml      # Main orchestration
│   ├── .env.example            # Environment variables
│   │
│   ├── infrastructure/         # PostgreSQL, Redis, Kafka, etc.
│   ├── services/              # Microservices (core, business, frontend)
│   ├── management/            # Kafka UI, PgAdmin
│   └── scripts/               # Helper scripts
│       ├── quick-start.sh
│       ├── start-pms.sh
│       ├── stop-pms.sh
│       ├── health-check.sh
│       ├── build-all.sh
│       ├── init-databases.sql
│       └── pgadmin-servers.json
│
├── k8s/                        # Kubernetes manifests
├── terraform/                  # Infrastructure as Code
├── argocd/                     # GitOps configuration
└── secrets.env                 # Secret values reference
```

## 🎯 Use Cases

### Local Development
```bash
cd docker-compose
make up-infra     # Start databases & messaging
# Run your service locally, connected to Docker infrastructure
```

### Integration Testing
```bash
cd docker-compose
make up           # Start full stack
# Run integration tests
```

### Full Stack Demo
```bash
cd docker-compose
make up-build     # Build and start everything
make frontend     # Open in browser
```

## 🔗 Related

- **Production**: Use [Kubernetes manifests](k8s/)
- **Cloud Infra**: Use [Terraform](terraform/)
- **GitOps**: Use [ArgoCD](argocd/)
- **Local Dev**: Use [Docker Compose](docker-compose/)

## 📄 License

Internal PMS Organization use only.
