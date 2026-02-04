#!/bin/bash

# RDS Connection Details
export PGHOST="pms-dev-postgres.cab8eqka4smp.us-east-1.rds.amazonaws.com"
export PGPORT="5432"
export PGDATABASE="pmsdb"
export PGUSER="pmsadmin"
export PGPASSWORD='SyQXkSq{GPc7_O9z8hu}DlwX:I:GP<Cf'

echo "======================================"
echo "Initializing PMS RDS Database Schemas"
echo "======================================"
echo "Host: $PGHOST"
echo "Database: $PGDATABASE"
echo "User: $PGUSER"
echo ""

# Execute the schema initialization script
echo "Executing schema creation script..."
psql -f /mnt/c/Developer/pms-org/pms-infra/scripts/init-rds-schemas.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database schemas initialized successfully!"
else
    echo ""
    echo "❌ Failed to initialize database schemas"
    exit 1
fi
