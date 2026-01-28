# PMS Docker Compose - Local Development Environment

Complete Docker Compose setup for running the entire Portfolio Management System (PMS) locally with all microservices and infrastructure.

## 📋 Overview

This modular Docker Compose setup provides a complete local development environment with:

- **Infrastructure Services**: PostgreSQL, Redis, RabbitMQ, Kafka, Zookeeper, Schema Registry
- **Core Services**: API Gateway, Auth, Portfolio, Transactional
- **Business Services**: Trade Capture, Validation, Simulation, Analytics, RTTM, Leaderboard, Ingestion, Crosscutting
- **Frontend**: Angular application
- **Management Tools**: Kafka UI, PgAdmin

All configurations use hardcoded values from AWS Secrets Manager (`pms/dev/*`) matching the Kubernetes deployment.

## 🏗️ Architecture

### Modular Structure

```
docker-compose/
├── docker-compose.yml                    # Main orchestration file
├── .env.example                          # Environment variables template
│
├── infrastructure/                       # Infrastructure services
│   └── docker-compose.infra.yml         # PostgreSQL, Redis, Kafka, RabbitMQ, etc.
│
├── services/                             # Application services
│   ├── docker-compose.core.yml          # Auth, API Gateway, Portfolio, Transactional
│   ├── docker-compose.business.yml      # Trade Capture, Validation, Simulation, etc.
│   └── docker-compose.frontend.yml      # Angular frontend
│
├── management/                           # Management tools
│   └── docker-compose.management.yml    # Kafka UI, PgAdmin
│
└── scripts/                              # Helper scripts and initialization
    ├── start-pms.sh                     # Startup script
    ├── stop-pms.sh                      # Shutdown script
    ├── health-check.sh                  # Health monitoring
    ├── build-all.sh                     # Build all images
    ├── quick-start.sh                   # Interactive setup wizard
    ├── init-databases.sql               # PostgreSQL initialization
    └── pgadmin-servers.json             # PgAdmin configuration
```

### Network Architecture

- **Network**: `pms-network` (172.20.0.0/16)
- **Infrastructure**: 172.20.0.10-19
- **Core Services**: 172.20.0.20-26
- **Business Services**: 172.20.0.27-31
- **Frontend**: 172.20.0.40
- **Management**: 172.20.0.50-51

## 🚀 Quick Start

### Prerequisites

- Docker Desktop 4.0+ with **8GB RAM** allocated
- Docker Compose v2.20+
- 20GB free disk space
- Git (for cloning service repositories)

### One-Command Start

```bash
cd docker-compose
./scripts/quick-start.sh
```

The interactive wizard will guide you through the setup process.

### Manual Start

```bash
# Navigate to docker-compose directory
cd docker-compose

# Start everything
docker compose up -d

# Or start with building
docker compose up -d --build

# Or use profiles for selective startup
docker compose --profile infra up -d      # Infrastructure only
docker compose --profile core up -d       # Core services only
docker compose --profile business up -d   # Business services only
docker compose --profile full up -d       # Everything
```

### Using Helper Scripts

```bash
cd scripts

# Interactive wizard
./quick-start.sh

# Start with scripts (from docker-compose directory)
./scripts/start-pms.sh full --build      # Build and start everything
./scripts/start-pms.sh infra             # Start infrastructure only
./scripts/start-pms.sh minimal           # Start minimal stack

# Check health
./scripts/health-check.sh

# Stop services
./scripts/stop-pms.sh graceful           # Graceful shutdown
./scripts/stop-pms.sh clean              # Remove volumes too
```

## 📦 Profiles

Docker Compose profiles allow you to start specific groups of services:

| Profile | Services | Usage |
|---------|----------|-------|
| `infra` | PostgreSQL, Redis, RabbitMQ, Kafka, Zookeeper, Schema Registry | Infrastructure only |
| `core` | Auth, API Gateway, Portfolio, Transactional | Core business logic |
| `business` | Trade Capture, Validation, Simulation, Analytics, RTTM, etc. | Business services |
| `frontend` | Angular application | Frontend UI |
| `mgmt` | Kafka UI, PgAdmin | Management tools |
| `full` | All services | Complete stack |
| `apps` | Core + Business services | All applications |

### Examples

```bash
# Start only infrastructure
docker compose --profile infra up -d

# Start infrastructure + core services
docker compose --profile infra --profile core up -d

# Start everything
docker compose --profile full up -d
# OR simply
docker compose up -d
```

## 🌐 Service Endpoints

### Application Services

| Service | Port | URL | Health Check |
|---------|------|-----|--------------|
| API Gateway | 8080 | http://localhost:8080 | /actuator/health |
| Auth | 8082 | http://localhost:8082 | /actuator/health |
| Trade Capture | 8083 | http://localhost:8083 | /actuator/health |
| Transactional | 8084 | http://localhost:8084 | /actuator/health |
| Validation | 8085 | http://localhost:8085 | /actuator/health |
| Analytics | 8086 | http://localhost:8086 | /actuator/health |
| Crosscutting | 8087 | http://localhost:8087 | /actuator/health |
| RTTM | 8088 | http://localhost:8088 | /actuator/health |
| Leaderboard | 8089 | http://localhost:8089 | /actuator/health |
| Simulation | 8090 | http://localhost:8090 | /actuator/health |
| Ingestion | 8091 | http://localhost:8091 | /actuator/health |
| Portfolio | 8095 | http://localhost:8095 | /actuator/health |
| Frontend | 4200 | http://localhost:4200 | http://localhost:4200 |

### Infrastructure Services

| Service | Port | Credentials |
|---------|------|-------------|
| PostgreSQL | 5432 | `pms` / `pms` / `pmsdb` |
| Redis | 6379 | password: `redis` |
| RabbitMQ | 5672, 15672 | `rabbit-user` / `rabbitmq` |
| RabbitMQ UI | 15672 | http://localhost:15672 |
| Kafka | 9092 | No auth |
| Schema Registry | 8081 | http://localhost:8081 |

### Management Tools

| Tool | Port | URL | Credentials |
|------|------|-----|-------------|
| Kafka UI | 9021 | http://localhost:9021 | No auth |
| PgAdmin | 5050 | http://localhost:5050 | `admin@pms.local` / `admin` |

## 🔧 Configuration

### Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

All values are pre-configured from AWS Secrets Manager (`pms/dev/*`):

- **Database**: pms/pms/pmsdb
- **Redis**: password `redis`
- **RabbitMQ**: rabbit-user/rabbitmq
- **JWT Secrets**: Hardcoded for development

### Customization

Edit individual compose files to customize:

- Resource limits (CPU, memory)
- Port mappings
- Environment variables
- Health check intervals
- Network configuration

## 📊 Data Persistence

Volumes are created for persistent data:

```bash
# List volumes
docker volume ls | grep pms

# Inspect a volume
docker volume inspect pms-postgres-data

# Remove all volumes (WARNING: Deletes all data)
docker volume rm pms-postgres-data pms-redis-data pms-kafka-data pms-rabbitmq-data pms-zookeeper-data pms-zookeeper-logs
```

## 🔍 Monitoring & Debugging

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f trade-capture

# Multiple services
docker compose logs -f postgres kafka redis

# Last 100 lines
docker compose logs --tail=100 trade-capture
```

### Check Service Status

```bash
# Using Docker Compose
docker compose ps

# Using health check script
./scripts/health-check.sh

# Check specific container
docker inspect pms-trade-capture --format='{{.State.Health.Status}}'
```

### Access Containers

```bash
# PostgreSQL
docker exec -it pms-postgres psql -U pms -d pmsdb

# Redis
docker exec -it pms-redis redis-cli -a redis

# RabbitMQ
docker exec -it pms-rabbitmq rabbitmqctl list_queues

# Kafka
docker exec -it pms-kafka kafka-topics --list --bootstrap-server localhost:9092

# Any service bash
docker exec -it pms-trade-capture bash
```

## 🛠️ Common Operations

### Build Services

```bash
# Build all services
docker compose build

# Build specific service
docker compose build trade-capture

# Build without cache
docker compose build --no-cache

# Parallel build using script
./scripts/build-all.sh parallel 4
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart trade-capture

# Recreate (rebuild + restart)
docker compose up -d --force-recreate trade-capture
```

### Scale Services

```bash
# Scale a service (if stateless)
docker compose up -d --scale trade-capture=3
```

### Update Single Service

```bash
# 1. Make code changes
# 2. Rebuild
docker compose build trade-capture

# 3. Recreate container
docker compose up -d --force-recreate trade-capture

# 4. Check logs
docker compose logs -f trade-capture
```

## 🐛 Troubleshooting

### Services Won't Start

1. **Check Docker resources**:
   ```bash
   docker system df
   docker system prune -a --volumes  # Clean up
   ```

2. **Check logs**:
   ```bash
   docker compose logs [service-name]
   ```

3. **Check dependencies**:
   ```bash
   # Ensure infrastructure is healthy first
   docker compose --profile infra up -d
   ./scripts/health-check.sh
   ```

### Port Conflicts

If ports are already in use, edit the compose files:

```yaml
ports:
  - "NEW_PORT:CONTAINER_PORT"
```

### Database Connection Issues

```bash
# Wait for PostgreSQL
docker exec pms-postgres pg_isready -U pms -d pmsdb

# Check logs
docker compose logs postgres

# Connect manually
docker exec -it pms-postgres psql -U pms -d pmsdb
```

### Kafka Issues

```bash
# Check Kafka health
docker exec pms-kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# List topics
docker exec pms-kafka kafka-topics --list --bootstrap-server localhost:9092

# Check Schema Registry
curl http://localhost:8081/subjects
```

### Out of Memory

1. Increase Docker Desktop memory (Settings > Resources)
2. Reduce Java heap sizes in compose files:
   ```yaml
   environment:
     JAVA_OPTS: "-Xms128m -Xmx256m"
   ```
3. Start services incrementally

### Clean Start

```bash
# Stop and remove everything
./scripts/stop-pms.sh clean

# Or manually
docker compose down -v
docker system prune -a

# Start fresh
./scripts/start-pms.sh full --build
```

## 📝 Development Workflow

### Recommended Workflow

1. **Start infrastructure**:
   ```bash
   docker compose --profile infra up -d
   ```

2. **Wait for healthy state**:
   ```bash
   ./scripts/health-check.sh
   ```

3. **Start your service for development**:
   ```bash
   # Option 1: Start in Docker
   docker compose --profile core up -d
   
   # Option 2: Run locally (outside Docker)
   # Configure application.yml to point to localhost:5432, localhost:6379, etc.
   ```

4. **Develop and test**:
   ```bash
   # Make changes
   # Rebuild if needed
   docker compose build my-service
   docker compose up -d my-service
   ```

5. **Clean up**:
   ```bash
   ./scripts/stop-pms.sh graceful
   ```

### Integration Testing

```bash
# Start full stack
docker compose --profile full up -d

# Wait for services
sleep 60

# Run tests
./run-integration-tests.sh

# Check results
./scripts/health-check.sh
```

## 🔒 Security Notes

⚠️ **Important**: This setup is for **local development only**!

- All secrets are hardcoded and exposed
- No TLS/SSL encryption
- Default credentials are used
- No network isolation beyond Docker bridge

**Never use these configurations in production!**

## 📚 Additional Resources

- [Main PMS Infrastructure README](../README.md)
- [AWS Secrets Reference](../secrets.env)
- [Deployment Architecture](../pms-deployment-architecture.md)
- [Kubernetes Deployment](../k8s/)
- [Terraform Infrastructure](../terraform/)

## 🤝 Contributing

When adding a new service:

1. Add service definition to appropriate compose file:
   - Core services → `services/docker-compose.core.yml`
   - Business services → `services/docker-compose.business.yml`
   - Frontend → `services/docker-compose.frontend.yml`

2. Update scripts:
   - Add to `start-pms.sh` startup sequence
   - Add health check in `health-check.sh`

3. Update this README with service details

4. Test with:
   ```bash
   docker compose --profile [profile] up -d
   ./scripts/health-check.sh
   ```

## 💡 Tips & Best Practices

- **Use profiles** to reduce resource usage during development
- **Start infrastructure first**, then applications
- **Check health** before running tests
- **Use `--build` flag** sparingly (only when code changes)
- **Monitor resources** with `docker stats`
- **Clean up regularly** with `docker system prune`
- **Use management tools** (Kafka UI, PgAdmin) for debugging
- **Keep volumes** between restarts to preserve data
- **Read logs** when services fail to start

## 📄 License

Internal PMS Organization use only.

---

**Questions?** Check the main [PMS Infrastructure README](../README.md) or contact the platform team.
