-- =============================================================================
-- PMS Database Initialization Script
-- =============================================================================
-- Creates all necessary databases and schemas for PMS services
-- This script runs automatically when PostgreSQL container starts for the first time
-- =============================================================================

-- Log initialization start
SELECT 'Starting PMS Database initialization...' AS status;

-- Main database is created by POSTGRES_DB env var (pmsdb)

-- =============================================================================
-- Create Schemas for Different Services
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS trades;
CREATE SCHEMA IF NOT EXISTS portfolios;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS validation;
CREATE SCHEMA IF NOT EXISTS simulation;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS transactional;
CREATE SCHEMA IF NOT EXISTS ingestion;
CREATE SCHEMA IF NOT EXISTS crosscutting;
CREATE SCHEMA IF NOT EXISTS rttm;

-- =============================================================================
-- Grant Permissions to pms User
-- =============================================================================

GRANT ALL PRIVILEGES ON SCHEMA trades TO pms;
GRANT ALL PRIVILEGES ON SCHEMA portfolios TO pms;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO pms;
GRANT ALL PRIVILEGES ON SCHEMA validation TO pms;
GRANT ALL PRIVILEGES ON SCHEMA simulation TO pms;
GRANT ALL PRIVILEGES ON SCHEMA auth TO pms;
GRANT ALL PRIVILEGES ON SCHEMA transactional TO pms;
GRANT ALL PRIVILEGES ON SCHEMA ingestion TO pms;
GRANT ALL PRIVILEGES ON SCHEMA crosscutting TO pms;
GRANT ALL PRIVILEGES ON SCHEMA rttm TO pms;

-- Grant permissions on public schema
GRANT ALL PRIVILEGES ON SCHEMA public TO pms;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO pms;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO pms;

-- =============================================================================
-- Create Extensions (if needed)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- =============================================================================
-- Log Completion
-- =============================================================================

SELECT 'PMS Database initialized successfully!' AS status;
SELECT 'Available schemas: trades, portfolios, analytics, validation, simulation, auth, transactional, ingestion, crosscutting, rttm' AS info;
