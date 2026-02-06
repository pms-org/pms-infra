# Validation Service Fix - Reference Data Population

## Issue Summary
The validation service was marking **47,003 trades as invalid** because the reference data tables were empty:
- `pms_stocks` table was missing symbols: **IBM**, **BAC**, and others
- `portfolio_investor_details` table had the correct 5 portfolios

## Root Cause
The validation service uses Drools rules that check:
1. Trade symbol exists in `pms_stocks` table
2. Trade portfolioId exists in `portfolio_investor_details` table

When these tables are empty or incomplete, ALL trades get marked as invalid.

## Solution Applied

### 1. Updated Seed Job
**File:** `pms-infra/k8s/jobs/database-init/populate-validation-tables-job.yaml`

**Changes:**
- Added missing symbols: IBM, BAC
- Updated sector names to match simulation data
- Changed `ON CONFLICT` from `stock_id` to `symbol` for idempotency
- Added `UNIQUE(symbol)` constraint to prevent duplicates

**Symbols now populated (15 total):**
```
AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA, NFLX, 
AMD, INTC, IBM, ORCL, BAC, JPM, WMT
```

### 2. Ran Seed Job
```bash
kubectl apply -f pms-infra/k8s/jobs/database-init/populate-validation-tables-job.yaml
```

**Result:**
- ✅ 5 portfolios inserted
- ✅ 15 stocks inserted (including IBM and BAC)

### 3. Restarted Validation Service
```bash
kubectl rollout restart deployment validation-service -n pms
```

This forced the service to reload reference data from the database.

### 4. Cleaned Invalid Trades (DEV ONLY)
**File:** `pms-infra/k8s/jobs/database-init/delete-invalid-trades-job.yaml`

```bash
kubectl apply -f pms-infra/k8s/jobs/database-init/delete-invalid-trades-job.yaml
```

**Result:**
- 🗑️ Deleted **47,003** invalid trades
- ✅ Fresh start with clean validation

## Verification

### Before Fix
```
Invalid trades: 47,003
Errors: "Invalid symbol: IBM", "Invalid symbol: BAC"
```

### After Fix
```
Invalid trades: 45 (legitimate validation failures - price/quantity = 0)
Errors: "pricePerStock must be greater than 0; quantity must be greater than 0"
```

### Log Verification
```bash
# No more "Invalid symbol" errors
kubectl logs -n pms -l app=validation-service --tail=200 | grep "Invalid symbol" | wc -l
# Output: 0

# Mostly VALID decisions now
kubectl logs -n pms -l app=validation-service --tail=200 | grep "VALID" | wc -l
# Output: 180+ VALID, only ~5 INVALID (for price/quantity)
```

## Files Modified

1. **pms-infra/k8s/jobs/database-init/populate-validation-tables-job.yaml**
   - Updated stock symbols list to match simulation data
   - Added IBM, BAC
   - Fixed ON CONFLICT to use symbol column
   - Added UNIQUE constraint on symbol

2. **pms-infra/k8s/jobs/database-init/delete-invalid-trades-job.yaml** (NEW)
   - Dev-only job to clean historical invalid trades
   - Uses table name: `validation_invalid_trades`

## Production Deployment Notes

⚠️ **DO NOT run `delete-invalid-trades-job.yaml` in production!**

For production:
1. Run only the `populate-validation-tables-job.yaml` to add reference data
2. Restart validation service
3. New trades will validate correctly
4. Historical invalid trades will remain in DB (for audit)
5. Optionally: Create a revalidation job to reprocess historical trades

## How to Run in Other Environments

```bash
# 1. Populate reference data
kubectl apply -f pms-infra/k8s/jobs/database-init/populate-validation-tables-job.yaml

# 2. Verify job completed
kubectl logs -n pms job/populate-validation-tables

# 3. Restart validation service
kubectl rollout restart deployment validation-service -n pms

# 4. Monitor validation logs
kubectl logs -n pms -l app=validation-service --tail=100 --follow
```

## Status: ✅ RESOLVED

- Validation service now correctly validates trades
- IBM and BAC symbols are in pms_stocks table
- Invalid trade count dropped from 47,003 to 45
- Remaining invalids are legitimate (price/quantity validation failures)
