#!/bin/bash
# Database seeding script for PMS platform
# Usage: ./seed-database.sh

set -e

NAMESPACE="pms"
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')

echo "🌱 Seeding database on pod: $POSTGRES_POD"

kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U pms -d pmsdb <<'EOSQL'
-- Seed portfolio_investor_details
INSERT INTO portfolio_investor_details (portfolio_id, name, phone_number, address) VALUES
('3f2c1d4e-8b57-4a92-9c65-b5e6f4e19b73', 'Portfolio A', 1234567890, 'New York'),
('7a9e3f1c-2b8d-4e6a-a1c5-d7f8e9a4b6c2', 'Portfolio B', 9876543210, 'London'),
('5b1d8f3e-9c4a-4d7e-b2f6-a8c9e1d4f7b3', 'Portfolio C', 5551234567, 'Tokyo'),
('9e4c2a1f-7d6b-4e8c-a3f5-b9d1e7c4a6f2', 'Portfolio D', 4445556666, 'Singapore'),
('1f7e9b3d-5a4c-4e2f-b8d6-c1a9e4f7b3d5', 'Portfolio E', 3334445555, 'Frankfurt')
ON CONFLICT (portfolio_id) DO NOTHING;

-- Seed pms_stocks
INSERT INTO pms_stocks (symbol, sector_name, created_at, updated_at) VALUES
('AAPL', 'TECH', now(), now()),
('GOOGL', 'TECH', now(), now()),
('MSFT', 'TECH', now(), now()),
('AMZN', 'TECH', now(), now()),
('TSLA', 'AUTO', now(), now()),
('JPM', 'FINANCE', now(), now()),
('BAC', 'FINANCE', now(), now()),
('GS', 'FINANCE', now(), now()),
('V', 'FINANCE', now(), now()),
('JNJ', 'HEALTHCARE', now(), now()),
('PFE', 'HEALTHCARE', now(), now()),
('UNH', 'HEALTHCARE', now(), now()),
('XOM', 'ENERGY', now(), now()),
('CVX', 'ENERGY', now(), now()),
('WMT', 'RETAIL', now(), now())
ON CONFLICT (symbol) DO NOTHING;

-- Display results
SELECT COUNT(*) as portfolio_count FROM portfolio_investor_details;
SELECT COUNT(*) as stock_count FROM pms_stocks;
EOSQL

echo "✅ Database seeding completed successfully!"
echo ""
echo "📊 Summary:"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U pms -d pmsdb -c "SELECT COUNT(*) as portfolios FROM portfolio_investor_details;"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U pms -d pmsdb -c "SELECT COUNT(*) as stocks FROM pms_stocks;"
