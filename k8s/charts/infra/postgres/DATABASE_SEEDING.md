# PostgreSQL Database Seeding

## Overview

The postgres Helm chart includes an automated database seeding solution that populates reference data required by the PMS platform services. This eliminates the need for manual SQL execution after deployment.

## How It Works

The seeding mechanism uses a **Kubernetes Job** with **Helm hooks** that:

1. **Triggers automatically** on `post-install` and `post-upgrade` events
2. **Waits for postgres to be ready** using init containers
3. **Executes SQL statements** to populate reference tables
4. **Is idempotent** - safe to run multiple times (uses `ON CONFLICT DO NOTHING`)
5. **Can be disabled** - controlled via `values.yaml`

## Architecture

```
Helm Install/Upgrade
        ↓
   Hook Triggered (post-install/post-upgrade)
        ↓
   Init Container (wait for postgres:5432)
        ↓
   Main Container (execute SQL statements)
        ↓
   Populate Tables:
     - portfolio_investor_details (5 portfolios)
     - pms_stocks (15 stock symbols)
```

## Tables Populated

### 1. portfolio_investor_details
Used by **validation service** to validate portfolio IDs in trades.

**Columns:**
- `id` (UUID) - Portfolio ID
- `investor_name` (VARCHAR) - Investor name
- `phone_number` (BIGINT) - Contact phone
- `address` (VARCHAR) - Investor address

**Default Data:** 5 portfolios

### 2. pms_stocks
Used by **validation service** to validate stock symbols in trades.

**Columns:**
- `symbol` (VARCHAR) - Stock ticker symbol
- `sector` (VARCHAR) - Industry sector

**Default Data:** 15 stock symbols (AAPL, GOOGL, MSFT, AMZN, TSLA, JPM, BAC, GS, V, JNJ, PFE, UNH, XOM, CVX, WMT)

## Configuration

### Enable/Disable Seeding

In `values.yaml`:

```yaml
seedData:
  enabled: true  # Set to false to disable seeding
```

### Customize Portfolio Data

```yaml
seedData:
  portfolios:
    - id: "3f2c1d4e-8b57-4a92-9c65-b5e6f4e19b73"
      investorName: "Portfolio A"
      phoneNumber: 1234567890
      address: "New York"
    
    # Add more portfolios...
```

### Customize Stock Data

```yaml
seedData:
  stocks:
    - symbol: "AAPL"
      sector: "TECH"
    
    # Add more stocks...
```

## Usage

### Deploy with Default Seed Data

```bash
# From pms-platform umbrella chart
helm upgrade --install pms-platform . -n pms

# Postgres chart is deployed with default reference data
```

### Deploy WITHOUT Seed Data

```bash
# Option 1: Override via command line
helm upgrade --install pms-platform . -n pms \
  --set infra.postgres.seedData.enabled=false

# Option 2: Modify values.yaml before deployment
# In pms-infra/k8s/charts/infra/postgres/values.yaml
# Set: seedData.enabled: false
```

### Add Custom Reference Data

1. **Edit values.yaml:**

```yaml
seedData:
  enabled: true
  portfolios:
    - id: "your-uuid-here"
      investorName: "Custom Portfolio"
      phoneNumber: 1234567890
      address: "Your Location"
  
  stocks:
    - symbol: "CUSTOM"
      sector: "SECTOR"
```

2. **Redeploy:**

```bash
helm upgrade pms-platform . -n pms
```

The job will re-run and insert new data (existing data remains due to `ON CONFLICT DO NOTHING`).

## Verification

### Check Job Status

```bash
# List all jobs in pms namespace
kubectl get jobs -n pms | grep seed

# Expected output:
# pms-platform-postgres-seed-data   1/1           5s         2m
```

### Check Job Logs

```bash
# Get pod name
kubectl get pods -n pms | grep seed-data

# View logs
kubectl logs pms-platform-postgres-seed-data-xxxxx -n pms
```

**Expected output:**
```
INSERT 0 5
INSERT 0 15
Database seeding completed successfully!
```

### Verify Data in Database

```bash
# Connect to postgres pod
kubectl exec -it deployment/postgres -n pms -- psql -U pms -d pmsdb

# Check portfolios
SELECT COUNT(*) FROM portfolio_investor_details;
# Expected: 5

# Check stocks
SELECT COUNT(*) FROM pms_stocks;
# Expected: 15

# View data
SELECT * FROM portfolio_investor_details;
SELECT * FROM pms_stocks;

# Exit
\q
```

## Troubleshooting

### Job Fails - "relation does not exist"

**Cause:** Tables not created yet by application services.

**Solution:** The portfolio and validation services create these tables on startup. Ensure those services have run at least once with `DB_DDL_AUTO=update` or `DB_DDL_AUTO=create`.

```bash
# Check portfolio service logs
kubectl logs deployment/portfolio -n pms | grep "Creating table"

# Check validation service logs
kubectl logs deployment/validation -n pms | grep "Creating table"
```

### Job Completes But No Data

**Cause 1:** Seeding disabled in values.yaml

```bash
# Check if enabled
helm get values pms-platform -n pms | grep -A5 seedData
```

**Cause 2:** Job ran before tables existed, then tables created but job didn't re-run

**Solution:** Manually trigger the job or redeploy:

```bash
# Delete and let Helm recreate
kubectl delete job pms-platform-postgres-seed-data -n pms
helm upgrade pms-platform . -n pms
```

### Want to Clear and Re-seed

```bash
# Connect to database
kubectl exec -it deployment/postgres -n pms -- psql -U pms -d pmsdb

# Clear existing data
DELETE FROM portfolio_investor_details;
DELETE FROM pms_stocks;
\q

# Re-run the job
kubectl delete job pms-platform-postgres-seed-data -n pms
helm upgrade pms-platform . -n pms
```

### Job Never Completes

**Cause:** Init container waiting for postgres

**Check:**
```bash
kubectl logs pms-platform-postgres-seed-data-xxxxx -n pms -c wait-for-postgres
```

**Solution:** Ensure postgres service is accessible:
```bash
kubectl get svc postgres -n pms
kubectl exec -it deployment/postgres -n pms -- pg_isready
```

## Best Practices

### Development Environment
- Keep `seedData.enabled: true` for local development
- Use default portfolios and stocks for testing
- Helps quickly spin up new environments

### Staging Environment
- Keep `seedData.enabled: true`
- May want to use production-like data
- Customize portfolios and stocks in values.yaml

### Production Environment
- Set `seedData.enabled: false`
- Load real data via migration scripts or application APIs
- Reference data should come from authoritative sources

### CI/CD Pipelines
```bash
# Dev/Test deployments
helm upgrade --install pms-platform . -n pms \
  --set infra.postgres.seedData.enabled=true

# Production deployments
helm upgrade --install pms-platform . -n pms \
  --set infra.postgres.seedData.enabled=false
```

## Impact on Services

### Validation Service
**Critical dependency** - without this seed data:
- All trades fail validation (0% valid trade rate)
- Invalid trades rate approaches 100%
- No data flows to transactional service

**With seed data:**
- ~70-85% valid trade rate (depending on simulation randomness)
- ~30 valid trades per minute
- Healthy Kafka flow to downstream services

### Simulation Service
**Indirect dependency** - generates random trades using:
- Portfolio IDs from the seeded data (5 options)
- Stock symbols from the seeded data (15 options)

If simulation uses IDs/symbols not in seed data → all trades invalid.

### Portfolio Service
**Creates the table** - must run before seeding job:
```java
// application.yaml
spring.jpa.hibernate.ddl-auto: ${DB_DDL_AUTO:update}
```

Helm values must have:
```yaml
env:
  DB_DDL_AUTO: "update"  # or "create"
```

### Transactional Service
**Downstream consumer** - relies on valid trades from validation service. Without seed data, receives no messages.

## Migration from Manual Seeding

### Old Approach (Manual)
```bash
# Had to manually run SQL after every deployment
kubectl exec -it deployment/postgres -n pms -- psql -U pms -d pmsdb

INSERT INTO portfolio_investor_details VALUES
  ('3f2c1d4e-8b57-4a92-9c65-b5e6f4e19b73', 'Portfolio A', ...);
# ... repeat for all portfolios and stocks
```

**Problems:**
- Error-prone (typos, missing entries)
- Not tracked in version control
- Requires manual intervention after every deploy
- Easy to forget in new environments

### New Approach (Automated)
```bash
# Deploy once, seed data included automatically
helm upgrade --install pms-platform . -n pms

# Data defined in values.yaml (version controlled)
# Runs automatically on install/upgrade
# Idempotent and safe
```

## Technical Details

### Helm Hook Annotations
```yaml
annotations:
  "helm.sh/hook": post-install,post-upgrade
  "helm.sh/hook-weight": "5"
  "helm.sh/hook-delete-policy": before-hook-creation
```

- **post-install:** Runs after postgres deployment on first install
- **post-upgrade:** Runs after postgres deployment on upgrades
- **hook-weight:** Executes after postgres is deployed (weight 0)
- **delete-policy:** Deletes old job before creating new one

### Init Container
```yaml
initContainers:
- name: wait-for-postgres
  image: busybox:1.36
  command:
    - sh
    - -c
    - |
      until nc -z postgres.pms.svc.cluster.local 5432; do
        echo "Waiting for postgres..."
        sleep 2
      done
```

Uses `nc` (netcat) to verify postgres port 5432 is accessible before proceeding.

### SQL Idempotency
```sql
INSERT INTO portfolio_investor_details (id, investor_name, phone_number, address)
VALUES ('...', '...', ..., '...')
ON CONFLICT (id) DO NOTHING;
```

The `ON CONFLICT DO NOTHING` clause ensures:
- First run: Inserts all data
- Subsequent runs: Skips existing records
- No errors on duplicate keys
- Safe to run multiple times

## Files Modified

```
pms-infra/k8s/charts/infra/postgres/
├── templates/
│   └── seed-data-job.yaml        # NEW - Kubernetes Job with SQL
├── values.yaml                    # MODIFIED - Added seedData section
└── DATABASE_SEEDING.md           # NEW - This documentation
```

## Related Documentation

- Main deployment guide: `/mnt/c/Developer/pms-org/DEPLOYMENT_SUMMARY.md`
- Quick reference: `/mnt/c/Developer/pms-org/QUICK_REFERENCE.md`
- Postgres chart: `/mnt/c/Developer/pms-org/pms-infra/k8s/charts/infra/postgres/`

## Summary

The automated database seeding solution:
- ✅ Eliminates manual SQL execution
- ✅ Version controlled in values.yaml
- ✅ Automatically runs on deploy
- ✅ Idempotent and safe
- ✅ Easy to customize
- ✅ Can be disabled for production
- ✅ Critical for validation service functionality

This ensures consistent reference data across all environments and prevents the "no valid trades" issue that plagued the initial deployment.
