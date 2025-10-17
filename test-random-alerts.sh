#!/bin/bash

echo "=== Testing Alert System with Random Data ==="
echo ""
echo "Sending 20 random alert requests..."
echo ""

SUCCESS=0
ALERTS_TRIGGERED=0
BELOW_THRESHOLD=0

for i in {1..20}; do
    # Random property (1-100)
    PROPERTY_ID=$((RANDOM % 100 + 1))

    # Random error count (0-150)
    ERROR_COUNT=$((RANDOM % 151))

    # Send request
    RESPONSE=$(curl -s -X POST http://localhost:8080/api/alert \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"property_${PROPERTY_ID};tenant_0;type_error;interface_api\",\"errorCount\":\"${ERROR_COUNT}\"}")

    STATUS=$(echo "$RESPONSE" | jq -r .status)
    THRESHOLD=$(echo "$RESPONSE" | jq -r .threshold // "N/A")

    if [ "$STATUS" == "alert_triggered" ]; then
        ((ALERTS_TRIGGERED++))
        echo "  [$i] Property $PROPERTY_ID: ErrorCount=$ERROR_COUNT > Threshold=$THRESHOLD → 🚨 ALERT"
    elif [ "$STATUS" == "below_threshold" ]; then
        ((BELOW_THRESHOLD++))
        echo "  [$i] Property $PROPERTY_ID: ErrorCount=$ERROR_COUNT < Threshold=$THRESHOLD → ✅ OK"
    else
        echo "  [$i] Property $PROPERTY_ID: ErrorCount=$ERROR_COUNT → ⚠️ NO_THRESHOLD"
    fi

    ((SUCCESS++))
done

echo ""
echo "=== SUMMARY ==="
echo "Total Requests:    $SUCCESS"
echo "Alerts Triggered:  $ALERTS_TRIGGERED"
echo "Below Threshold:   $BELOW_THRESHOLD"
echo ""
echo "Checking Kafka topics..."
THRESHOLD_COUNT=$(kcat -b lab-stay-backplane.westus.cloudapp.azure.com:9092 -t eagle-eye.thresholds -C -e -o beginning 2>/dev/null | wc -l)
ALERT_COUNT=$(kcat -b lab-stay-backplane.westus.cloudapp.azure.com:9092 -t eagle-eye.eagle.max.alerts -C -e -o beginning 2>/dev/null | wc -l)

echo "  eagle-eye.thresholds:       $THRESHOLD_COUNT messages"
echo "  eagle-eye.eagle.max.alerts: $ALERT_COUNT messages"
echo ""
echo "✅ Test complete!"
