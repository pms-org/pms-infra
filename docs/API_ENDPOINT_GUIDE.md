# PMS API Endpoint Access Guide

**Date:** February 8, 2026  
**Load Balancer:** `http://k8s-pms-pmsingre-ba04040d46-1513529560.us-east-1.elb.amazonaws.com`

## Overview

This guide explains how to access the PMS platform endpoints, including authentication requirements and usage examples.

---

## 🔐 Authentication

### Two Token Types

#### 1. USER Token

- **Use Case:** End-user facing APIs (logged-in users)
- **How to Get:** Login with username/password
- **Valid For:** 1 hour
- **Token Type Claim:** `"token_type": "USER"`

#### 2. SERVICE Token

- **Use Case:** Service-to-service communication
- **How to Get:** OAuth2 client credentials flow
- **Valid For:** Configured expiry
- **Token Type Claim:** `"token_type": "SERVICE"`

---

## 📍 Exposed Endpoints

### Authentication Endpoints (Public - No Token Required)

#### Login (Get USER Token)

```bash
POST /api/auth/login
Content-Type: application/json

{
  "username": "testuser",
  "password": "password123"
}

# Response
{
  "accessToken": "eyJraWQiOi...",
  "tokenType": "Bearer",
  "expiresIn": 3600
}
```

#### Signup (Register New User)

```bash
POST /api/auth/signup
Content-Type: application/json

{
  "username": "newuser",
  "password": "securepassword"
}
```

---

### Portfolio Service (USER Token Required)

#### Get All Portfolios

```bash
GET /api/portfolio/all
Authorization: Bearer {USER_TOKEN}
```

**Response:** List of portfolios

```json
[
  {
    "portfolioId": "f6a225cc-c28a-4b6c-aecf-1fa00bc8255c",
    "name": "John Doe",
    "phoneNumber": 9898123456,
    "address": "New York"
  }
]
```

#### Get Portfolio by ID

```bash
GET /api/portfolio/{id}
Authorization: Bearer {USER_TOKEN}
```

#### Create Portfolio

```bash
POST /api/portfolio/create
Authorization: Bearer {USER_TOKEN}
Content-Type: application/json

{
  "name": "John Doe",
  "phoneNumber": "555-1234",
  "address": "123 Main St, New York, NY"
}
```

---

### Simulation Service (USER Token Required)

```bash
POST /simulation/**
Authorization: Bearer {USER_TOKEN}
Content-Type: application/json

{
  // Simulation request payload
}
```

---

### Other Services (USER Token Required)

- **Leaderboard:** `/api/leaderboard/**`
- **RTTM:** `/api/rttm/**`
- **Analytics:** `/api/analysis/**`, `/api/sectors/**`, `/api/transactions/**`
- **Portfolio Value:** `/api/portfolio_value/**`
- **Unrealized P&L:** `/api/unrealized/**`

---

## 🔧 Usage Examples

### cURL Examples

#### 1. Login and Get Token

```bash
# Get USER token
TOKEN=$(curl -s -X POST "http://k8s-pms-pmsingre-ba04040d46-1513529560.us-east-1.elb.amazonaws.com/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}' \
  | jq -r '.accessToken')

echo "Token: $TOKEN"
```

#### 2. Use Token to Access Protected Endpoint

```bash
# Get all portfolios
curl -X GET "http://k8s-pms-pmsingre-ba04040d46-1513529560.us-east-1.elb.amazonaws.com/api/portfolio/all" \
  -H "Authorization: Bearer $TOKEN"

# Create a portfolio
curl -X POST "http://k8s-pms-pmsingre-ba04040d46-1513529560.us-east-1.elb.amazonaws.com/api/portfolio/create" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Jane Smith",
    "phoneNumber": "555-5678",
    "address": "456 Park Ave, NY"
  }'
```

---

## 📮 Postman Setup

### Environment Variables

Create a Postman environment with:

```
base_url: http://k8s-pms-pmsingre-ba04040d46-1513529560.us-east-1.elb.amazonaws.com
access_token: (auto-populated by pre-request script)
```

### Pre-request Script for USER Token

**Collection/Folder Level - Add this to auto-fetch USER tokens:**

```javascript
// Check if token exists and is not expired
const currentToken = pm.environment.get("access_token");
const tokenExpiry = pm.environment.get("token_expiry");

const now = Date.now();
const shouldRefresh = !currentToken || !tokenExpiry || now >= tokenExpiry;

if (shouldRefresh) {
  pm.sendRequest(
    {
      url: pm.environment.get("base_url") + "/api/auth/login",
      method: "POST",
      header: {
        "Content-Type": "application/json",
      },
      body: {
        mode: "raw",
        raw: JSON.stringify({
          username: "testuser",
          password: "password123",
        }),
      },
    },
    function (err, res) {
      if (err || res.code !== 200) {
        console.error("❌ Login Failed!", err || res.json());
      } else {
        const response = res.json();
        pm.environment.set("access_token", response.accessToken);
        pm.environment.set(
          "token_expiry",
          Date.now() + response.expiresIn * 1000,
        );
        console.log("✅ USER Token fetched successfully!");
      }
    },
  );
}
```

### Pre-request Script for SERVICE Token

**For service-to-service calls (currently only `/portfolio/**` without /api):\*\*

```javascript
const config = {
  url: pm.environment.get("base_url") + "/oauth2/token",
  clientId: "service-client",
  clientSecret: "service-secret",
  scope: "service.read",
};

pm.environment.unset("service_token");

const authHeader = "Basic " + btoa(config.clientId + ":" + config.clientSecret);

pm.sendRequest(
  {
    url: config.url,
    method: "POST",
    header: {
      Authorization: authHeader,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: {
      mode: "urlencoded",
      urlencoded: [
        { key: "grant_type", value: "client_credentials" },
        { key: "scope", value: config.scope },
      ],
    },
  },
  function (err, res) {
    if (err || res.code !== 200) {
      console.error("❌ Auth Failed! Status:", res.code);
      console.log("Response:", res.json());
    } else {
      const token = res.json().access_token;
      pm.environment.set("service_token", token);
      console.log("✅ SERVICE Token fetched and saved!");
    }
  },
);
```

### Request Authorization

In your Postman requests:

1. Go to **Authorization** tab
2. Select **Type:** Bearer Token
3. **Token:** `{{access_token}}` (for USER endpoints)
4. **Token:** `{{service_token}}` (for SERVICE endpoints)

---

## 🔒 Security Configuration Summary

### API Gateway Security Rules

```yaml
Public Endpoints (No Auth):
  - /api/auth/**
  - /actuator/**
  - /ws/** (WebSocket handshake)
  - OPTIONS /** (CORS preflight)

SERVICE Token Required:
  - /portfolio/** (without /api prefix)

USER Token Required:
  - /simulation/**
  - /api/portfolio/**
  - /api/leaderboard/**
  - /api/rttm/**
  - /api/analysis/**
  - /api/sectors/**
  - /api/portfolio_value/**
  - /api/transactions/**
  - /api/unrealized/**
  - Legacy routes: /leaderboard/**, /rttm/**, /analytics/**, etc.
```

---

## 🐛 Troubleshooting

### Common Issues

#### 401 Unauthorized

- **Cause:** Missing or invalid token
- **Solution:** Ensure you're using a valid token and it hasn't expired

#### 403 Forbidden

- **Cause:** Wrong token type (USER vs SERVICE)
- **Solution:** Check if endpoint requires USER or SERVICE token

#### 500 Internal Server Error

- **Cause:** Backend service error
- **Solution:** Check service logs with:
  ```bash
  kubectl logs -n pms <pod-name> --tail=50
  ```

#### Token Expired

- **Solution:** Re-authenticate to get a new token
- USER tokens expire in 1 hour

### Verify Token Type

Decode your JWT token at [jwt.io](https://jwt.io) and check the `token_type` claim:

- Should be `"USER"` for user endpoints
- Should be `"SERVICE"` for service-to-service calls

---

## 📊 Architecture

```
Internet → ALB (Port 80)
           ↓
       Ingress (pms-ingress)
           ↓
    ┌──────────────────┐
    │   API Gateway    │ ← Security checks here
    │   (Port 8088)    │
    └──────────────────┘
           ↓
    ┌──────────┬───────────┬────────────┐
    │          │           │            │
  Frontend  Portfolio  Simulation   Other
  (Port 80) (Port 8095) (Port 8090) Services
```

---

## 📝 Notes

1. **Current Status:** API Gateway successfully updated with new security configuration
2. **Image Repository:** Updated to use `nehanawork1/pms-apigateway:latest`
3. **Deployment:** Deployed via Helm chart `pms-platform`
4. **Known Issue:** `/api/portfolio/create` endpoint returns 500 error (application-level issue, not security/routing)

---

## 🔄 Recent Changes

- **Feb 8, 2026:** Exposed `/simulation/**` and `/api/portfolio/**` for USER tokens
- **Feb 8, 2026:** Updated API Gateway image repository to `nehanawork1`
- **Feb 8, 2026:** Deployed via Helm upgrade

---

## 📞 Support

For issues or questions:

1. Check pod logs: `kubectl logs -n pms <pod-name>`
2. Check API Gateway logs for routing issues
3. Verify security configuration in [SecurityConfig.java](../../pms-apigateway/src/main/java/com/example/apigateway/config/SecurityConfig.java)
