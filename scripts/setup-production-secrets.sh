#!/bin/bash
# setup-production-secrets.sh
# Script to set up production secrets in AWS Secrets Manager
# NOTE: Update the placeholder values with your actual credentials before running

set -e

# Set AWS region - UPDATE THIS
export AWS_REGION=<YOUR_AWS_REGION>

echo "Setting up production secrets for PMS..."
echo "⚠️  WARNING: Update the placeholder values in this script with your actual credentials!"
echo ""

# Create production database secret - UPDATE THESE VALUES
echo "Creating production database secret..."
aws secretsmanager create-secret \
  --name pms/database/prod \
  --description "RDS PostgreSQL credentials for PMS production" \
  --secret-string '{
    "username": "<YOUR_DB_USERNAME>",
    "password": "<YOUR_DB_PASSWORD>",
    "host": "<YOUR_RDS_ENDPOINT>",
    "port": "5432",
    "dbname": "<YOUR_DB_NAME>",
    "engine": "postgres"
  }'

echo "✅ Production database secret created successfully!"
echo ""
echo "📝 Note: RabbitMQ credentials need to be configured separately."
echo "   Update the RabbitMQ secret at: pms/rabbitmq/prod"
echo ""
echo "🔧 To deploy to production:"
echo "   kubectl apply -k environments/prod/"
echo ""
echo "Production secrets setup complete!"