#!/bin/bash

# Simple stress test - 100 requests with 5 scenarios

ENDPOINT="http://localhost:8080/api/alert"

echo "========================================="
echo "Stress Test - 100 Requests"
echo "========================================="
echo ""

# Track results
SUCCESS=0
ALERTS=0
BELOW=0
NO_THRESHOLD=0
ERRORS=0

START_TIME=$(date +%s)

echo "Running tests..."
echo ""

# Scenario 1: High errors (way above threshold 50)
echo "Scenario 1: High errors (100-150) - 20 requests"
for i in {1..20}; do
    ERROR_COUNT=$((100 + RANDOM % 51))
    RESULT=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
        -d "{\"key\":\"property_${i};tenant_0;type_error;interface_api\",\"errorCount\":\"${ERROR_COUNT}\"}")

    if echo "$RESULT" | grep -q "key"; then
        ((SUCCESS++))
        if echo "$RESULT" | grep -q "alert_triggered"; then
            ((ALERTS++))
            echo -n "🔥"
        elif echo "$RESULT" | grep -q "below_threshold"; then
            ((BELOW++))
            echo -n "✓"
        else
            ((NO_THRESHOLD++))
            echo -n "○"
        fi
    else
        ((ERRORS++))
        echo -n "✗"
    fi
done
echo " (20/20)"

# Scenario 2: Just above threshold (55-65)
echo "Scenario 2: Just above threshold (55-65) - 20 requests"
for i in {21..40}; do
    ERROR_COUNT=$((55 + RANDOM % 11))
    RESULT=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
        -d "{\"key\":\"property_${i};tenant_0;type_error;interface_api\",\"errorCount\":\"${ERROR_COUNT}\"}")

    if echo "$RESULT" | grep -q "key"; then
        ((SUCCESS++))
        if echo "$RESULT" | grep -q "alert_triggered"; then
            ((ALERTS++))
            echo -n "🔥"
        elif echo "$RESULT" | grep -q "below_threshold"; then
            ((BELOW++))
            echo -n "✓"
        else
            ((NO_THRESHOLD++))
            echo -n "○"
        fi
    else
        ((ERRORS++))
        echo -n "✗"
    fi
done
echo " (20/20)"

# Scenario 3: At threshold boundary (50)
echo "Scenario 3: At threshold boundary (50) - 20 requests"
for i in {41..60}; do
    ERROR_COUNT=50
    RESULT=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
        -d "{\"key\":\"property_${i};tenant_0;type_error;interface_api\",\"errorCount\":\"${ERROR_COUNT}\"}")

    if echo "$RESULT" | grep -q "key"; then
        ((SUCCESS++))
        if echo "$RESULT" | grep -q "alert_triggered"; then
            ((ALERTS++))
            echo -n "🔥"
        elif echo "$RESULT" | grep -q "below_threshold"; then
            ((BELOW++))
            echo -n "✓"
        else
            ((NO_THRESHOLD++))
            echo -n "○"
        fi
    else
        ((ERRORS++))
        echo -n "✗"
    fi
done
echo " (20/20)"

# Scenario 4: Below threshold (30-45)
echo "Scenario 4: Below threshold (30-45) - 20 requests"
for i in {61..80}; do
    ERROR_COUNT=$((30 + RANDOM % 16))
    RESULT=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
        -d "{\"key\":\"property_${i};tenant_0;type_error;interface_api\",\"errorCount\":\"${ERROR_COUNT}\"}")

    if echo "$RESULT" | grep -q "key"; then
        ((SUCCESS++))
        if echo "$RESULT" | grep -q "alert_triggered"; then
            ((ALERTS++))
            echo -n "🔥"
        elif echo "$RESULT" | grep -q "below_threshold"; then
            ((BELOW++))
            echo -n "✓"
        else
            ((NO_THRESHOLD++))
            echo -n "○"
        fi
    else
        ((ERRORS++))
        echo -n "✗"
    fi
done
echo " (20/20)"

# Scenario 5: Very low errors (5-15)
echo "Scenario 5: Very low errors (5-15) - 20 requests"
for i in {81..100}; do
    ERROR_COUNT=$((5 + RANDOM % 11))
    RESULT=$(curl -s -X POST "$ENDPOINT" -H "Content-Type: application/json" \
        -d "{\"key\":\"property_${i};tenant_0;type_error;interface_api\",\"errorCount\":\"${ERROR_COUNT}\"}")

    if echo "$RESULT" | grep -q "key"; then
        ((SUCCESS++))
        if echo "$RESULT" | grep -q "alert_triggered"; then
            ((ALERTS++))
            echo -n "🔥"
        elif echo "$RESULT" | grep -q "below_threshold"; then
            ((BELOW++))
            echo -n "✓"
        else
            ((NO_THRESHOLD++))
            echo -n "○"
        fi
    else
        ((ERRORS++))
        echo -n "✗"
    fi
done
echo " (20/20)"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="
echo ""
echo "Total Requests:       100"
echo "Successful:           $SUCCESS ($(( SUCCESS * 100 / 100 ))%)"
echo "Failed:               $ERRORS"
echo ""
echo "Response Breakdown:"
echo "  🔥 Alerts Triggered: $ALERTS"
echo "  ✓  Below Threshold:  $BELOW"
echo "  ○  No Threshold:     $NO_THRESHOLD"
echo ""
echo "Performance:"
echo "  Total Time:          ${DURATION}s"
echo "  Average Latency:     $((DURATION * 1000 / 100))ms per request"
echo "  Throughput:          $((100 / DURATION)) requests/sec"
echo ""

if [ $SUCCESS -eq 100 ]; then
    echo "✅ All 100 requests completed successfully!"
else
    echo "⚠️  $ERRORS requests failed"
fi

echo ""
echo "Legend: 🔥=Alert  ✓=Below  ○=NoThreshold  ✗=Error"
