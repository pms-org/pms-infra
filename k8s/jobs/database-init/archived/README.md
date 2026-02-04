# Archived Database Initialization Scripts

These scripts are **deprecated** and kept for reference only.

## Deprecated Files

- **`init-rds-schemas-job.yaml`** - Old Kubernetes job (replaced by `../init-all-schemas-job.yaml`)
- **`init-rds-schemas.sql`** - Old SQL script (replaced by `../sql/init-all-schemas.sql`)
- **`init-rds.sh`** - Old bash script for local execution (replaced by Kubernetes job approach)

## Why Deprecated?

These initial versions were created during development and had limitations:
- Limited schema coverage
- Missing RTTM monitoring tables
- No performance indexes
- Less comprehensive error handling

## Current Solution

Use the files in the parent directory:
- `../init-all-schemas-job.yaml` - Complete Kubernetes job
- `../sql/init-all-schemas.sql` - Complete SQL script
- `../run-schema-init.sh` - Helper script for easy execution

See `../README.md` for usage instructions.
