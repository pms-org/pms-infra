#!/bin/bash

##############################################################################
# PMS Platform Endpoint Testing Script
# Tests all HTTP and WebSocket endpoints across services
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_GATEWAY=${API_GATEWAY_URL:-"http://localhost:8088"}
NAMESPACE=${NAMESPACE:-"pms"}
TIMEOUT=${TIMEOUT:-5}

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -e "${YELLOW}[TEST] $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    ((PASSED_TESTS++))
}

print_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    echo -e "${RED}  Error: $2${NC}"
    ((FAILED_TESTS++))
}

increment_test() {
    ((TOTAL_TESTS++))
}

# Test HTTP endpoint
test_http_endpoint() {
    local name="$1"
    local url="$2"
    local method="${3:-GET}"
    local expected_status="${4:-200}"
    local data="${5:-}"
    
    increment_test
    print_test "$name - $method $url"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            --connect-timeout "$TIMEOUT" \
            "$url" 2>&1) || true
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            --connect-timeout "$TIMEOUT" \
            "$url" 2>&1) || true
    fi
    
    if echo "$response" | tail -n1 | grep -q "^$expected_status$"; then
        print_success "$name"
        return 0
    else
        status=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n-1)
        print_fail "$name" "Expected status $expected_status, got $status. Response: $body"
        return 1
    fi
}

# Test WebSocket endpoint
test_websocket_endpoint() {
    local name="$1"
    local url="$2"
    
    increment_test
    print_test "$name - WebSocket $url"
    
    # Test WebSocket upgrade using curl
    response=$(curl -s -w "\n%{http_code}" \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Version: 13" \
        -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
        --connect-timeout "$TIMEOUT" \
        "$url" 2>&1) || true
    
    status=$(echo "$response" | tail -n1)
    
    # WebSocket upgrade returns 101 (Switching Protocols) or connection accepted
    if echo "$status" | grep -qE "^(101|200)$"; then
        print_success "$name"
        return 0
    else
        print_fail "$name" "WebSocket upgrade failed. Status: $status"
        return 1
    fi
}

# Get LoadBalancer URLs from Kubernetes
get_loadbalancer_urls() {
    print_header "Fetching LoadBalancer URLs from Kubernetes"
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}kubectl not found. Using default API_GATEWAY_URL: $API_GATEWAY${NC}"
        return
    fi
    
    # Get API Gateway LoadBalancer URL
    GATEWAY_LB=$(kubectl get svc apigateway-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    GATEWAY_PORT=$(kubectl get svc apigateway-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "8088")
    
    if [ -n "$GATEWAY_LB" ]; then
        API_GATEWAY="http://${GATEWAY_LB}:${GATEWAY_PORT}"
        echo -e "${GREEN}API Gateway URL: $API_GATEWAY${NC}"
    else
        echo -e "${YELLOW}Could not fetch API Gateway LoadBalancer URL from cluster${NC}"
        echo -e "${YELLOW}Using: $API_GATEWAY${NC}"
    fi
    
    # Get Frontend LoadBalancer URL
    FRONTEND_LB=$(kubectl get svc frontend-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    FRONTEND_PORT=$(kubectl get svc frontend-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
    
    if [ -n "$FRONTEND_LB" ]; then
        FRONTEND_URL="http://${FRONTEND_LB}:${FRONTEND_PORT}"
        echo -e "${GREEN}Frontend URL: $FRONTEND_URL${NC}"
    fi
}

##############################################################################
# Test Suites
##############################################################################

test_auth_service() {
    print_header "Testing Auth Service Endpoints"
    
    # POST /api/auth/signup
    test_http_endpoint \
        "Auth Signup" \
        "$API_GATEWAY/api/auth/signup" \
        "POST" \
        "200" \
        '{"username":"testuser","password":"testpass123","email":"test@example.com"}'
    
    # POST /api/auth/login
    test_http_endpoint \
        "Auth Login" \
        "$API_GATEWAY/api/auth/login" \
        "POST" \
        "200" \
        '{"username":"testuser","password":"testpass123"}'
}

test_portfolio_service() {
    print_header "Testing Portfolio Service Endpoints"
    
    # GET /api/portfolio/all
    test_http_endpoint \
        "Portfolio - Get All" \
        "$API_GATEWAY/api/portfolio/all" \
        "GET" \
        "200"
    
    # POST /api/portfolio/create
    test_http_endpoint \
        "Portfolio - Create" \
        "$API_GATEWAY/api/portfolio/create" \
        "POST" \
        "200" \
        '{"name":"Test Portfolio"}'
}

test_analytics_service() {
    print_header "Testing Analytics Service Endpoints"
    
    # GET /api/analysis/all
    test_http_endpoint \
        "Analytics - All Analysis" \
        "$API_GATEWAY/api/analysis/all" \
        "GET" \
        "200"
    
    # GET /api/sectors/overall
    test_http_endpoint \
        "Analytics - Overall Sectors" \
        "$API_GATEWAY/api/sectors/overall" \
        "GET" \
        "200"
    
    # GET /api/unrealized
    test_http_endpoint \
        "Analytics - Unrealized PnL" \
        "$API_GATEWAY/api/unrealized" \
        "GET" \
        "200"
    
    # GET /api/sectors/sector-catalog
    test_http_endpoint \
        "Analytics - Sector Catalog" \
        "$API_GATEWAY/api/sectors/sector-catalog" \
        "GET" \
        "200"
}

test_leaderboard_service() {
    print_header "Testing Leaderboard Service Endpoints"
    
    # GET /api/leaderboard/top
    test_http_endpoint \
        "Leaderboard - Top Performers" \
        "$API_GATEWAY/api/leaderboard/top" \
        "GET" \
        "200"
    
    # GET /api/leaderboard/around?portfolioId=test
    test_http_endpoint \
        "Leaderboard - Around Portfolio" \
        "$API_GATEWAY/api/leaderboard/around?portfolioId=P001" \
        "GET" \
        "200"
}

test_rttm_service() {
    print_header "Testing RTTM Service Endpoints"
    
    # GET /api/rttm/metrics
    test_http_endpoint \
        "RTTM - Metrics" \
        "$API_GATEWAY/api/rttm/metrics" \
        "GET" \
        "200"
    
    # GET /api/rttm/pipeline
    test_http_endpoint \
        "RTTM - Pipeline" \
        "$API_GATEWAY/api/rttm/pipeline" \
        "GET" \
        "200"
    
    # GET /api/rttm/telemetry-snapshot
    test_http_endpoint \
        "RTTM - Telemetry Snapshot" \
        "$API_GATEWAY/api/rttm/telemetry-snapshot" \
        "GET" \
        "200"
    
    # GET /api/rttm/dlq
    test_http_endpoint \
        "RTTM - DLQ" \
        "$API_GATEWAY/api/rttm/dlq" \
        "GET" \
        "200"
    
    # GET /api/rttm/alerts
    test_http_endpoint \
        "RTTM - Alerts" \
        "$API_GATEWAY/api/rttm/alerts" \
        "GET" \
        "200"
}

test_simulation_service() {
    print_header "Testing Simulation Service Endpoints"
    
    # POST /simulation/create-portfolio
    test_http_endpoint \
        "Simulation - Create Portfolio" \
        "$API_GATEWAY/simulation/create-portfolio" \
        "POST" \
        "200" \
        '{}'
}

test_websocket_endpoints() {
    print_header "Testing WebSocket Endpoints"
    
    # Note: Basic WebSocket connectivity test
    # For full STOMP testing, you would need a WebSocket client like wscat
    
    echo -e "${YELLOW}Note: WebSocket endpoints require STOMP client for full testing${NC}"
    echo -e "${YELLOW}These tests only verify the WebSocket upgrade capability${NC}\n"
    
    # Analytics WebSocket
    local analytics_ws="${API_GATEWAY/http/ws}"
    test_websocket_endpoint \
        "Analytics - WebSocket /ws" \
        "$analytics_ws/ws"
    
    # Leaderboard WebSocket
    test_websocket_endpoint \
        "Leaderboard - WebSocket /ws/updates" \
        "$analytics_ws/ws/updates"
    
    # RTTM WebSocket
    test_websocket_endpoint \
        "RTTM - WebSocket /ws/rttm/metrics" \
        "$analytics_ws/ws/rttm/metrics"
}

test_api_gateway_health() {
    print_header "Testing API Gateway Health"
    
    # API Gateway fallback endpoint
    test_http_endpoint \
        "API Gateway - Fallback Endpoint" \
        "$API_GATEWAY/fallback" \
        "GET" \
        "200"
    
    # Test CORS headers
    increment_test
    print_test "API Gateway - CORS Headers"
    response=$(curl -s -H "Origin: http://example.com" \
        -H "Access-Control-Request-Method: GET" \
        -X OPTIONS \
        --connect-timeout "$TIMEOUT" \
        -I "$API_GATEWAY/api/analysis/all" 2>&1) || true
    
    if echo "$response" | grep -qi "access-control-allow"; then
        print_success "CORS Headers Present"
    else
        print_fail "CORS Headers" "No CORS headers found in response"
    fi
}

test_frontend_deployment() {
    print_header "Testing Frontend Deployment"
    
    if [ -z "$FRONTEND_URL" ]; then
        echo -e "${YELLOW}Frontend URL not available. Skipping frontend tests.${NC}"
        return
    fi
    
    # Test frontend static files
    test_http_endpoint \
        "Frontend - Index Page" \
        "$FRONTEND_URL/" \
        "GET" \
        "200"
    
    # Test env.js runtime configuration
    test_http_endpoint \
        "Frontend - Runtime Config (env.js)" \
        "$FRONTEND_URL/env.js" \
        "GET" \
        "200"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header "PMS Platform Endpoint Testing"
    echo -e "API Gateway: ${GREEN}$API_GATEWAY${NC}"
    echo -e "Namespace: ${GREEN}$NAMESPACE${NC}"
    echo -e "Timeout: ${GREEN}${TIMEOUT}s${NC}"
    
    # Fetch LoadBalancer URLs if kubectl is available
    get_loadbalancer_urls
    
    # Run all test suites
    test_api_gateway_health
    test_auth_service
    test_portfolio_service
    test_analytics_service
    test_leaderboard_service
    test_rttm_service
    test_simulation_service
    test_websocket_endpoints
    test_frontend_deployment
    
    # Print summary
    print_header "Test Summary"
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed! ✓${NC}\n"
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Please review the output above.${NC}\n"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --gateway-url)
            API_GATEWAY="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --gateway-url URL    API Gateway URL (default: http://localhost:8088)"
            echo "  --namespace NAME     Kubernetes namespace (default: pms)"
            echo "  --timeout SECONDS    Request timeout in seconds (default: 5)"
            echo "  --help               Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --gateway-url http://api-gateway.example.com:8088 --namespace pms"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

main
