#!/bin/bash
echo "Loading 100 thresholds to Kafka with random values (40-90)..."
for i in {1..100}; do
  key=$(printf "property_%d;tenant_0;type_error;interface_api" $i | md5sum | cut -c1-16)
  # Random threshold between 40 and 90
  threshold=$((40 + RANDOM % 51))
  value="$key:$threshold:0"
  echo "$value" | kcat -b lab-stay-backplane.westus.cloudapp.azure.com:9092 -t eagle-eye.config -P -k "$key" 2>/dev/null
  if [ $((i % 20)) -eq 0 ]; then
    echo "  Loaded $i/100 (key: $key, threshold: $threshold)..."
  fi
done
echo "✅ Loaded 100 random thresholds (range: 40-90). Waiting 3 seconds for Kafka Streams to process..."
sleep 3
echo "✅ Ready to process alerts!"
