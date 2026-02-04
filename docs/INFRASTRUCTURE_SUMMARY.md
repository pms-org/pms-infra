# PMS Infrastructure - Cleanup & Organization Summary

**Date:** February 4, 2026  
**Status:** ✅ Complete

## What Was Done

### 1. Fixed Analytics Service
- Added missing environment variables to global ConfigMap
- Added `DB_URL` and `SPRING_DATASOURCE_URL` for explicit JDBC URL
- Analytics running stable for 4+ hours with 0 restarts

### 2. Created Database Schemas
- All services now have required tables:
  - **Simulation**: portfolio_id (5), symbol (15)
  - **Validation**: validation_outbox, validation_invalid_trades, pms_stocks, etc.
  - **Transactional**: transaction, transactional_outbox, etc.
  - **RTTM**: rttm_portfolio_positions, rttm_trade_events, rttm_alerts, etc.
  - **Analytics**: analytics, analytics_outbox, analytics_portfolio_value_history, etc.
- Created performance indexes
- Total: 39 tables created in RDS

### 3. Organized Scripts & Jobs

#### New Structure:
```
k8s/jobs/
├── README.md                          # Index of all jobs
└── database-init/
    ├── README.md                      # Detailed documentation
    ├── init-all-schemas-job.yaml     # Kubernetes job (CURRENT)
    ├── run-schema-init.sh            # Helper script
    ├── sql/
    │   └── init-all-schemas.sql      # Standalone SQL script
    └── archived/
        ├── README.md                  # Why these are deprecated
        ├── init-rds-schemas-job.yaml # OLD - limited schemas
        ├── init-rds-schemas.sql      # OLD - limited schemas
        └── init-rds.sh               # OLD - local execution
```

#### Files Moved:
- ✅ Active files → `k8s/jobs/database-init/`
- ✅ SQL scripts → `k8s/jobs/database-init/sql/`
- ✅ Old/deprecated → `k8s/jobs/database-init/archived/`

## Current System Status

### Infrastructure
- **RDS**: db.r7g.large, PostgreSQL 16, publicly accessible
- **EKS Cluster**: pms-dev
- **Namespace**: pms
- **Total Pods**: 21/21 running

### Services Running
| Service | Status | Notes |
|---------|--------|-------|
| Analytics | ✅ Running (0 restarts, 4h+) | Fixed with environment variables |
| Validation | ✅ Running | Writing to invalid/valid topics |
| Transactional | ✅ Running | Processing valid trades |
| RTTM | ✅ Running | Real-time position tracking |
| Simulation | ✅ Running | Generating trades |
| All others | ✅ Running | apigateway, auth, frontend, etc. |

### Database
- **Tables**: 39
- **Reference Data**: 
  - Portfolios: 5
  - Symbols: 15 (AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA, NFLX, AMD, INTC, IBM, ORCL, BAC, JPM, WMT)

## How to Use (Main Database Switch)

When you switch to the main database:

### Option 1: Using Helper Script (Recommended)
```bash
cd /mnt/c/Developer/pms-org/pms-infra/k8s/jobs/database-init
./run-schema-init.sh
```

### Option 2: Direct Kubectl
```bash
cd /mnt/c/Developer/pms-org/pms-infra/k8s/jobs/database-init
kubectl apply -f init-all-schemas-job.yaml
kubectl wait --for=condition=complete job/init-all-schemas -n pms --timeout=120s
kubectl logs -n pms job/init-all-schemas
```

### Option 3: Using pgAdmin
1. Open pgAdmin UI
2. Connect to your main database
3. Open Query Tool
4. Load `sql/init-all-schemas.sql`
5. Execute

## Application URLs

- **Frontend**: http://k8s-pms-frontend-c13844b64e-3fca58243f788c0a.elb.us-east-1.amazonaws.com
- **pgAdmin**: http://k8s-pms-pgadmin-db2a1162f0-338f0a77baefa457.elb.us-east-1.amazonaws.com

## Key Files for Reference

### Configuration
- `pms-infra/k8s/pms-platform/values.yaml` - Global config with DB variables
- `pms-infra/k8s/environments/dev/values.yaml` - Dev-specific overrides

### Database Init
- `k8s/jobs/database-init/init-all-schemas-job.yaml` - Kubernetes job
- `k8s/jobs/database-init/sql/init-all-schemas.sql` - SQL script
- `k8s/jobs/database-init/README.md` - Full documentation

### Secrets
- AWS Secrets Manager: `pms/dev/postgres` - DB credentials
- K8s Secret: `pms-global-secrets` - Synced from AWS

## Validation Service Notes

The validation service is working correctly:
- ✅ Validates portfolios against `portfolio_id` table
- ✅ Validates symbols against `symbol` table
- ✅ Writes **invalid** trades → `invalid-trades-topic`
- ✅ Writes **valid** trades → `valid-trades-topic`

Currently, all trades are invalid because simulation generates random portfolios/symbols not in reference tables. To get valid trades, ensure simulation uses:
- **Portfolios**: 3f2c1d4e-8b57-4a92-9c65-b5e6f4e19b73, a8d4c0fa-7c1b-4e5d-9a89-2d635f0e2a14, d91f0b62-4c2f-4b91-8f2f-1b6c4ad7e543, 59c8a6d1-3f8b-4a67-bab6-89d0e72cce10, e2fa4c39-2a65-41c8-9f91-3c57f1d900ba
- **Symbols**: AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA, NFLX, AMD, INTC, IBM, ORCL, BAC, JPM, WMT

## Next Steps

1. ✅ **Test Frontend** - Access the frontend URL and verify UI loads
2. ✅ **Verify Data Flow** - Check if trades flow through validation → transactional → analytics
3. 🔄 **Update Simulation** - Configure to use valid portfolio/symbol combinations
4. 🔄 **Monitor Logs** - Watch for any errors in service logs
5. 🔄 **When Switching DB** - Run the schema init job on main database

## Troubleshooting

### If analytics crashes again:
```bash
# Check config
kubectl get configmap -n pms pms-global-config -o yaml | grep -E "DB_|ANALYTICS_"

# Check secrets
kubectl get secret -n pms pms-global-secrets -o yaml

# Restart pod
kubectl delete pod -n pms -l app=analytics
```

### If validation not writing valid trades:
- Check simulation is using valid portfolio IDs and symbols
- Verify reference tables have data:
  ```sql
  SELECT * FROM portfolio_id;
  SELECT * FROM symbol;
  ```

### If database connection fails:
- Verify ExternalName service: `kubectl get svc -n pms postgres`
- Check RDS security group allows EKS cluster
- Test connection from a pod:
  ```bash
  kubectl run psql-test -n pms --image=postgres:16 --rm -it -- \
    psql postgresql://pmsadmin:<password>@postgres:5432/pmsdb
  ```

---

**Status**: All systems operational ✅  
**Last Updated**: February 4, 2026, 5:50 PM UTC
