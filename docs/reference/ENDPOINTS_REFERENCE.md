# 🔌 PMS Platform Endpoints Documentation

## Overview
This document provides a comprehensive overview of all HTTP and WebSocket endpoints exposed by the PMS platform services.

## 🏗️ Architecture

### Service Communication Flow
```
Browser/Client
    ↓
Frontend (LoadBalancer) → API Gateway (LoadBalancer) → Backend Services
                                ↓
                    ┌───────────┼───────────┐
                    ↓           ↓           ↓
                Analytics  Leaderboard    RTTM
                Portfolio    Auth      Simulation
```

### API Gateway Routes
All external traffic goes through the API Gateway which handles:
- Rate limiting
- Circuit breaking
- Retry logic
- Request routing
- CORS headers

---

## 📋 Service Endpoints Summary

### 1. Auth Service (Port: 8081)

**Base Path:** `/api/auth`

| Endpoint | Method | Purpose | Request Body | Response |
|----------|--------|---------|--------------|----------|
| `/api/auth/signup` | POST | User registration | `{username, password, email}` | User details + JWT |
| `/api/auth/login` | POST | User authentication | `{username, password}` | JWT token |

**Via API Gateway:**
- Direct access through API Gateway (routes not explicitly defined, falls through)

---

### 2. Portfolio Service (Port: 8095)

**Base Path:** `/api/portfolio`

| Endpoint | Method | Purpose | Request Body | Response |
|----------|--------|---------|--------------|----------|
| `/api/portfolio/create` | POST | Create new portfolio | `{name, ...}` | Portfolio details |
| `/api/portfolio/{id}` | GET | Get portfolio by ID | - | Portfolio details |
| `/api/portfolio/all` | GET | Get all portfolios | - | `Portfolio[]` |

**Via API Gateway:**
```
/portfolio/** → http://portfolio-id-service:8095/**
```

---

### 3. Analytics Service (Port: 8086)

**Base Path:** `/api`

#### HTTP Endpoints

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/api/analysis/all` | GET | All portfolio analysis | `AnalysisEntityDto[]` |
| `/api/unrealized` | GET | Unrealized PnL data | PnL data |
| `/api/sectors/overall` | GET | Overall sector breakdown | `SectorMetricsDto[]` |
| `/api/sectors/sector-wise/{sector}` | GET | Sector drilldown | `SectorMetricsDto[]` |
| `/api/sectors/portfolio-wise/{portfolioId}` | GET | Portfolio sector analysis | `SectorMetricsDto[]` |
| `/api/sectors/portfolio-wise/{portfolioId}/sector-wise/{sector}` | GET | Portfolio + sector drilldown | `SectorMetricsDto[]` |
| `/api/sectors/sector-catalog` | GET | Available sectors | `String[]` |
| `/api/portfolio_value/history/{portfolioId}` | GET | Portfolio value history | History data |
| `/api/transactions` | POST | Record transaction | Transaction details | Success response |

#### WebSocket Endpoints (STOMP)

**Connection:** `/ws`

| Topic/Destination | Type | Purpose | Message Type |
|-------------------|------|---------|--------------|
| `/topic/position-update` | Subscribe | Real-time position updates | `AnalysisEntityDto` |
| `/topic/unrealized-pnl` | Subscribe | Live PnL updates | `UnrealisedPnlWsDto` |

**Via API Gateway:**
```
/api/analysis/** → http://pms-analytics:8086/api/analysis/**
/api/sectors/** → http://pms-analytics:8086/api/sectors/**
/api/transactions/** → http://pms-analytics:8086/api/transactions/**
/api/portfolio_value/** → http://pms-analytics:8086/api/portfolio_value/**
/api/unrealized/** → http://pms-analytics:8086/api/unrealized/**
/analytics/** → http://pms-analytics:8086/api/**
```

---

### 4. Leaderboard Service (Port: 8000)

**Base Path:** `/api/leaderboard`

#### HTTP Endpoints

| Endpoint | Method | Purpose | Query Params | Response |
|----------|--------|---------|--------------|----------|
| `/api/leaderboard/top` | GET | Top performers | `limit` (optional) | `LeaderboardEntry[]` |
| `/api/leaderboard/around` | GET | Rankings around portfolio | `portfolioId` | `LeaderboardEntry[]` |

#### WebSocket Endpoints

**Connection:** Direct WebSocket

| Endpoint | Type | Purpose | Message Type |
|----------|------|---------|--------------|
| `/ws/updates` | WebSocket | Leaderboard snapshots | `LeaderboardSnapshot` |
| `/ws/leaderboard/top` | WebSocket | Top performer updates | `LeaderboardEntry[]` |
| `/ws/leaderboard/around` | WebSocket | Around portfolio updates | `LeaderboardEntry[]` |

**Via API Gateway:**
```
/api/leaderboard/** → http://pms-leaderboard:8000/api/leaderboard/**
/leaderboard/** → http://pms-leaderboard:8000/api/leaderboard/**
```

---

### 5. RTTM Service (Port: 8087)

**Base Path:** `/api/rttm`

#### HTTP Endpoints

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/api/rttm/metrics` | GET | System metrics | `MetricCard[]` |
| `/api/rttm/pipeline` | GET | Pipeline stages | `PipelineStage[]` |
| `/api/rttm/telemetry-snapshot` | GET | Telemetry snapshot | `TelemetrySnapshot` |
| `/api/rttm/dlq` | GET | Dead letter queue data | `DLQResponse` |
| `/api/rttm/alerts` | GET | System alerts | `Alert[]` |

#### WebSocket Endpoints

**Connection:** Direct WebSocket

| Endpoint | Type | Purpose | Message Type |
|----------|------|---------|--------------|
| `/ws/rttm/metrics` | WebSocket | Real-time metrics | `MetricCard[]` |
| `/ws/rttm/pipeline` | WebSocket | Pipeline updates | `PipelineStage[]` |
| `/ws/rttm/telemetry` | WebSocket | Telemetry alerts | `Alert[]` |
| `/ws/rttm/dlq` | WebSocket | DLQ updates | `DLQResponse[]` |
| `/ws/rttm/alerts` | WebSocket | System alerts | `Alert[]` |

**Via API Gateway:**
```
/api/rttm/** → http://pms-rttm:8087/api/rttm/**
/rttm/** → http://pms-rttm:8087/api/rttm/**
```

---

### 6. Simulation Service (Port: 8090)

**Base Path:** `/simulation`

| Endpoint | Method | Purpose | Request Body | Response |
|----------|--------|---------|--------------|----------|
| `/simulation/create-portfolio` | POST | Create simulated portfolio | Simulation config | Portfolio details |

**Via API Gateway:**
```
/simulation/** → http://pms-simulation:8090/simulation/**
```
- Includes rate limiting (5 req/s, burst 10)
- Circuit breaker enabled
- Retry on connection errors

---

## 🔧 API Gateway Configuration

### Rate Limiting
- **Simulation:** 5 requests/sec, burst 10
- **Analytics:** 10 requests/sec, burst 20
- **Leaderboard:** 10 requests/sec, burst 20
- **RTTM:** 10 requests/sec, burst 20

### Circuit Breaker
All routes have circuit breakers configured with fallback to `/fallback` endpoint.

### Retry Policy
- **Simulation:** 1 retry on POST requests
- **Analytics/Leaderboard/RTTM:** 2 retries on GET requests
- Retries on: `ConnectException`, `TimeoutException`

### Timeouts
- **Connect timeout:** 3 seconds
- **Response timeout:** 10 seconds

---

## 🌐 Frontend Configuration

### Environment Variables (Runtime)

The frontend uses runtime configuration injected via Kubernetes ConfigMap (`env.js`):

```javascript
window.__ENV__ = {
  API_GATEWAY_HTTP: "http://<LoadBalancer>:8088",
  API_GATEWAY_WS: "ws://<LoadBalancer>:8088",
  
  AUTH_HTTP: "http://<LoadBalancer>:8088",
  
  PORTFOLIO_HTTP: "http://<LoadBalancer>:8088",
  PORTFOLIO_WS: "ws://<LoadBalancer>:8088",
  
  ANALYTICS_HTTP: "http://<LoadBalancer>:8088",
  ANALYTICS_WS: "ws://<LoadBalancer>:8088",
  
  LEADERBOARD_HTTP: "http://<LoadBalancer>:8088",
  LEADERBOARD_WS: "ws://<LoadBalancer>:8088",
  
  RTTM_HTTP: "http://<LoadBalancer>:8088",
  RTTM_WS: "ws://<LoadBalancer>:8088",
};
```

### Frontend Routes to Backend Services

```
Frontend → API Gateway → Service Mapping:

Analytics:
  /api/analysis/** → Analytics Service
  /api/sectors/** → Analytics Service
  /ws (STOMP) → Analytics Service

Leaderboard:
  /api/leaderboard/** → Leaderboard Service
  /ws/leaderboard/** → Leaderboard Service

RTTM:
  /api/rttm/** → RTTM Service
  /ws/rttm/** → RTTM Service

Portfolio:
  /api/portfolio/** → Portfolio Service
  
Auth:
  /api/auth/** → Auth Service
```

---

## 🧪 Testing Endpoints

### Using the Test Script

```bash
# From pms-infra directory
cd scripts

# Make executable
chmod +x test-endpoints.sh

# Test with local API Gateway
./test-endpoints.sh --gateway-url http://localhost:8088

# Test with Kubernetes LoadBalancer (auto-detected)
./test-endpoints.sh --namespace pms

# Test with custom settings
./test-endpoints.sh \
  --gateway-url http://a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com:8088 \
  --namespace pms \
  --timeout 10
```

### Manual Testing with curl

#### HTTP Endpoints
```bash
# API Gateway
GATEWAY="http://a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com:8088"

# Auth - Login
curl -X POST "$GATEWAY/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'

# Analytics - Get all analysis
curl "$GATEWAY/api/analysis/all"

# Leaderboard - Top performers
curl "$GATEWAY/api/leaderboard/top"

# RTTM - Metrics
curl "$GATEWAY/api/rttm/metrics"

# Portfolio - Get all
curl "$GATEWAY/api/portfolio/all"
```

#### WebSocket Testing with wscat

```bash
# Install wscat
npm install -g wscat

# Test Analytics WebSocket (STOMP)
wscat -c ws://a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com:8088/ws

# After connection, send STOMP CONNECT frame
CONNECT
accept-version:1.2
host:localhost

# Subscribe to position updates
SUBSCRIBE
id:sub-0
destination:/topic/position-update

# Test Leaderboard WebSocket
wscat -c ws://a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com:8088/ws/updates

# Test RTTM WebSocket
wscat -c ws://a3ed40b7b10934382a4b04887e88ef29-164917452.us-east-1.elb.amazonaws.com:8088/ws/rttm/metrics
```

---

## 🔍 Common Issues and Solutions

### Issue: 404 Not Found
**Solution:** Check API Gateway routing configuration. Verify service is running:
```bash
kubectl get pods -n pms
kubectl logs <service-pod> -n pms
```

### Issue: 503 Service Unavailable
**Cause:** Circuit breaker open or backend service down
**Solution:** 
1. Check backend service health
2. Review circuit breaker status
3. Check rate limiting thresholds

### Issue: WebSocket Connection Failed
**Solution:** 
1. Verify WebSocket upgrade headers
2. Check CORS configuration
3. Ensure LoadBalancer supports WebSocket

### Issue: CORS Errors
**Solution:** API Gateway includes CORS headers. Check:
```yaml
default-filters:
  - DedupeResponseHeader=Access-Control-Allow-Origin Access-Control-Allow-Credentials
```

---

## 📊 Endpoint Health Check Summary

| Service | HTTP Port | WS Port | Health Endpoint | Status Check |
|---------|-----------|---------|-----------------|--------------|
| API Gateway | 8088 | 8088 | `/fallback` | Via API Gateway |
| Auth | 8081 | - | `/api/auth/login` | POST test |
| Portfolio | 8095 | - | `/api/portfolio/all` | GET test |
| Analytics | 8086 | 8086 | `/api/analysis/all` | GET test |
| Leaderboard | 8000 | 8000 | `/api/leaderboard/top` | GET test |
| RTTM | 8087 | 8087 | `/api/rttm/metrics` | GET test |
| Simulation | 8090 | - | `/simulation/create-portfolio` | POST test |
| Frontend | 80 | - | `/` | GET test |

---

## 🚀 Next Steps

1. **Run Endpoint Tests:**
   ```bash
   cd /mnt/c/Developer/pms-org/pms-infra/scripts
   ./test-endpoints.sh --namespace pms
   ```

2. **Deploy Frontend to EKS:**
   - See [FRONTEND_EKS_DEPLOYMENT.md](./FRONTEND_EKS_DEPLOYMENT.md)

3. **Monitor Services:**
   ```bash
   kubectl get pods -n pms -w
   kubectl logs -f <pod-name> -n pms
   ```

4. **Access Frontend:**
   - Get LoadBalancer URL:
     ```bash
     kubectl get svc frontend-service -n pms
     ```
   - Open in browser: `http://<frontend-lb-url>`

---

## 📝 Notes

- All services use Kubernetes DNS for internal communication
- External access goes through LoadBalancer services
- Frontend always communicates through API Gateway
- WebSocket connections require HTTP/1.1 upgrade
- STOMP protocol used for Analytics WebSocket messaging

---

**Last Updated:** January 30, 2026
