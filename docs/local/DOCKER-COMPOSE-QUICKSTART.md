# 🐳 Docker Compose Local Development - Quick Reference

## 🚀 One-Command Start

```bash
cd docker-compose
./scripts/quick-start.sh
```

## 📦 What's Included

### Complete PMS Stack
- **13 Microservices**: Auth, API Gateway, Trade Capture, Validation, Simulation, Analytics, Portfolio, Transactional, RTTM, Leaderboard, Ingestion, Crosscutting, Frontend
- **Infrastructure**: PostgreSQL, Redis, RabbitMQ, Kafka, Zookeeper, Schema Registry
- **Management Tools**: Kafka UI, PgAdmin

### Modular Architecture
```
docker-compose/
├── docker-compose.yml                  # Main file
├── infrastructure/                     # PostgreSQL, Redis, Kafka, etc.
├── services/                           # Core, Business, Frontend services
├── management/                         # Kafka UI, PgAdmin
└── scripts/                            # Helper scripts
```

## 🎯 Common Commands

### Using Makefile (Recommended)
```bash
cd docker-compose

make help                # Show all commands
make init               # First time setup
make up                 # Start everything
make up-infra           # Start infrastructure only
make health             # Check service health
make logs               # View all logs
make logs-kafka         # View specific service logs
make down               # Stop all services
make down-clean         # Stop and remove data
```

### Using Docker Compose Directly
```bash
# Start everything
docker compose up -d

# Start with profiles
docker compose --profile infra up -d      # Infrastructure only
docker compose --profile core up -d       # Core services
docker compose --profile full up -d       # Everything

# Stop
docker compose down

# View logs
docker compose logs -f [service-name]

# Check status
docker compose ps
```

### Using Helper Scripts
```bash
cd scripts

./quick-start.sh                 # Interactive wizard
./start-pms.sh full --build      # Build and start all
./start-pms.sh infra             # Infrastructure only
./health-check.sh                # Check health
./stop-pms.sh graceful           # Graceful shutdown
```

## 🌐 Service URLs

| Service | URL |
|---------|-----|
| **API Gateway** | http://localhost:8080 |
| **Frontend** | http://localhost:4200 |
| **Kafka UI** | http://localhost:9021 |
| **PgAdmin** | http://localhost:5050 (admin@pms.local/admin) |
| **RabbitMQ UI** | http://localhost:15672 (rabbit-user/rabbitmq) |

## 🔧 Configuration

All values hardcoded from `pms/dev/*` secrets:
- **PostgreSQL**: pms/pms/pmsdb
- **Redis**: password `redis`
- **RabbitMQ**: rabbit-user/rabbitmq
- **Kafka**: localhost:9092

## 🐛 Quick Troubleshooting

```bash
# Check what's running
docker compose ps

# View logs
docker compose logs -f [service]

# Restart service
docker compose restart [service]

# Rebuild service
docker compose up -d --build [service]

# Clean start
make down-clean
make up-build
```

## 📊 Resource Usage

- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 20GB free space
- **Startup**: 3-5 minutes (full stack)

## 📚 Full Documentation

See [docker-compose/README.md](docker-compose/README.md) for complete documentation.

## 💡 Best Practices

1. **Start infrastructure first**: `make up-infra`
2. **Wait for healthy state**: `make health`
3. **Start apps incrementally**: `make up-core` then `make up-business`
4. **Use profiles** to reduce resource usage
5. **Check logs** when services fail
6. **Clean up regularly**: `make clean`

---

**For Production Deployments**: Use Kubernetes manifests in `k8s/` directory.
