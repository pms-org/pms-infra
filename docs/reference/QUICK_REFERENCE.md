# Quick Reference: PMS Platform Deployment Changes

## 🔧 Code Changes

### 1. pms-simulation/src/main/java/com/dtcc/simulation/service/TradeGeneratorService.java
```java
// ADDED: Prevent future timestamps
private void updateTimestamp(TradeEvent t) {
    long randomGapSeconds = 1 + random.nextInt(300);
    lastTimestamp = lastTimestamp.plusSeconds(randomGapSeconds);
    
    // NEW: Ensure timestamp never goes into the future
    LocalDateTime now = LocalDateTime.now();
    if (lastTimestamp.isAfter(now)) {
        lastTimestamp = now.minusHours(1);
    }
    
    t.setTimestamp(lastTimestamp);
}
```

### 2. pms-validation/src/main/resources/application.yml
```yaml
# CHANGED: Database URL construction
datasource:
  url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:pmsdb}
  # WAS: url: ${DB_URL}
```

### 3. pms-validation/src/main/java/.../service/outbox/ValidationOutboxEventProcessor.java
```java
// REMOVED: Hardcoded topic
// private static final String TOPIC = "portfolio-risk-metrics";

// ADDED: Configurable topic
@Value("${app.outgoing-valid-trades-topic}")
private String validTradesTopic;

// UPDATED: All 4 references
kafkaTemplate.send(validTradesTopic, ...);  // was: TOPIC
```

### 4. pms-portfolio/src/main/resources/application.yaml
```yaml
# CHANGED: Make DDL mode configurable
jpa:
  hibernate:
    ddl-auto: ${DB_DDL_AUTO:update}  # WAS: validate
```

---

## 📝 Helm Chart Changes

### pms-infra/k8s/charts/services/portfolio/values.yaml
```yaml
config:
  DB_DDL_AUTO: "update"  # WAS: "validate"
```

### pms-infra/k8s/charts/services/auth/values.yaml
```yaml
dependencies:
  - name: apigateway
    command:
      - sh
      - -c
      - "until nc -z apigateway 8088; do ..."  # WAS: 8080
```

### pms-infra/k8s/charts/services/validation/values.yaml
```yaml
config:
  KAFKA_CONSUMER_GROUP_ID: "validation-consumer-group"  # ADDED
```

### pms-infra/k8s/charts/services/transactional/values.yaml
```yaml
config:
  TRANSACTIONAL_TRADES_CONSUMER_CONSUMER_ID: "transactional-trades-consumer-1"  # ADDED
  TRANSACTIONAL_TRADES_CONSUMER_DLT_TOPIC: "transactional-trades-dlt"  # ADDED
```

### pms-infra/k8s/charts/services/analytics/values.yaml
```yaml
config:
  ANALYTICS_REDIS_TIMEOUT: "10000"  # WAS: "10s" (milliseconds)
  ANALYTICS_REDIS_SHUTDOWN_TIMEOUT: "2000"  # WAS: "2s" (milliseconds)
```

---

## 💾 Database Reference Data

### Execute Once on PostgreSQL
```sql
-- Portfolio IDs
INSERT INTO portfolio_investor_details (portfolio_id, name, phone_number, address) VALUES
('3f2c1d4e-8b57-4a92-9c65-b5e6f4e19b73', 'Portfolio A', 1234567890, 'New York'),
('a8d4c0fa-7c1b-4e5d-9a89-2d635f0e2a14', 'Portfolio B', 1234567891, 'San Francisco'),
('d91f0b62-4c2f-4b91-8f2f-1b6c4ad7e543', 'Portfolio C', 1234567892, 'Boston'),
('59c8a6d1-3f8b-4a67-bab6-89d0e72cce10', 'Portfolio D', 1234567893, 'Chicago'),
('e2fa4c39-2a65-41c8-9f91-3c57f1d900ba', 'Portfolio E', 1234567894, 'Seattle')
ON CONFLICT (portfolio_id) DO NOTHING;

-- Stock Symbols
INSERT INTO pms_stocks (symbol, sector_name, created_at, updated_at) VALUES
('AAPL', 'TECH', now(), now()),
('MSFT', 'TECH', now(), now()),
('GOOGL', 'TECH', now(), now()),
('AMZN', 'TECH', now(), now()),
('META', 'TECH', now(), now()),
('NVDA', 'TECH', now(), now()),
('TSLA', 'AUTO', now(), now()),
('NFLX', 'ENTERTAINMENT', now(), now()),
('AMD', 'TECH', now(), now()),
('INTC', 'TECH', now(), now()),
('IBM', 'TECH', now(), now()),
('ORCL', 'TECH', now(), now()),
('BAC', 'FINANCE', now(), now()),
('JPM', 'FINANCE', now(), now()),
('WMT', 'RETAIL', now(), now())
ON CONFLICT (symbol) DO NOTHING;
```

---

## 🐳 Docker Images to Rebuild

```bash
# 1. Simulation (timestamp fix)
cd pms-simulation
docker build -t niishantdev/pms-simulation:latest .
docker push niishantdev/pms-simulation:latest

# 2. Validation (outbox topic fix + DB URL fix)
cd pms-validation/docker
docker build -t niishantdev/pms-validation:latest .
docker push niishantdev/pms-validation:latest

# 3. Portfolio (ddl-auto fix)
cd pms-portfolio
docker build -t niishantdev/pms-portfolio:latest .
docker push niishantdev/pms-portfolio:latest
```

---

## 🚀 Deployment Steps

```bash
# 1. Navigate to Helm chart
cd pms-infra/k8s/pms-platform

# 2. Update dependencies
helm dependency update

# 3. Deploy
helm upgrade pms-platform . -n pms --timeout 5m

# 4. Restart affected pods
kubectl delete pod -n pms -l app=simulation
kubectl delete pod -n pms -l app=validation-service
kubectl delete pod -n pms -l app=portfolio
```

---

## ✅ Verification Commands

```bash
# Check pod status
kubectl get pods -n pms

# Check Kafka topics
kubectl exec -n pms kafka-* -- kafka-topics --bootstrap-server localhost:19092 --list

# Monitor valid trades
kubectl exec -n pms kafka-* -- \
  kafka-console-consumer --bootstrap-server localhost:19092 \
  --topic valid-trades-topic --max-messages 5

# Check database
kubectl exec -n pms postgres-* -- psql -U pms -d pmsdb -c "
  SELECT COUNT(*) FROM validation_outbox;
  SELECT COUNT(*) FROM portfolio_investor_details;
  SELECT COUNT(*) FROM pms_stocks;
"

# Check service logs
kubectl logs -n pms -l app=validation-service --tail=50
kubectl logs -n pms -l app=transactional --tail=50
kubectl logs -n pms -l app=simulation --tail=50
```

---

## 📊 Expected Results

After deployment:
- ✅ All pods in Running state (1/1 READY)
- ✅ Valid trades appearing in `valid-trades-topic`
- ✅ Transactional service processing batches
- ✅ Analytics receiving transaction messages
- ✅ Invalid trade rate: 15-30% (down from 100%)
- ✅ ~30 valid trades per minute

---

## 🔍 Troubleshooting

### If validation service has errors:
```bash
# Check reference data
kubectl exec -n pms postgres-* -- psql -U pms -d pmsdb -c "
  SELECT COUNT(*) FROM portfolio_investor_details;
  SELECT COUNT(*) FROM pms_stocks;
"
# Should show 5 and 15 respectively
```

### If no valid trades:
```bash
# Check outbox
kubectl exec -n pms postgres-* -- psql -U pms -d pmsdb -c "
  SELECT COUNT(*), sent_status FROM validation_outbox GROUP BY sent_status;
"

# Check validation logs
kubectl logs -n pms -l app=validation-service | grep -i "outbox\|sent"
```

### If transactional not consuming:
```bash
# Check consumer group
kubectl exec -n pms kafka-* -- \
  kafka-consumer-groups --bootstrap-server localhost:19092 \
  --describe --group transactional-validation-consumer-group
```

---

## 📝 Files Changed Summary

**Application Code:**
- ✏️ pms-simulation/src/main/java/.../TradeGeneratorService.java
- ✏️ pms-validation/src/main/resources/application.yml
- ✏️ pms-validation/src/main/java/.../ValidationOutboxEventProcessor.java
- ✏️ pms-portfolio/src/main/resources/application.yaml

**Helm Charts:**
- ✏️ k8s/charts/services/portfolio/values.yaml
- ✏️ k8s/charts/services/auth/values.yaml
- ✏️ k8s/charts/services/validation/values.yaml
- ✏️ k8s/charts/services/transactional/values.yaml
- ✏️ k8s/charts/services/analytics/values.yaml

**Docker Images:**
- 🐳 niishantdev/pms-simulation:latest
- 🐳 niishantdev/pms-validation:latest
- 🐳 niishantdev/pms-portfolio:latest

**Database:**
- 💾 portfolio_investor_details (5 rows)
- 💾 pms_stocks (15 rows)

---

**Last Updated:** January 29, 2026
