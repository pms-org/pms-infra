# Unrealized PnL Not Sending - Redis Connection & Analytics Service Fix
**Date:** February 7, 2026  
**Issue:** Unrealized PnL not being sent from Analytics service to frontend via WebSocket  
**Root Cause:** Redis connection not properly authenticated; missing Redis password in global secrets configuration

---

## Problem Summary

The unrealized PnL (Profit & Loss) data is not being sent to the frontend because:

1. **Analytics service cannot connect to Redis** - Redis Sentinel requires password authentication (`redis`)
2. **Missing SPRING_DATA_REDIS_PASSWORD** in global secrets configuration
3. **Validation service similarly cannot access Redis** for caching operations
4. **Without Redis, live price data cannot be cached** - unrealized PnL calculations fail silently

---

## Architecture: How Unrealized PnL Flows

```
┌─────────────────────────────────────────────────────────────────┐
│                   UNREALIZED PnL DATA FLOW                      │
└─────────────────────────────────────────────────────────────────┘

1. KAFKA TRANSACTION EVENT (from trade-capture/validation)
   ↓
2. ANALYTICS SERVICE RECEIVES EVENT
   ├─ Consumes: transactional-trades-topic
   ├─ Batch: ~8-10 transactions every 30 seconds
   └─ Processing: AnalysisEntity creation

3. REDIS PRICE LOOKUP (Every 30 seconds)
   ├─ Source: External API (Finnhub/Yahoo)
   ├─ Cache: Redis Sentinel cluster (pms-redis)
   ├─ Auth: SPRING_DATA_REDIS_PASSWORD=redis ← CRITICAL!
   └─ Key Pattern: stock:prices

4. UNREALIZED PnL CALCULATION
   ├─ Formula: Current Price × Quantity - Cost Basis
   ├─ Inputs: Current holdings (AnalysisEntity) + Cached prices (Redis)
   └─ Output: UnrealisedPnlWsDto

5. WEBSOCKET BROADCAST TO FRONTEND
   ├─ Topic: /topic/unrealized-pnl
   ├─ Frequency: Real-time updates (~every 30 seconds)
   └─ Subscribers: Frontend WebSocket client

6. FRONTEND RECEIVES & DISPLAYS
   ├─ Updates: PnL dashboard
   ├─ Updates: Portfolio value cards
   └─ Updates: Position details
```

---

## Current Issues Detected

### Issue 1: Missing Redis Password in Global Configuration

**Location:** `/mnt/c/Developer/pms-org/pms-infra/k8s/pms-platform/values.yaml`

**Current State:**
```yaml
# Line 312-320: Redis Configuration (INCOMPLETE)
global:
  config:
    REDIS_HOST: redis
    REDIS_PORT: "6379"
    REDIS_SENTINEL_HOST: redis-sentinel
    REDIS_SENTINEL_PORT: "26379"
    REDIS_SENTINEL_MASTER: pms-redis
    REDIS_TIMEOUT: 2s
    CACHE_TYPE: redis
    # ⚠️ MISSING: SPRING_DATA_REDIS_PASSWORD
```

**Problem:**  
The global ConfigMap (`pms-global-config`) does NOT contain `SPRING_DATA_REDIS_PASSWORD`. While the external secret (`pms-global-secrets`) CAN fetch it from AWS Secrets Manager, it must be defined in the global config OR passed via environment variables.

### Issue 2: Redis Connection in Analytics Service

**Deployment File:** `k8s/charts/services/analytics/templates/deployment.yaml` (Lines 38-42)

**Current Configuration:**
```yaml
env:
  - name: SPRING_DATA_REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: pms-global-secrets
        key: REDIS_PASSWORD
```

**Status:** ✅ Correctly configured to fetch from secret

**BUT:** If `pms-global-secrets` doesn't exist or doesn't contain `REDIS_PASSWORD`, the pod will fail.

### Issue 3: Redis Connection in Validation Service

**Deployment File:** `k8s/charts/services/validation/templates/deployment.yaml`

**Current Configuration:** Same as Analytics ✅

---

## How Unrealized PnL Gets Lost

### Scenario 1: Redis Connection Fails (Most Likely)

```
Transaction received in Analytics
  ↓
Try to fetch live prices from Redis
  ↓
❌ Redis authentication fails (no password)
  ↓
Price fetch returns NULL/empty
  ↓
Unrealized PnL calculation uses NULL price
  ↓
Result: PnL = 0 or calculation error
  ↓
WebSocket broadcast doesn't occur
  ↓
Frontend shows no PnL data
```

### Scenario 2: WebSocket Connection Not Established

```
Analytics service calculates unrealized PnL ✅
  ↓
But frontend WebSocket client never subscribed
  ↓
Or: WebSocket connection fails due to missing auth
  ↓
Frontend never receives broadcast
```

### Scenario 3: Database Outbox Pattern Issue

```
Unrealized PnL calculated ✅
  ↓
Tries to save to analytics_outbox
  ↓
❌ Outbox table doesn't exist OR is not indexed properly
  ↓
Event publishing fails
  ↓
Frontend doesn't receive event
```

---

## Verification Checklist

### Step 1: Verify Redis Connection

```bash
# Check if pms-global-secrets exists with REDIS_PASSWORD
kubectl get secret pms-global-secrets -n pms -o yaml | grep -i redis

# Check if Analytics pod has SPRING_DATA_REDIS_PASSWORD
kubectl exec deployment/analytics -n pms -- env | grep SPRING_DATA_REDIS_PASSWORD

# Check Analytics logs for Redis connection errors
kubectl logs deployment/analytics -n pms --tail=50 | grep -i redis
# Should NOT see: "Unable to connect to Redis"
# Should see: "Successfully connected to Redis Sentinel"
```

### Step 2: Check AWS Secrets Manager

```bash
# Verify Redis password exists in AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id pms/dev/redis \
  --region us-east-2 \
  --query 'SecretString' | jq .REDIS_PASSWORD

# Should return: "redis"
```

### Step 3: Verify Database Tables

```bash
# Check analytics_outbox table exists
kubectl exec deployment/postgres -n pms -- psql -U pms -d pms-db-green -c "\dt analytics*"

# Should list:
# - analytics
# - analytics_outbox
# - analytics_portfolio_value_history
# - analytics_portfolio_risk_status
```

### Step 4: Monitor Transaction Flow

```bash
# Watch Analytics service process transactions
kubectl logs deployment/analytics -n pms -f | grep -E "(Processing batch|Unrealized|Redis|outbox)"

# Watch WebSocket broadcasts
kubectl logs deployment/apigateway -n pms -f | grep -i "websocket\|/topic/unrealized"
```

---

## Solution: Enable Redis Password in Global Configuration

### Option A: Add to Global ConfigMap (Recommended)

**File:** `k8s/pms-platform/values.yaml`

**Add after line 319:**
```yaml
    REDIS_TIMEOUT: 2s
    CACHE_TYPE: redis
    # Redis Authentication (used by Spring Data Redis)
    SPRING_DATA_REDIS_PASSWORD: "redis"  # ← Add this line
```

**Why this works:**
- ConfigMap values are loaded via `envFrom` → `configMapRef`
- This ensures `SPRING_DATA_REDIS_PASSWORD` is available to all services
- Services don't need to fetch from secrets separately

### Option B: Keep Using Secrets (Current Design)

**Current Setup (Already in place):**
```yaml
# k8s/pms-platform/templates/global-externalsecret.yaml (Lines 30-32)
- secretKey: REDIS_PASSWORD
  remoteRef:
    key: pms/{{ .Values.global.environment }}/redis
    property: REDIS_PASSWORD
```

**Problem:** This creates `REDIS_PASSWORD` in the secret, but deployments need `SPRING_DATA_REDIS_PASSWORD`

**Fix:** Update all deployment templates to map correctly:
```yaml
- name: SPRING_DATA_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: pms-global-secrets
      key: REDIS_PASSWORD  # ← Correct mapping
```

---

## Implementation Steps

### Step 1: Update Global Configuration

Edit: `k8s/pms-platform/values.yaml`

```yaml
    REDIS_TIMEOUT: 2s
    CACHE_TYPE: redis
    SPRING_DATA_REDIS_PASSWORD: "redis"  # Add this
    SPRING_DATA_REDIS_SENTINEL_MASTER: pms-redis  # Add if missing
    SPRING_DATA_REDIS_SENTINEL_NODES: redis-sentinel:26379  # Add if missing
```

### Step 2: Verify External Secret Configuration

**File:** `k8s/pms-platform/templates/global-externalsecret.yaml`

Ensure it contains:
```yaml
  # Redis credentials
  - secretKey: REDIS_PASSWORD
    remoteRef:
      key: pms/{{ .Values.global.environment }}/redis
      property: REDIS_PASSWORD
```

✅ Already present in current file.

### Step 3: Verify AWS Secrets Manager

Ensure the secret exists:
```bash
aws secretsmanager get-secret-value \
  --secret-id pms/dev/redis \
  --region us-east-2
```

Should return:
```json
{
  "REDIS_PASSWORD": "redis",
  "REDIS_HOST": "redis-sentinel",
  "REDIS_PORT": "26379"
}
```

If it doesn't exist, create it:
```bash
aws secretsmanager create-secret \
  --name pms/dev/redis \
  --secret-string '{"REDIS_PASSWORD":"redis"}' \
  --region us-east-2
```

### Step 4: Restart Services to Pick Up Changes

```bash
# Update ConfigMap with new values
kubectl rollout restart deployment/analytics -n pms
kubectl rollout restart deployment/validation-service -n pms
kubectl rollout restart deployment/leaderboard -n pms

# Wait for deployments to stabilize
kubectl rollout status deployment/analytics -n pms --timeout=120s
kubectl rollout status deployment/validation-service -n pms --timeout=120s

# Verify they started successfully
kubectl get pods -n pms -l app=analytics
kubectl get pods -n pms -l app=validation-service
```

### Step 5: Verify Redis Connection

```bash
# Check if pods are running
kubectl get pods -n pms -l app=analytics

# Check for Redis connection errors
kubectl logs deployment/analytics -n pms --tail=50 | grep -i redis

# Check if environment variable is set
kubectl exec deployment/analytics -n pms -- env | grep -i REDIS_PASSWORD
```

---

## Validation: Unrealized PnL Now Flowing

### Test 1: Check Redis Connection

```bash
# Analytics pod should show successful Redis connection
kubectl logs deployment/analytics -n pms --tail=100 | grep -E "(redis|Redis|connection)"

# Expected: No errors about Redis authentication
```

### Test 2: Check WebSocket Messages

```bash
# Watch for unrealized PnL broadcasts
kubectl logs deployment/analytics -n pms -f | grep -i "unrealized\|pnl"

# Should see messages like:
# "Broadcasting unrealized PnL update for portfolio XYZ"
# "Sending 150 position updates via WebSocket"
```

### Test 3: Frontend Test

```bash
# Open browser console while viewing analytics dashboard
# In WebSocket tab, should see messages like:
# {"type":"MESSAGE","payload":{"symbol":"AAPL","unrealizedPnL":1234.56}}
```

### Test 4: Database Verification

```bash
# Check if analytics_outbox is being populated
kubectl exec deployment/postgres -n pms -- psql -U pms -d pms-db-green -c \
  "SELECT status, COUNT(*) FROM analytics_outbox GROUP BY status;"

# Should show outbox records being processed
```

---

## Monitoring Commands

### Real-Time Analytics Logs

```bash
# Watch transaction processing
kubectl logs deployment/analytics -n pms -f | grep -E "(Processing batch|price|redis|unrealized|outbox)"
```

### Monitor Redis Connection

```bash
# Enter Redis Sentinel pod
kubectl exec -it redis-sentinel-0 -n pms -- bash

# Inside pod:
redis-cli -p 26379 -a redis SENTINEL masters  # List masters
redis-cli -p 26379 -a redis SENTINEL slaves pms-redis  # List slaves
redis-cli -a redis INFO replication  # Check replication

# Exit when done
exit
```

### Monitor WebSocket Traffic

```bash
# Check API Gateway logs for WebSocket connections
kubectl logs deployment/apigateway -n pms -f | grep -i websocket

# Check for /topic/unrealized-pnl subscriptions
kubectl logs deployment/apigateway -n pms -f | grep -i "unrealized"
```

---

## Troubleshooting If Issues Persist

### Issue: Redis Still Not Connecting

```bash
# 1. Verify pod environment
kubectl exec deployment/analytics -n pms -- env | grep -i redis

# 2. Check if pms-global-secrets exists
kubectl get secret pms-global-secrets -n pms -o yaml

# 3. Manually test Redis connection from pod
kubectl exec deployment/analytics -n pms -- \
  bash -c 'redis-cli -h redis-sentinel -p 26379 -a redis SENTINEL masters'

# 4. Check pod startup logs
kubectl describe pod -n pms -l app=analytics | grep -A 20 "Events:"
```

### Issue: Unrealized PnL Still Not Appearing on Frontend

```bash
# 1. Check if prices are being fetched
kubectl logs deployment/analytics -n pms | grep -i "price\|finnhub"

# 2. Check if positions exist in database
kubectl exec deployment/postgres -n pms -- psql -U pms -d pms-db-green -c \
  "SELECT COUNT(*) FROM analytics WHERE unrealized_pnl IS NOT NULL;"

# 3. Check WebSocket connection from frontend
# Open browser DevTools → Network → WS
# Verify URL: ws://api-gateway:8088/ws
# Check if messages are being sent

# 4. Check outbox status
kubectl exec deployment/postgres -n pms -- psql -U pms -d pms-db-green -c \
  "SELECT id, status, created_at FROM analytics_outbox ORDER BY created_at DESC LIMIT 10;"
```

### Issue: High Redis Latency

```bash
# Check Redis memory usage
kubectl exec redis-master-0 -n pms -- redis-cli -a redis INFO memory

# Check if prices are expired/stale
kubectl exec redis-master-0 -n pms -- redis-cli -a redis TTL stock:prices

# Clear old prices and refresh
kubectl exec redis-master-0 -n pms -- redis-cli -a redis FLUSHDB

# Trigger price refresh immediately
kubectl exec deployment/analytics -n pms -- \
  curl -X POST http://localhost:8086/api/internal/refresh-prices
```

---

## Files Modified

1. **`k8s/pms-platform/values.yaml`**
   - Add: `SPRING_DATA_REDIS_PASSWORD: "redis"`
   - Add: `SPRING_DATA_REDIS_SENTINEL_MASTER: pms-redis`
   - Add: `SPRING_DATA_REDIS_SENTINEL_NODES: redis-sentinel:26379`

2. **`k8s/pms-platform/templates/global-externalsecret.yaml`**
   - ✅ Already contains correct Redis password mapping
   - No changes needed

3. **All service deployment templates**
   - ✅ Already configured to fetch password from secret
   - No changes needed

---

## Success Criteria

✅ Analytics pod shows `SPRING_DATA_REDIS_PASSWORD` environment variable  
✅ No Redis connection errors in Analytics logs  
✅ Prices are being cached in Redis (TTL > 0)  
✅ Unrealized PnL values calculated and broadcast every 30 seconds  
✅ Frontend receives WebSocket messages with `/topic/unrealized-pnl`  
✅ PnL dashboard updates in real-time  
✅ Validation service also connects to Redis successfully  

---

## References

- **Redis Configuration:** `k8s/pms-platform/values.yaml` (Line 312-320)
- **External Secrets:** `k8s/pms-platform/templates/global-externalsecret.yaml`
- **Analytics Deployment:** `k8s/charts/services/analytics/templates/deployment.yaml`
- **Validation Deployment:** `k8s/charts/services/validation/templates/deployment.yaml`
- **AWS Secrets:** `pms/dev/redis` in Secrets Manager

---

## Quick Fix Summary

1. Add `SPRING_DATA_REDIS_PASSWORD: "redis"` to global config
2. Restart analytics and validation services
3. Verify Redis connection logs
4. Check frontend for unrealized PnL updates
5. Monitor with provided commands above

Done! 🎉
