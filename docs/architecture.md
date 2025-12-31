# PMS Architecture

## System Overview

The Portfolio Management System (PMS) is a distributed microservices architecture for high-throughput trade processing.

```
┌─────────────┐
│ Simulation  │ (Trade Generator)
└──────┬──────┘
       │ Protobuf/RabbitMQ Stream
       ▼
┌──────────────────┐
│  Trade Capture   │ (Ingestion Service)
└────┬────────┬────┘
     │        │
     │        │ Protobuf/Kafka
     │        ▼
     │   ┌──────────────┐
     │   │  Validation  │ (Validation Service)
     │   └──────────────┘
     │
     │ JDBC
     ▼
┌────────────┐
│ PostgreSQL │ (Persistence Layer)
└────────────┘

Supporting Services:
- RabbitMQ (Streaming)
- Kafka + Schema Registry (Event Bus)
- Redis (Caching)
```

## Components

### 1. Simulation Service
**Purpose:** Generate realistic trade events for testing and simulation.

**Tech Stack:**
- Java/Spring Boot
- RabbitMQ Stream Producer
- PostgreSQL for trade data

**Responsibilities:**
- Generate trade events at configurable rates
- Publish to RabbitMQ Stream (`trade-stream`)
- Store simulation metadata in database

**Endpoints:**
- HTTP API for controlling simulation parameters
- Health checks

### 2. Trade Capture Service
**Purpose:** Ingest trades from RabbitMQ and publish to Kafka.

**Tech Stack:**
- Java/Spring Boot
- RabbitMQ Stream Consumer
- PostgreSQL (with advisory locks)
- Kafka Producer (Protobuf serialization)
- Outbox Pattern for reliability

**Responsibilities:**
- Consume trades from RabbitMQ Stream
- Batch persistence to PostgreSQL
- Outbox pattern for Kafka publication
- Dead Letter Queue (DLQ) handling
- Duplicate detection

**Data Flow:**
1. RabbitMQ Stream → Batch Ingestion
2. PostgreSQL → Transactional Write
3. Outbox Table → Polling Worker
4. Kafka → Protobuf Serialization

**Key Features:**
- Advisory locks prevent duplicate processing
- Configurable batch sizes (default 500)
- Retry logic with exponential backoff
- Health checks and metrics

### 3. Validation Service
**Purpose:** Validate trades and route to valid/invalid topics.

**Tech Stack:**
- Java/Spring Boot
- Kafka Consumer (Protobuf deserialization)
- Kafka Producer
- Redis (caching validation rules)
- PostgreSQL (validation results)

**Responsibilities:**
- Consume trades from Kafka (`raw-trades-topic`)
- Apply validation rules (cached in Redis)
- Publish to valid/invalid topics
- Store validation results

**Validation Rules:**
- Trade amount limits
- Symbol whitelist/blacklist
- Timestamp validation
- Required field checks

## Infrastructure Services

### PostgreSQL
- **Version:** 16
- **Purpose:** Primary data store
- **Configuration:**
  - User: pms / Pass: pms (local only)
  - Database: pmsdb
  - Port: 5432
- **Schemas:**
  - Trade tables (simulation, trade-capture)
  - Outbox table (trade-capture)
  - Validation results (validation)

### RabbitMQ
- **Version:** 3.13-management
- **Purpose:** High-throughput trade ingestion
- **Configuration:**
  - AMQP Port: 5672
  - Stream Port: 5552
  - Management UI: 15672
  - Plugins: rabbitmq_stream
- **Streams:**
  - `trade-stream` - Primary trade ingestion

### Kafka
- **Version:** 7.5.0 (Confluent Platform)
- **Mode:** KRaft (no Zookeeper)
- **Purpose:** Event streaming backbone
- **Configuration:**
  - Bootstrap: kafka:19092 (internal)
  - Controller: localhost:9093
  - Replication Factor: 1 (single node)
- **Topics:**
  - `raw-trades-topic` - Incoming trades
  - `valid-trades-topic` - Validated trades
  - `invalid-trades-topic` - Failed validation

**Important:** Kafka deployment uses `enableServiceLinks: false` and explicit PORT variable unset to avoid Kubernetes service discovery collisions.

### Schema Registry
- **Version:** 7.5.0 (Confluent Platform)
- **Purpose:** Protobuf schema management
- **Configuration:**
  - Port: 8081
  - Kafka Store: kafka:19092
- **Features:**
  - Schema versioning
  - Compatibility checks
  - Protobuf serialization

### Redis
- **Version:** redislabs/redismod
- **Purpose:** Caching layer
- **Configuration:**
  - Port: 6379
  - Modules: RedisAI, RedisSearch, RedisGraph, RedisTimeSeries, RedisJSON, RedisBloom, RedisGears
- **Usage:**
  - Validation rule caching
  - Session storage (future)
  - Rate limiting (future)

## Data Flow

### Trade Ingestion Flow

```
1. Simulation generates trade
   └─> Protobuf serialization
       └─> RabbitMQ Stream publish

2. Trade Capture consumes from Stream
   └─> Batch accumulation (500 trades or 100ms timeout)
       └─> PostgreSQL batch insert (with advisory lock)
           └─> Outbox table entry

3. Outbox Poller (background thread)
   └─> Query pending events
       └─> Kafka publish (Protobuf)
           └─> Mark as SENT

4. Validation consumes from Kafka
   └─> Protobuf deserialization
       └─> Apply validation rules (cached in Redis)
           └─> Publish to valid/invalid topic
               └─> Store result in PostgreSQL
```

## Network Communication

### Service Dependencies

```
Simulation:
  → postgres:5432
  → rabbitmq:5552
  → kafka:19092 (future enhancement)

Trade Capture:
  → postgres:5432
  → rabbitmq:5552
  → kafka:19092
  → schema-registry:8081

Validation:
  → postgres:5432
  → kafka:19092
  → schema-registry:8081
  → redis:6379
```

### DNS Resolution

All services use Kubernetes ClusterIP DNS:
- `postgres.pms.svc.cluster.local:5432`
- `kafka.pms.svc.cluster.local:19092`
- Short form: `postgres`, `kafka`, etc. (within same namespace)

### Init Containers

Each application uses init containers to wait for dependencies:
```yaml
initContainers:
  - name: wait-for-postgres
  - name: wait-for-rabbitmq
  - name: wait-for-kafka
  - name: wait-for-schema-registry
```

## Security

### Secrets Management
- Secrets stored in `k8s/overlays/<env>/secrets.env` (gitignored)
- Generated as Kubernetes Secrets via Kustomize `secretGenerator`
- Injected as environment variables
- **Never hardcoded** in manifests

### Network Policies (future)
- Restrict pod-to-pod communication
- Allow only necessary service access
- Deny external egress by default

## Scalability

### Current State (Local Development)
- Single replica for all services
- No autoscaling
- No resource limits

### Production Recommendations
- Horizontal Pod Autoscaling (HPA) for trade-capture and validation
- StatefulSets for Kafka (multi-broker)
- Persistent Volumes with SSD storage
- Resource limits/requests defined
- Network policies enforced

## Monitoring (future)

### Metrics
- Prometheus for scraping
- Grafana for visualization
- Application metrics via Micrometer/Actuator

### Logging
- Centralized logging (ELK or Loki)
- Structured JSON logs
- Correlation IDs for distributed tracing

### Tracing
- OpenTelemetry instrumentation
- Jaeger/Zipkin for trace visualization

## Disaster Recovery

### Backup Strategy (production)
- PostgreSQL: Daily backups with PITR
- Kafka: Topic replication (3x minimum)
- RabbitMQ: Persistent queues, mirrored

### Recovery Procedures
- Database restore from backups
- Kafka topic replay from earliest offset
- Graceful degradation with circuit breakers

## Known Issues

### Kafka/Schema Registry PORT Collision
**Symptom:** Pods crash with "port is deprecated" error

**Cause:** Kubernetes injects `KAFKA_PORT` / `SCHEMA_REGISTRY_PORT` environment variables

**Solution:** 
```yaml
enableServiceLinks: false
command:
  - /bin/bash
  - -c
  - |
    unset KAFKA_PORT
    unset SCHEMA_REGISTRY_SERVICE_PORT
    /etc/confluent/docker/run
```

See `KAFKA_FIX_SUMMARY.md` for details.

## Performance Characteristics

### Trade Capture
- Throughput: 10,000+ trades/sec (batch mode)
- Latency: < 100ms (p99)
- Batch Size: 500 trades or 100ms timeout

### Validation
- Throughput: 5,000+ trades/sec
- Latency: < 50ms (p99) with Redis cache hit
- Cache Hit Rate: > 95%

## Technology Decisions

### Why RabbitMQ Stream?
- Higher throughput than classic queues
- Consumer offset tracking
- Replay capability
- Lower latency than Kafka for ingestion

### Why Kafka for downstream?
- Durable event log
- Multiple consumer groups
- Schema evolution (Protobuf)
- Industry standard for event streaming

### Why Outbox Pattern?
- Exactly-once semantics
- Transactional consistency
- Decouples database writes from Kafka availability

### Why Protobuf?
- Compact binary format
- Schema evolution support
- Backwards/forwards compatibility
- Fast serialization/deserialization

## Future Enhancements

- [ ] Multi-region deployment
- [ ] Event sourcing for trade history
- [ ] CQRS pattern for read-heavy queries
- [ ] GraphQL API gateway
- [ ] Machine learning for trade validation
- [ ] Real-time analytics with Flink/Spark
