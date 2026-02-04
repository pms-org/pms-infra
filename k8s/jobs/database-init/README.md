# PMS Database Schema Initialization

This directory contains scripts and Kubernetes jobs to initialize all database schemas for the PMS (Portfolio Management System) application.

## Files

- **`init-all-schemas.sql`** - Complete SQL script for manual execution
- **`init-all-schemas-job.yaml`** - Kubernetes Job for automated schema initialization

## What Gets Created

### 1. Simulation Schema (Reference Data)
- `portfolio_id` - Portfolio reference table
- `symbol` - Stock symbol reference table

**Seed Data:**
- 5 Portfolio IDs
- 15 Stock Symbols (AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA, NFLX, AMD, INTC, IBM, ORCL, BAC, JPM, WMT)

### 2. Validation Schema
- `validation_invalid_trades` - Invalid trade records
- `validation_processed_messages` - Idempotency tracking
- `pms_stocks` - Stock information
- `validation_outbox` - Valid trades outbox
- `validation_dlq_entry` - Dead letter queue

### 3. Transactional Schema
- `transaction` - Processed transactions
- `transactional_outbox` - Transaction events outbox
- `transactional_processed_messages` - Idempotency tracking
- `transactional_dlq_entry` - Dead letter queue

### 4. RTTM Schema
- `rttm_portfolio_positions` - Real-time portfolio positions
- `rttm_invalid_trades` - Invalid trade records
- `rttm_processed_messages` - Idempotency tracking
- `rttm_trade_events` - Trade event tracking
- `rttm_error_events` - Error tracking
- `rttm_dlq_events` - Dead letter queue
- `rttm_queue_metrics` - Queue monitoring
- `rttm_stage_latency` - Performance metrics
- `rttm_alerts` - Alert management

### 5. Analytics Schema
- `analytics` - Analytics data
- `analytics_outbox` - Analytics events outbox
- `analytics_portfolio_value_history` - Portfolio value over time
- `analytics_portfolio_risk_status` - Risk assessments

### 6. Performance Indexes
Automatically creates indexes on frequently queried columns for:
- Portfolio IDs
- Symbols
- Timestamps
- Status fields

## Usage

### Option 1: Kubernetes Job (Recommended)

This is the recommended approach as it runs from within the cluster and has direct access to RDS.

```bash
# Apply the job
kubectl apply -f init-all-schemas-job.yaml

# Wait for completion
kubectl wait --for=condition=complete job/init-all-schemas -n pms --timeout=120s

# Check logs
kubectl logs -n pms job/init-all-schemas

# Clean up the job (optional)
kubectl delete job init-all-schemas -n pms
```

### Option 2: Manual SQL Execution

For local execution or troubleshooting:

```bash
# From within the cluster (using a psql pod)
kubectl run psql-temp -n pms --image=postgres:16 --rm -it -- bash
export PGHOST=postgres
export PGPORT=5432
export PGDATABASE=pmsdb
export PGUSER=pmsadmin
export PGPASSWORD='<password>'

# Copy and paste the SQL script content or mount it as a volume
psql < init-all-schemas.sql
```

### Option 3: Using pgAdmin

1. Access pgAdmin: http://k8s-pms-pgadmin-<hash>.elb.us-east-1.amazonaws.com
2. Login with credentials
3. Open Query Tool for the PMS database
4. Copy and paste the contents of `init-all-schemas.sql`
5. Execute the script

## Verification

After running the initialization, verify the results:

```bash
# Check table counts
kubectl run psql-verify -n pms --image=postgres:16 --rm -it -- \
  psql postgresql://pmsadmin:<password>@postgres:5432/pmsdb \
  -c "SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"

# Check reference data
kubectl run psql-verify -n pms --image=postgres:16 --rm -it -- \
  psql postgresql://pmsadmin:<password>@postgres:5432/pmsdb \
  -c "SELECT 'Portfolios' as type, COUNT(*) FROM portfolio_id UNION ALL SELECT 'Symbols', COUNT(*) FROM symbol;"
```

Expected output:
- 5 Portfolio IDs
- 15 Symbols
- 35+ tables created

## Important Notes

1. **Idempotent**: The script uses `CREATE TABLE IF NOT EXISTS` and `ON CONFLICT DO NOTHING`, so it's safe to run multiple times.

2. **No Data Loss**: Existing tables and data are preserved. Only missing tables are created.

3. **Connection**: The Kubernetes job uses the ExternalName service `postgres` which points to the RDS instance.

4. **Secrets**: Database credentials are pulled from the `pms-global-secrets` Kubernetes secret.

5. **Cleanup**: The job automatically deletes itself 5 minutes after completion (ttlSecondsAfterFinished: 300).

## Switching to Main Database

When switching from dev to main/production database:

1. **Update the RDS endpoint** in Terraform or values.yaml
2. **Update the ExternalName service** to point to the new RDS instance
3. **Run the initialization job**:
   ```bash
   kubectl apply -f init-all-schemas-job.yaml
   kubectl wait --for=condition=complete job/init-all-schemas -n pms --timeout=120s
   kubectl logs -n pms job/init-all-schemas
   ```
4. **Verify the schemas** were created successfully
5. **Restart services** if needed to clear any cached connections

## Troubleshooting

### Job fails with connection timeout
- Check if the ExternalName service `postgres` is configured correctly
- Verify RDS security group allows connections from EKS
- Check if RDS is in the correct VPC/subnets

### Job fails with authentication error
- Verify `pms-global-secrets` contains correct `DB_USERNAME` and `DB_PASSWORD`
- Check AWS Secrets Manager has the correct credentials
- Ensure External Secrets Operator has synced the secrets

### Job completes but tables are missing
- Check the job logs: `kubectl logs -n pms job/init-all-schemas`
- Look for SQL errors in the output
- Verify database permissions for the user

### Need to re-run the job
```bash
# Delete the old job
kubectl delete job init-all-schemas -n pms

# Re-apply
kubectl apply -f init-all-schemas-job.yaml
```

## Migration from Old Schema

If you have existing data in old table structures, you'll need to:

1. Backup existing data
2. Create migration scripts to transform data
3. Load data into new schema
4. Verify data integrity

Contact the development team for migration assistance.
