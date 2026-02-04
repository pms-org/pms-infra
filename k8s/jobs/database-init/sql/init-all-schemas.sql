-- ============================================
-- PMS Database Complete Schema Initialization
-- ============================================
-- This script creates all database schemas for the PMS application
-- Services: Simulation, Validation, Transactional, RTTM, Analytics
-- 
-- Usage:
--   psql -U pmsadmin -d pmsdb -f init-all-schemas.sql
-- ============================================

\echo '=========================================='
\echo 'PMS Database Schema Initialization'
\echo '=========================================='
\echo ''

-- ============================================
-- 1. SIMULATION SCHEMA (Reference Data)
-- ============================================
\echo '>>> Creating Simulation Schema...'

CREATE TABLE IF NOT EXISTS "portfolio_id" (
   "portfolio_id" uuid PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS "symbol" (
   "symbol" varchar(255) PRIMARY KEY
);

-- Insert seed data for portfolios
INSERT INTO "portfolio_id" ( portfolio_id ) VALUES 
   ( '3f2c1d4e-8b57-4a92-9c65-b5e6f4e19b73' ),
   ( 'a8d4c0fa-7c1b-4e5d-9a89-2d635f0e2a14' ),
   ( 'd91f0b62-4c2f-4b91-8f2f-1b6c4ad7e543' ),
   ( '59c8a6d1-3f8b-4a67-bab6-89d0e72cce10' ),
   ( 'e2fa4c39-2a65-41c8-9f91-3c57f1d900ba' )
ON CONFLICT (portfolio_id) DO NOTHING;

-- Insert seed data for symbols
INSERT INTO "symbol" ( symbol ) VALUES 
   ( 'AAPL' ), ( 'MSFT' ), ( 'GOOGL' ), ( 'AMZN' ), ( 'META' ),
   ( 'NVDA' ), ( 'TSLA' ), ( 'NFLX' ), ( 'AMD' ), ( 'INTC' ),
   ( 'IBM' ), ( 'ORCL' ), ( 'BAC' ), ( 'JPM' ), ( 'WMT' )
ON CONFLICT (symbol) DO NOTHING;

\echo '✓ Simulation schema created'
\echo ''

-- ============================================
-- 2. VALIDATION SCHEMA
-- ============================================
\echo '>>> Creating Validation Schema...'

-- Invalid trades table
CREATE TABLE IF NOT EXISTS validation_invalid_trades (
    invalid_trade_outbox_id BIGSERIAL PRIMARY KEY,
    event_id UUID,
    trade_id UUID,
    portfolio_id UUID,
    symbol VARCHAR(255),
    side VARCHAR(50),
    price_per_stock NUMERIC(19, 4),
    quantity BIGINT,
    trade_timestamp TIMESTAMP,
    sent_status VARCHAR(255),
    validation_status VARCHAR(255),
    validation_errors TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Processed messages table
CREATE TABLE IF NOT EXISTS validation_processed_messages (
    id BIGSERIAL PRIMARY KEY,
    trade_id UUID NOT NULL,
    consumer_group VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    processed_at TIMESTAMP NOT NULL,
    CONSTRAINT uk_trade_id_consumer_group UNIQUE (trade_id, consumer_group)
);

-- Stocks table
CREATE TABLE IF NOT EXISTS pms_stocks (
    stock_id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(255) NOT NULL,
    sector_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Validation outbox table
CREATE TABLE IF NOT EXISTS validation_outbox (
    validation_outbox_id BIGSERIAL PRIMARY KEY,
    event_id UUID NOT NULL,
    trade_id UUID NOT NULL,
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    side VARCHAR(50) NOT NULL,
    price_per_stock NUMERIC(19, 4) NOT NULL,
    quantity BIGINT NOT NULL,
    trade_timestamp TIMESTAMP NOT NULL,
    sent_status VARCHAR(255) NOT NULL,
    validation_status VARCHAR(255) NOT NULL,
    validation_errors TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- Validation DLQ table
CREATE TABLE IF NOT EXISTS validation_dlq_entry (
    dlq_entry_id BIGSERIAL PRIMARY KEY,
    payload BYTEA NOT NULL,
    error_detail TEXT,
    created_at TIMESTAMP NOT NULL
);

\echo '✓ Validation schema created'
\echo ''

-- ============================================
-- 3. TRANSACTIONAL SCHEMA
-- ============================================
\echo '>>> Creating Transactional Schema...'

CREATE TABLE IF NOT EXISTS transactional_outbox (
    transactional_outbox_id BIGSERIAL PRIMARY KEY,
    event_id UUID NOT NULL,
    trade_id UUID NOT NULL,
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    side VARCHAR(50) NOT NULL,
    price_per_stock NUMERIC(19, 4) NOT NULL,
    quantity BIGINT NOT NULL,
    trade_timestamp TIMESTAMP NOT NULL,
    sent_status VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS transactional_processed_messages (
    id BIGSERIAL PRIMARY KEY,
    trade_id UUID NOT NULL,
    consumer_group VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    processed_at TIMESTAMP NOT NULL,
    CONSTRAINT uk_transactional_trade_id_consumer_group UNIQUE (trade_id, consumer_group)
);

CREATE TABLE IF NOT EXISTS transactional_dlq_entry (
    dlq_entry_id BIGSERIAL PRIMARY KEY,
    payload BYTEA NOT NULL,
    error_detail TEXT,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS "transaction" (
    transaction_id UUID PRIMARY KEY,
    trade_id UUID NOT NULL,
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    side VARCHAR(50) NOT NULL,
    price_per_stock NUMERIC(19, 4) NOT NULL,
    quantity BIGINT NOT NULL,
    trade_timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

\echo '✓ Transactional schema created'
\echo ''

-- ============================================
-- 4. RTTM SCHEMA
-- ============================================
\echo '>>> Creating RTTM Schema...'

CREATE TABLE IF NOT EXISTS rttm_portfolio_positions (
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    quantity BIGINT NOT NULL DEFAULT 0,
    average_price NUMERIC(19, 4),
    last_updated TIMESTAMP NOT NULL,
    PRIMARY KEY (portfolio_id, symbol)
);

CREATE TABLE IF NOT EXISTS rttm_invalid_trades (
    invalid_trade_id BIGSERIAL PRIMARY KEY,
    event_id UUID,
    trade_id UUID,
    portfolio_id UUID,
    symbol VARCHAR(255),
    side VARCHAR(50),
    price_per_stock NUMERIC(19, 4),
    quantity BIGINT,
    trade_timestamp TIMESTAMP,
    validation_errors TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rttm_processed_messages (
    id BIGSERIAL PRIMARY KEY,
    trade_id UUID NOT NULL,
    consumer_group VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    processed_at TIMESTAMP NOT NULL,
    CONSTRAINT uk_rttm_trade_id_consumer_group UNIQUE (trade_id, consumer_group)
);

-- RTTM Event Tracking Tables
CREATE TABLE IF NOT EXISTS rttm_trade_events (
    event_id BIGSERIAL PRIMARY KEY,
    trade_id UUID NOT NULL,
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    side VARCHAR(50) NOT NULL,
    quantity BIGINT NOT NULL,
    price_per_stock NUMERIC(19, 4) NOT NULL,
    trade_timestamp TIMESTAMP NOT NULL,
    received_at TIMESTAMP NOT NULL,
    processed_at TIMESTAMP,
    status VARCHAR(50) NOT NULL,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rttm_error_events (
    error_id BIGSERIAL PRIMARY KEY,
    trade_id UUID,
    error_type VARCHAR(100) NOT NULL,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rttm_dlq_events (
    dlq_id BIGSERIAL PRIMARY KEY,
    trade_id UUID,
    payload TEXT NOT NULL,
    error_message TEXT,
    retry_count INT DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_retry_at TIMESTAMP
);

-- RTTM Monitoring Tables
CREATE TABLE IF NOT EXISTS rttm_queue_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    queue_name VARCHAR(100) NOT NULL,
    queue_size INT NOT NULL,
    enqueue_rate NUMERIC(10, 2),
    dequeue_rate NUMERIC(10, 2),
    measured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rttm_stage_latency (
    latency_id BIGSERIAL PRIMARY KEY,
    stage_name VARCHAR(100) NOT NULL,
    avg_latency_ms NUMERIC(10, 2) NOT NULL,
    max_latency_ms NUMERIC(10, 2) NOT NULL,
    min_latency_ms NUMERIC(10, 2) NOT NULL,
    sample_count INT NOT NULL,
    measured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rttm_alerts (
    alert_id BIGSERIAL PRIMARY KEY,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    details JSONB,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMP,
    acknowledged_by VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

\echo '✓ RTTM schema created'
\echo ''

-- ============================================
-- 5. ANALYTICS SCHEMA
-- ============================================
\echo '>>> Creating Analytics Schema...'

CREATE TABLE IF NOT EXISTS analytics (
    analytics_id BIGSERIAL PRIMARY KEY,
    transaction_id UUID NOT NULL,
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    side VARCHAR(50) NOT NULL,
    price_per_stock NUMERIC(19, 4) NOT NULL,
    quantity BIGINT NOT NULL,
    trade_timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics_outbox (
    analytics_outbox_id BIGSERIAL PRIMARY KEY,
    event_id UUID NOT NULL,
    transaction_id UUID NOT NULL,
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    side VARCHAR(50) NOT NULL,
    price_per_stock NUMERIC(19, 4) NOT NULL,
    quantity BIGINT NOT NULL,
    trade_timestamp TIMESTAMP NOT NULL,
    sent_status VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics_portfolio_value_history (
    portfolio_value_history_id BIGSERIAL PRIMARY KEY,
    portfolio_id UUID NOT NULL,
    total_value NUMERIC(19, 4) NOT NULL,
    calculated_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics_portfolio_risk_status (
    portfolio_risk_status_id BIGSERIAL PRIMARY KEY,
    portfolio_id UUID NOT NULL,
    risk_level VARCHAR(50) NOT NULL,
    calculated_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL
);

\echo '✓ Analytics schema created'
\echo ''

-- ============================================
-- 6. ADDITIONAL COMMON TABLES
-- ============================================
\echo '>>> Creating Common Tables...'

-- User management (if needed)
CREATE TABLE IF NOT EXISTS pms_users (
    user_id UUID PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio investor details
CREATE TABLE IF NOT EXISTS portfolio_investor_details (
    portfolio_id UUID PRIMARY KEY,
    investor_name VARCHAR(255) NOT NULL,
    initial_investment NUMERIC(19, 4),
    risk_tolerance VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

\echo '✓ Common tables created'
\echo ''

-- ============================================
-- 7. INDEXES FOR PERFORMANCE
-- ============================================
\echo '>>> Creating Indexes...'

-- Validation indexes
CREATE INDEX IF NOT EXISTS idx_validation_invalid_trades_portfolio ON validation_invalid_trades(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_validation_invalid_trades_symbol ON validation_invalid_trades(symbol);
CREATE INDEX IF NOT EXISTS idx_validation_invalid_trades_status ON validation_invalid_trades(sent_status);
CREATE INDEX IF NOT EXISTS idx_validation_outbox_status ON validation_outbox(sent_status);

-- Transactional indexes
CREATE INDEX IF NOT EXISTS idx_transaction_portfolio ON "transaction"(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transaction_symbol ON "transaction"(symbol);
CREATE INDEX IF NOT EXISTS idx_transaction_timestamp ON "transaction"(trade_timestamp);
CREATE INDEX IF NOT EXISTS idx_transactional_outbox_status ON transactional_outbox(sent_status);

-- RTTM indexes
CREATE INDEX IF NOT EXISTS idx_rttm_positions_portfolio ON rttm_portfolio_positions(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_rttm_positions_symbol ON rttm_portfolio_positions(symbol);
CREATE INDEX IF NOT EXISTS idx_rttm_trade_events_status ON rttm_trade_events(status);
CREATE INDEX IF NOT EXISTS idx_rttm_trade_events_timestamp ON rttm_trade_events(trade_timestamp);

-- Analytics indexes
CREATE INDEX IF NOT EXISTS idx_analytics_portfolio ON analytics(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_analytics_symbol ON analytics(symbol);
CREATE INDEX IF NOT EXISTS idx_analytics_timestamp ON analytics(trade_timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_outbox_status ON analytics_outbox(sent_status);

\echo '✓ Indexes created'
\echo ''

-- ============================================
-- 8. VERIFICATION
-- ============================================
\echo '=========================================='
\echo 'Verification'
\echo '=========================================='
\echo ''

\echo 'Table Row Counts:'
SELECT 'portfolio_id' as table_name, COUNT(*) as count FROM "portfolio_id"
UNION ALL
SELECT 'symbol', COUNT(*) FROM "symbol"
UNION ALL
SELECT 'validation_invalid_trades', COUNT(*) FROM validation_invalid_trades
UNION ALL
SELECT 'validation_outbox', COUNT(*) FROM validation_outbox
UNION ALL
SELECT 'transaction', COUNT(*) FROM "transaction"
UNION ALL
SELECT 'transactional_outbox', COUNT(*) FROM transactional_outbox
UNION ALL
SELECT 'analytics', COUNT(*) FROM analytics
UNION ALL
SELECT 'analytics_outbox', COUNT(*) FROM analytics_outbox
UNION ALL
SELECT 'rttm_portfolio_positions', COUNT(*) FROM rttm_portfolio_positions
UNION ALL
SELECT 'rttm_trade_events', COUNT(*) FROM rttm_trade_events
ORDER BY table_name;

\echo ''
\echo 'All Tables in Database:'
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

\echo ''
\echo '=========================================='
\echo '✅ Database initialization complete!'
\echo '=========================================='
\echo ''
\echo 'Reference Data Summary:'
\echo '  - Portfolios: 5'
\echo '  - Symbols: 15 (AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA, NFLX, AMD, INTC, IBM, ORCL, BAC, JPM, WMT)'
\echo ''
\echo 'Services Supported:'
\echo '  - Simulation'
\echo '  - Validation'
\echo '  - Transactional'
\echo '  - RTTM'
\echo '  - Analytics'
\echo ''
