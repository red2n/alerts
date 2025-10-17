#!/bin/bash

# ==============================================================================
# Alert System - Unified Management Script
# ==============================================================================
#
# This script handles all operations for the Kafka Alert System:
#   - Create Kafka topics
#   - Start/stop the application
#   - Run performance tests
#   - Test Kafka connectivity
#
# Usage: ./manage.sh <command> [options]
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_JAR="$SCRIPT_DIR/target/kafka-alerts-processor-1.0.0.jar"
APP_LOG="$SCRIPT_DIR/app.log"
PID_FILE="$SCRIPT_DIR/app.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  create-topics <broker>    Create all 3 required Kafka topics
  start                     Start the application
  stop                      Stop the application
  restart                   Restart the application
  status                    Check application status
  logs [lines]              Show application logs (default: 50 lines)
  test-connectivity <broker> Test Kafka broker connectivity
  test-performance          Run basic performance tests (10 requests)
  test-stress               Run stress test (100 requests, 5 scenarios)
  build                     Build the application
  help                      Show this help message

Examples:
  # Create topics
  $0 create-topics kafka-broker.example.com:9092

  # Start application
  $0 start

  # Check logs
  $0 logs 100

  # Run performance test
  $0 test-performance

  # Run stress test (100 requests)
  $0 test-stress

Environment Variables:
  KAFKA_BOOTSTRAP_SERVERS   Kafka broker address (for create-topics)

EOF
}

# ==============================================================================
# CREATE TOPICS
# ==============================================================================

create_topics() {
    local BROKER="${1:-${KAFKA_BOOTSTRAP_SERVERS}}"

    if [ -z "$BROKER" ]; then
        print_error "Kafka broker address not provided"
        echo ""
        echo "Usage:"
        echo "  $0 create-topics <broker-address>"
        echo ""
        echo "Example:"
        echo "  $0 create-topics my-kafka-broker.example.com:9092"
        echo ""
        exit 1
    fi

    print_header "Creating Kafka Topics"

    echo "Kafka Broker: $BROKER"
    echo "Partitions: 1"
    echo "Replication Factor: 1"
    echo ""

    # Check if kafka-topics command is available
    if ! command -v kafka-topics &> /dev/null; then
        print_warning "kafka-topics command not found"
        echo ""
        echo "Please create these 3 topics manually:"
        echo "  1. eagle-eye.config"
        echo "  2. eagle-eye.alerts"
        echo "  3. eagle-eye-stream-processor-threshold-store-changelog"
        echo ""
        echo "See README.md for detailed specifications"
        exit 1
    fi

    # Create topics
    local PARTITIONS=1
    local REPLICATION=1
    local RETENTION_MS=2592000000
    local COMPRESSION="snappy"

    echo "Creating topics..."
    echo ""

    # Topic 1
    echo "1. eagle-eye.config..."
    kafka-topics --create \
      --bootstrap-server "$BROKER" \
      --topic eagle-eye.config \
      --partitions $PARTITIONS \
      --replication-factor $REPLICATION \
      --config retention.ms=$RETENTION_MS \
      --config cleanup.policy=delete \
      --config compression.type=$COMPRESSION \
      --if-not-exists 2>&1 | grep -v "already exists" || true
    print_success "eagle-eye.config"

    # Topic 2
    echo "2. eagle-eye.alerts..."
    kafka-topics --create \
      --bootstrap-server "$BROKER" \
      --topic eagle-eye.alerts \
      --partitions $PARTITIONS \
      --replication-factor $REPLICATION \
      --config retention.ms=$RETENTION_MS \
      --config cleanup.policy=delete \
      --config compression.type=$COMPRESSION \
      --if-not-exists 2>&1 | grep -v "already exists" || true
    print_success "eagle-eye.alerts"

    # Topic 3
    echo "3. eagle-eye-stream-processor-threshold-store-changelog..."
    kafka-topics --create \
      --bootstrap-server "$BROKER" \
      --topic eagle-eye-stream-processor-threshold-store-changelog \
      --partitions $PARTITIONS \
      --replication-factor $REPLICATION \
      --config retention.ms=$RETENTION_MS \
      --config cleanup.policy=compact,delete \
      --config compression.type=$COMPRESSION \
      --config min.compaction.lag.ms=0 \
      --config segment.ms=100 \
      --if-not-exists 2>&1 | grep -v "already exists" || true
    print_success "eagle-eye-stream-processor-threshold-store-changelog"

    echo ""
    print_success "All topics created successfully!"
}

# ==============================================================================
# APPLICATION MANAGEMENT
# ==============================================================================

build_app() {
    print_header "Building Application"

    cd "$SCRIPT_DIR"
    mvn clean package -DskipTests -q

    if [ -f "$APP_JAR" ]; then
        print_success "Build completed: $APP_JAR"
    else
        print_error "Build failed - JAR file not found"
        exit 1
    fi
}

start_app() {
    print_header "Starting Application"

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            print_warning "Application already running (PID: $OLD_PID)"
            exit 0
        fi
    fi

    # Check if JAR exists
    if [ ! -f "$APP_JAR" ]; then
        print_error "Application JAR not found. Run: $0 build"
        exit 1
    fi

    # Start application
    nohup java \
      -Djava.net.preferIPv4Stack=true \
      -Dsun.net.inetaddr.ttl=60 \
      -jar "$APP_JAR" > "$APP_LOG" 2>&1 &

    local PID=$!
    echo $PID > "$PID_FILE"

    print_success "Application started (PID: $PID)"
    print_info "Logs: tail -f $APP_LOG"

    # Wait a few seconds and check status
    sleep 3
    if ps -p "$PID" > /dev/null 2>&1; then
        print_success "Application is running"
    else
        print_error "Application failed to start - check logs"
        cat "$APP_LOG" | tail -20
        exit 1
    fi
}

stop_app() {
    print_header "Stopping Application"

    if [ ! -f "$PID_FILE" ]; then
        print_warning "Application not running (PID file not found)"
        # Try to kill by name anyway
        pkill -f "kafka-alerts-processor" 2>/dev/null && print_success "Application stopped" || true
        exit 0
    fi

    local PID=$(cat "$PID_FILE")

    if ps -p "$PID" > /dev/null 2>&1; then
        kill "$PID"
        sleep 2

        # Force kill if still running
        if ps -p "$PID" > /dev/null 2>&1; then
            kill -9 "$PID"
            sleep 1
        fi

        rm -f "$PID_FILE"
        print_success "Application stopped"
    else
        print_warning "Application not running (stale PID file)"
        rm -f "$PID_FILE"
    fi
}

restart_app() {
    print_header "Restarting Application"
    stop_app
    sleep 2
    start_app
}

status_app() {
    print_header "Application Status"

    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            print_success "Application is RUNNING (PID: $PID)"
            echo ""
            echo "Memory usage:"
            ps -p "$PID" -o pid,vsz,rss,cmd | tail -1
            echo ""
            echo "Recent logs:"
            tail -10 "$APP_LOG"
        else
            print_error "Application is STOPPED (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        print_warning "Application is STOPPED"
    fi
}

show_logs() {
    local LINES="${1:-50}"

    if [ ! -f "$APP_LOG" ]; then
        print_error "Log file not found: $APP_LOG"
        exit 1
    fi

    print_header "Application Logs (last $LINES lines)"
    tail -n "$LINES" "$APP_LOG"
}

# ==============================================================================
# TESTING
# ==============================================================================

test_connectivity() {
    local BROKER="${1:-${KAFKA_BOOTSTRAP_SERVERS}}"

    if [ -z "$BROKER" ]; then
        print_error "Kafka broker address not provided"
        echo "Usage: $0 test-connectivity <broker-address>"
        exit 1
    fi

    print_header "Kafka Connectivity Test"

    echo "Broker: $BROKER"
    echo ""

    # Test TCP connectivity
    local HOST=$(echo "$BROKER" | cut -d: -f1)
    local PORT=$(echo "$BROKER" | cut -d: -f2)

    echo "Testing TCP connection to $HOST:$PORT..."
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
        print_success "Port $PORT is accessible"
    else
        print_error "Cannot connect to port $PORT"
        exit 1
    fi

    echo ""

    # Check for kcat
    if command -v kcat &> /dev/null; then
        echo "Listing topics..."
        kcat -b "$BROKER" -L | grep -i "eagle-eye" || print_warning "No eagle-eye topics found"
    else
        print_warning "kcat not installed - cannot list topics"
    fi

    echo ""
    print_success "Connectivity test complete"
}

test_performance() {
    print_header "Performance Test"

    local ENDPOINT="http://localhost:8080/api/alert"

    # Check if app is running
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if ! ps -p "$PID" > /dev/null 2>&1; then
            print_error "Application not running. Start it first: $0 start"
            exit 1
        fi
    else
        print_error "Application not running. Start it first: $0 start"
        exit 1
    fi

    echo "Testing API endpoint: $ENDPOINT"
    echo ""

    # Test 1: Alert above threshold
    echo "Test 1: Alert ABOVE threshold (should trigger)"
    RESULT=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
      -d '{"key":"property_10;tenant_0;type_error;interface_api","errorCount":"75"}')
    echo "Response: $RESULT"
    echo ""

    # Test 2: Alert below threshold
    echo "Test 2: Alert BELOW threshold (should not trigger)"
    RESULT=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
      -d '{"key":"property_20;tenant_0;type_error;interface_api","errorCount":"30"}')
    echo "Response: $RESULT"
    echo ""

    # Test 3: Performance - 10 requests
    echo "Test 3: Performance - 10 requests"
    START=$(date +%s%N)
    for i in {1..10}; do
      curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
        -d "{\"key\":\"property_$i;tenant_0;type_error;interface_api\",\"errorCount\":\"$((50 + i))\"}" > /dev/null
    done
    END=$(date +%s%N)
    DURATION=$(( (END - START) / 1000000 ))

    print_success "Completed 10 requests in ${DURATION}ms"
    echo "Average latency: $((DURATION / 10))ms per request"
    echo ""

    print_success "Performance test complete"
}

test_stress() {
    print_header "Stress Test - 100 Requests with 5 Error Scenarios"

    local ENDPOINT="http://localhost:8080/api/alert"

    # Check if app is running
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if ! ps -p "$PID" > /dev/null 2>&1; then
            print_error "Application not running. Start it first: $0 start"
            exit 1
        fi
    else
        print_error "Application not running. Start it first: $0 start"
        exit 1
    fi

    echo "Testing API endpoint: $ENDPOINT"
    echo "Sending 100 requests with 5 different error scenarios..."
    echo ""

    # Error scenarios (5 types)
    local -a SCENARIOS=(
        "High errors - Way above threshold"
        "Just above threshold"
        "At threshold boundary"
        "Below threshold"
        "Very low errors"
    )

    # Track results
    local TOTAL_REQUESTS=100
    local SUCCESS=0
    local ALERTS_TRIGGERED=0
    local BELOW_THRESHOLD=0
    local NO_THRESHOLD=0
    local ERRORS=0

    # Start overall timer
    local OVERALL_START=$(date +%s%N)

    echo "┌────────────────────────────────────────────────────────────────┐"
    echo "│                    STRESS TEST PROGRESS                        │"
    echo "└────────────────────────────────────────────────────────────────┘"
    echo ""

    # Run 100 requests (20 requests per scenario)
    for round in {1..5}; do
        echo "Round $round/5: ${SCENARIOS[$((round-1))]}"

        local ROUND_START=$(date +%s%N)
        local ROUND_SUCCESS=0
        local ROUND_ALERTS=0

        for i in {1..20}; do
            local PROP_ID=$((($round - 1) * 20 + $i))

            # Determine error count based on scenario
            case $round in
                1) ERROR_COUNT=$((100 + RANDOM % 50))  ;; # 100-150 (way above 50)
                2) ERROR_COUNT=$((55 + RANDOM % 10))   ;; # 55-65 (just above 50)
                3) ERROR_COUNT=50                      ;; # Exactly 50 (at boundary)
                4) ERROR_COUNT=$((30 + RANDOM % 15))   ;; # 30-45 (below 50)
                5) ERROR_COUNT=$((5 + RANDOM % 10))    ;; # 5-15 (very low)
            esac

            # Send request
            RESULT=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
                -H "Content-Type: application/json" \
                -d "{\"key\":\"property_${PROP_ID};tenant_0;type_error;interface_api\",\"errorCount\":\"${ERROR_COUNT}\"}" 2>/dev/null)

            HTTP_CODE=$(echo "$RESULT" | tail -1)
            RESPONSE=$(echo "$RESULT" | head -1)

            # Track success
            if [ "$HTTP_CODE" = "200" ]; then
                ((SUCCESS++))
                ((ROUND_SUCCESS++))

                # Parse response to track alert types
                if echo "$RESPONSE" | grep -q "alert_triggered"; then
                    ((ALERTS_TRIGGERED++))
                    ((ROUND_ALERTS++))
                elif echo "$RESPONSE" | grep -q "below_threshold"; then
                    ((BELOW_THRESHOLD++))
                elif echo "$RESPONSE" | grep -q "no_threshold_configured"; then
                    ((NO_THRESHOLD++))
                fi
            else
                ((ERRORS++))
                echo "  ❌ Request $PROP_ID failed with HTTP $HTTP_CODE"
            fi

            # Progress indicator
            if [ $((i % 5)) -eq 0 ]; then
                echo -n "."
            fi
        done

        local ROUND_END=$(date +%s%N)
        local ROUND_DURATION=$(( (ROUND_END - ROUND_START) / 1000000 ))

        echo ""
        echo "  ✅ Completed: $ROUND_SUCCESS/20 | Alerts: $ROUND_ALERTS | Time: ${ROUND_DURATION}ms"
        echo ""
    done

    local OVERALL_END=$(date +%s%N)
    local OVERALL_DURATION=$(( (OVERALL_END - OVERALL_START) / 1000000 ))

    # Print summary
    echo ""
    echo "┌────────────────────────────────────────────────────────────────┐"
    echo "│                      TEST SUMMARY                              │"
    echo "└────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "Total Requests:        $TOTAL_REQUESTS"
    echo "Successful:            $SUCCESS ($(( SUCCESS * 100 / TOTAL_REQUESTS ))%)"
    echo "Failed:                $ERRORS"
    echo ""
    echo "Response Breakdown:"
    echo "  • Alerts Triggered:  $ALERTS_TRIGGERED"
    echo "  • Below Threshold:   $BELOW_THRESHOLD"
    echo "  • No Threshold:      $NO_THRESHOLD"
    echo ""
    echo "Performance Metrics:"
    echo "  • Total Time:        ${OVERALL_DURATION}ms"
    echo "  • Average Latency:   $((OVERALL_DURATION / TOTAL_REQUESTS))ms per request"
    echo "  • Throughput:        $((TOTAL_REQUESTS * 1000 / OVERALL_DURATION)) requests/sec"
    echo ""

    if [ $SUCCESS -eq $TOTAL_REQUESTS ]; then
        print_success "All $TOTAL_REQUESTS requests completed successfully!"
    else
        print_warning "$ERRORS requests failed"
    fi

    echo ""
    echo "💡 Check logs for alert details: ./manage.sh logs 50"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    local COMMAND="${1:-help}"

    case "$COMMAND" in
        create-topics)
            create_topics "$2"
            ;;
        build)
            build_app
            ;;
        start)
            start_app
            ;;
        stop)
            stop_app
            ;;
        restart)
            restart_app
            ;;
        status)
            status_app
            ;;
        logs)
            show_logs "$2"
            ;;
        test-connectivity)
            test_connectivity "$2"
            ;;
        test-performance)
            test_performance
            ;;
        test-stress)
            test_stress
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
