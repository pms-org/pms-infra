# Analytics Service - LLM Fix-It Prompt Template

**Purpose:** Copy-paste this entire document into an LLM conversation to quickly fix analytics service issues.

---

## Quick Start: Paste This Into Your LLM

```
I'm having issues with the pms-analytics service in Kubernetes. Here's the context:

ENVIRONMENT:
- Kubernetes cluster: EKS "pms-dev", namespace "pms"
- Service: analytics (Spring Boot 3.5.8, Java 21)
- Database: PostgreSQL (postgres:5432, database: pmsdb, user: pms)
- Redis: Sentinel cluster (master: pms-redis, sentinels: redis-sentinel:26379, password: redis)
- Kafka: kafka:29092, topic: transactional-trades-topic

SYMPTOMS:
[Describe what's not working - paste error logs here]

COMMANDS TO DIAGNOSE:
# Check pod status
kubectl get pods -n pms -l app=analytics

# Check recent logs
kubectl logs deployment/analytics -n pms --tail=200

# Check for errors
kubectl logs deployment/analytics -n pms --tail=200 | grep -i error

# Check database tables
kubectl exec deployment/postgres -n pms -- psql -U pms -d pmsdb -c "\dt analytics*"

# Check outbox status
kubectl exec deployment/postgres -n pms -- psql -U pms -d pmsdb -c "SELECT status, COUNT(*) FROM analytics_outbox GROUP BY status;"

KNOWN ISSUES & FIXES:

1. Redis Connection Error:
   - Error: "Unable to connect to Redis"
   - Fix: Add password configuration in RedisConfig.java
   - File: src/main/java/com/pms/analytics/config/RedisConfig.java
   - Add: @Value("${spring.data.redis.password:}") private String redisPassword;
   - Add: config.setPassword(redisPassword); in redisConnectionFactory()

2. BigDecimal Parsing Error:
   - Error: "Character N is neither a decimal"
   - Fix: Add parseBigDecimal() helper in TransactionMapper.java
   - File: src/main/java/com/pms/analytics/mapper/TransactionMapper.java
   - Returns BigDecimal.ZERO for "NA", null, or invalid values

3. Insufficient Holdings Error:
   - Error: "Insufficient holdings: Trying to sell X but only Y available"
   - Fix: Skip instead of throw in TransactionService.java
   - File: src/main/java/com/pms/analytics/service/TransactionService.java
   - Change handleSell() to return early instead of throwing exception

4. Missing Table Error:
   - Error: "relation 'analytics_portfolio_risk_status' does not exist"
   - Fix: Create table with SQL
   - Command: kubectl exec -i deployment/postgres -n pms -- psql -U pms -d pmsdb
   - SQL: CREATE TABLE IF NOT EXISTS analytics_portfolio_risk_status (portfolio_id UUID PRIMARY KEY, last_computed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP);

5. Empty Outbox:
   - Symptom: "Fetched 0 from outbox"
   - Cause: No historical data (needs 29+ days)
   - Fix: Run scripts/populate_historical_data.sql to create synthetic test data

6. Outbox Not Populating After Batch:
   - Symptom: "Saving 0 records in outbox" after "Triggering risk metrics"
   - Fix: Add RiskMetricsCalculator trigger in BatchProcessingService.java
   - File: src/main/java/com/pms/analytics/service/BatchProcessingService.java
   - Inject RiskMetricsCalculator and call after batch processing

BUILD & DEPLOY:
cd /mnt/c/Developer/pms-org/pms-analytics
docker build -t niishantdev/pms-analytics:latest .
docker push niishantdev/pms-analytics:latest
kubectl rollout restart deployment/analytics -n pms
kubectl rollout status deployment/analytics -n pms --timeout=120s

Please help me fix this issue step by step.
```

---

## Error Pattern Matching

### If you see: "Unable to connect to Redis"
**LLM Prompt:**
```
The analytics service is failing to connect to Redis Sentinel. The error is:
"Unable to connect to Redis; nested exception is io.lettuce.core.RedisConnectionException"

Redis is configured as:
- Master: pms-redis
- Sentinels: redis-sentinel:26379
- Password: redis

The RedisConfig.java is missing password authentication. Please show me the complete RedisConfig.java file with password configuration added using @Value("${spring.data.redis.password:}") and setting it in RedisSentinelConfiguration.
```

### If you see: "Character N is neither a decimal"
**LLM Prompt:**
```
Transaction processing is failing with:
"Error processing transaction: Character N is neither a decimal digit number..."

This happens when Kafka messages contain "NA" as the buyPrice or sellPrice. The TransactionMapper.fromProto() method is calling "new BigDecimal(proto.getBuyPrice())" directly.

Please create a parseBigDecimal(String value) helper method that:
1. Returns BigDecimal.ZERO for null, empty, or "NA" values
2. Catches NumberFormatException and returns BigDecimal.ZERO
3. Update fromProto() to use this helper for buyPrice and sellPrice
```

### If you see: "Insufficient holdings"
**LLM Prompt:**
```
SELL transactions are failing with:
"Insufficient holdings: Trying to sell X but only Y available"

This causes the entire batch to fail. The issue is in TransactionService.handleSell() which throws InsufficientHoldingsException.

Please modify handleSell() to:
1. Check if entity.getHoldings() < quantity
2. If true, print "SELL skipped: insufficient holdings..." and return early
3. Do NOT throw an exception
4. Allow the batch to continue processing other transactions
```

### If you see: "relation does not exist"
**LLM Prompt:**
```
The application is crashing with:
"org.postgresql.util.PSQLException: ERROR: relation 'analytics_portfolio_risk_status' does not exist"

This table is used by PortfolioRiskStatusDao to track when risk metrics were last computed.

Please provide:
1. SQL to create the table with columns: portfolio_id (UUID, PRIMARY KEY), last_computed_at (TIMESTAMP)
2. kubectl command to execute it in postgres pod
3. Index on last_computed_at for performance
```

### If you see: "Fetched 0 from outbox"
**LLM Prompt:**
```
The outbox table is empty. Logs show:
"Fetched 0 from outbox"
"Cannot compute risk - it needs atleast 29 days of history"

The analytics_portfolio_value_history table is empty. Risk metrics require 29 days of daily portfolio value snapshots.

Please create a SQL script that:
1. Gets all portfolio IDs from the analytics table
2. For each portfolio, generates 30 days of synthetic historical data
3. Uses realistic variations (±2% daily volatility, slight upward trend)
4. Inserts into analytics_portfolio_value_history with proper UUID, timestamps
5. Includes verification queries at the end

Table structure:
- id (UUID)
- portfolio_id (UUID)
- date (DATE)
- portfolio_value (NUMERIC(38,2))
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

### If you see: "Saving 0 records in outbox" after triggering
**LLM Prompt:**
```
The risk calculator is being triggered but not creating outbox entries:
"Triggering risk metrics calculation to populate outbox after batch processing."
"Saving 0 records in outbox."

Historical data exists (150 records, 30 days). The issue is that BatchProcessingService isn't calling RiskMetricsCalculator.

Please show me how to:
1. Inject RiskMetricsCalculator into BatchProcessingService using @Autowired
2. After sending WebSocket update in processBatch(), call riskMetricsCalculator.computeRiskMetricsForAllPortfolios()
3. Wrap in try-catch to handle exceptions gracefully
4. Log "Triggering risk metrics calculation to populate outbox after batch processing."
```

---

## Common Command Sequences

### Diagnose Issues
```bash
# Get pod status
kubectl get pods -n pms -l app=analytics

# Get recent logs
kubectl logs deployment/analytics -n pms --tail=200

# Get errors only
kubectl logs deployment/analytics -n pms --tail=200 | grep -i error

# Get transaction processing logs
kubectl logs deployment/analytics -n pms --tail=100 | grep -E "(Processing batch|Saving.*batch|SELL|BUY)"

# Check database
kubectl exec deployment/postgres -n pms -- psql -U pms -d pmsdb -c "
SELECT 'analytics' as table, COUNT(*) FROM analytics
UNION ALL SELECT 'analytics_outbox', COUNT(*) FROM analytics_outbox
UNION ALL SELECT 'analytics_portfolio_value_history', COUNT(*) FROM analytics_portfolio_value_history
UNION ALL SELECT 'analytics_portfolio_risk_status', COUNT(*) FROM analytics_portfolio_risk_status;
"

# Check outbox status
kubectl exec deployment/postgres -n pms -- psql -U pms -d pmsdb -c "
SELECT status, COUNT(*) FROM analytics_outbox GROUP BY status;
"
```

### Apply Fixes
```bash
# Create missing table
kubectl exec -i deployment/postgres -n pms -- psql -U pms -d pmsdb << 'EOF'
CREATE TABLE IF NOT EXISTS analytics_portfolio_risk_status (
    portfolio_id UUID PRIMARY KEY,
    last_computed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_portfolio_risk_last_computed 
ON analytics_portfolio_risk_status(last_computed_at);
EOF

# Populate historical data
kubectl exec -i deployment/postgres -n pms -- psql -U pms -d pmsdb < /mnt/c/Developer/pms-org/pms-analytics/scripts/populate_historical_data.sql

# Update ConfigMap
kubectl patch configmap analytics-config -n pms --type merge -p '{
  "data": {
    "SPRING_DATA_REDIS_PASSWORD": "redis",
    "ANALYTICS_PORTFOLIO_VALUE_CRON": "0 59 23 * * ?",
    "ANALYTICS_PORTFOLIO_VALUE_TIMEZONE": "Asia/Kolkata",
    "ANALYTICS_PRICE_REFRESH_DELAY_MS": "30000"
  }
}'

# Rebuild and deploy
cd /mnt/c/Developer/pms-org/pms-analytics
docker build -t niishantdev/pms-analytics:latest .
docker push niishantdev/pms-analytics:latest
kubectl rollout restart deployment/analytics -n pms
kubectl rollout status deployment/analytics -n pms --timeout=120s
```

### Verify Fixes
```bash
# Wait for processing
sleep 60

# Check transaction processing
kubectl logs deployment/analytics -n pms --tail=50 | grep "Saving a batch"

# Check risk calculation
kubectl logs deployment/analytics -n pms --tail=50 | grep "Saving.*outbox"

# Check outbox
kubectl exec deployment/postgres -n pms -- psql -U pms -d pmsdb -c "
SELECT status, COUNT(*) FROM analytics_outbox GROUP BY status;
"

# Check Kafka publishing
kubectl logs deployment/analytics -n pms --tail=50 | grep "sent to Kafka"
```

---

## File Modification Templates

### RedisConfig.java (Add Password)
```java
@Value("${spring.data.redis.password:}")
private String redisPassword;

@Bean
public LettuceConnectionFactory redisConnectionFactory() {
    RedisSentinelConfiguration config = new RedisSentinelConfiguration();
    config.master(sentinelMaster);
    
    if (redisPassword != null && !redisPassword.isEmpty()) {
        config.setPassword(redisPassword);
    }
    
    // ... rest of configuration
}
```

### TransactionMapper.java (Add Helper)
```java
private static BigDecimal parseBigDecimal(String value) {
    if (value == null || value.isEmpty() || "NA".equalsIgnoreCase(value)) {
        return BigDecimal.ZERO;
    }
    try {
        return new BigDecimal(value);
    } catch (NumberFormatException e) {
        System.err.println("Invalid BigDecimal value: " + value + ", defaulting to ZERO");
        return BigDecimal.ZERO;
    }
}

public static TransactionDto fromProto(Transaction proto) {
    return TransactionDto.builder()
        .buyPrice(parseBigDecimal(proto.getBuyPrice()))
        .sellPrice(parseBigDecimal(proto.getSellPrice()))
        // ... rest of mapping
        .build();
}
```

### TransactionService.java (Skip Logic)
```java
private void handleSell(AnalysisEntity entity, BigDecimal sellPrice, int quantity) {
    if (entity.getHoldings() < quantity) {
        System.out.println("SELL skipped: insufficient holdings. Trying to sell " 
            + quantity + " but only " + entity.getHoldings() + " available.");
        return; // Skip instead of throw
    }
    // ... rest of sell logic
}
```

### BatchProcessingService.java (Add Trigger)
```java
@Autowired
private RiskMetricsCalculator riskMetricsCalculator;

@Transactional
public void processBatch(List<Transaction> messages) {
    // ... existing batch processing
    
    // Add at the end
    try {
        log.info("Triggering risk metrics calculation to populate outbox after batch processing.");
        riskMetricsCalculator.computeRiskMetricsForAllPortfolios();
    } catch (RuntimeException ex) {
        log.error("Failed to compute risk metrics and populate outbox", ex);
    }
}
```

---

## Success Indicators

After applying fixes, you should see:

```
✅ Pod running: 1/1 Ready
✅ No Redis connection errors
✅ Transaction batches processing: "Saving a batch of X analysis records"
✅ No "Character N" errors
✅ "SELL skipped" messages instead of exceptions
✅ Historical data: 150+ records (5 portfolios × 30 days)
✅ Risk calculation: "Computing risk metrics for X portfolios"
✅ Outbox entries: "Saving X records in outbox" (X > 0)
✅ Kafka publishing: "sent to Kafka successfully"
✅ Outbox status: SENT records > 0
```

---

## Quick Reference: What Needs Fixing

| Symptom | File to Fix | What to Add |
|---------|-------------|-------------|
| Redis connection error | RedisConfig.java | Password configuration |
| "Character N" error | TransactionMapper.java | parseBigDecimal() helper |
| Insufficient holdings | TransactionService.java | Skip instead of throw |
| Table doesn't exist | Database | CREATE TABLE SQL |
| Empty outbox | Database | Populate historical data |
| Not triggering after batch | BatchProcessingService.java | RiskMetricsCalculator call |

---

**End of LLM Prompt Template**

Save this file and use it as a quick reference for fixing analytics issues.
