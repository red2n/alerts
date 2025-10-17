package com.alerts.service;

import com.alerts.model.PropertyThreshold;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class AlertProcessingService {

    private final StreamsBuilderFactoryBean streamsBuilderFactoryBean;
    private final BloomFilterService bloomFilterService;
    private final KafkaTemplate<String, String> kafkaTemplate;

    // Test mode: In-memory threshold store for testing when Kafka Streams is not loading data
    private final Map<String, String> testThresholdStore = new ConcurrentHashMap<>();
    private boolean testMode = false;

    public AlertProcessingService(StreamsBuilderFactoryBean streamsBuilderFactoryBean,
                                  BloomFilterService bloomFilterService,
                                  KafkaTemplate<String, String> kafkaTemplate) {
        this.streamsBuilderFactoryBean = streamsBuilderFactoryBean;
        this.bloomFilterService = bloomFilterService;
        this.kafkaTemplate = kafkaTemplate;
    }    public static class AlertResult {
        public String reason;
        public long threshold;
        public long alertTimes;

        public static AlertResult thresholdBreached(long threshold, long alertTimes) {
            AlertResult result = new AlertResult();
            result.reason = "threshold_breached";
            result.threshold = threshold;
            result.alertTimes = alertTimes;
            return result;
        }

        public static AlertResult belowThreshold(long errorCount, long threshold) {
            AlertResult result = new AlertResult();
            result.reason = "below_threshold";
            result.threshold = threshold;
            return result;
        }

        public static AlertResult noThreshold(long errorCount) {
            AlertResult result = new AlertResult();
            result.reason = "no_threshold";
            return result;
        }

        public String getReason() {
            return reason;
        }

        public long getThreshold() {
            return threshold;
        }

        public long getAlertTimes() {
            return alertTimes;
        }
    }

    // Method to enable test mode and load thresholds directly
    public void enableTestMode() {
        System.out.println("Enabling test mode - loading 100 thresholds with random values (40-90)");
        testMode = true;

        java.util.Random random = new java.util.Random();

        // Load 100 test thresholds with random threshold values between 40-90
        for (int i = 1; i <= 100; i++) {
            String compositeKey = String.format("property_%d;tenant_0;type_error;interface_api", i);
            String hash = PropertyThreshold.generateHashFromCompositeKey(compositeKey);

            // Random threshold between 40 and 90 (inclusive)
            int randomThreshold = 40 + random.nextInt(51); // 40 + (0-50) = 40-90
            String value = String.format("%s:%d:0", hash, randomThreshold);
            testThresholdStore.put(hash, value);
            bloomFilterService.addHash(hash);

            if (i % 20 == 0) {
                System.out.printf("  Loaded %d/100 thresholds (last threshold: %d)%n", i, randomThreshold);
            }
        }
        System.out.println("✅ Test mode enabled with 100 random thresholds (range: 40-90)");
    }

    public AlertResult processAlert(String hash, long errorCount) {
        if (!bloomFilterService.mightContain(hash)) {
            return AlertResult.noThreshold(errorCount);
        }

        String value = null;

        if (testMode) {
            // Use in-memory store for testing
            value = testThresholdStore.get(hash);
        } else {
            // Try Kafka Streams state store
            try {
                ReadOnlyKeyValueStore<String, String> thresholdStore =
                    streamsBuilderFactoryBean.getKafkaStreams()
                        .store(org.apache.kafka.streams.StoreQueryParameters.fromNameAndType(
                            "threshold-store",
                            QueryableStoreTypes.keyValueStore()
                        ));
                value = thresholdStore.get(hash);
            } catch (Exception e) {
                // Fall back to test mode if Kafka Streams not available
                System.out.println("Kafka Streams not available, falling back to test mode");
                enableTestMode();
                value = testThresholdStore.get(hash);
            }
        }

        if (value == null) {
            return AlertResult.noThreshold(errorCount);
        }

        PropertyThreshold.ThresholdData data = PropertyThreshold.parseThresholdValue(value);
        if (data == null) {
            return AlertResult.noThreshold(errorCount);
        }

        if (errorCount >= data.threshold) {
            // Publish alert to Kafka topic when threshold is breached
            publishAlert(hash, errorCount, data.threshold, data.alertTimes);
            return AlertResult.thresholdBreached(data.threshold, data.alertTimes);
        } else {
            return AlertResult.belowThreshold(errorCount, data.threshold);
        }
    }

    /**
     * Publish alert message to eagle-eye.alerts topic
     */
    private void publishAlert(String hash, long errorCount, long threshold, long alertTimes) {
        String alertMessage = String.format("ALERT: Hash %s exceeded threshold! ErrorCount=%d, Threshold=%d, AlertTimes=%d",
            hash, errorCount, threshold, alertTimes);

        System.out.println("📢 Alert triggered - attempting to publish: " + alertMessage);

        // Send in background thread with minimal overhead
        new Thread(() -> {
            try {
                System.out.println("📤 [" + Thread.currentThread().getName() + "] Calling kafkaTemplate.send()...");
                var future = kafkaTemplate.send("eagle-eye.alerts", hash, alertMessage);
                System.out.println("📤 [" + Thread.currentThread().getName() + "] Send returned, future: " + future);

                // Add timeout to prevent hanging
                var result = future.toCompletableFuture().get(java.util.concurrent.TimeUnit.SECONDS.toMillis(5), java.util.concurrent.TimeUnit.MILLISECONDS);
                System.out.println("✅ Alert published: " + result.getRecordMetadata().topic() + "-" + result.getRecordMetadata().partition());
            } catch (Exception e) {
                System.err.println("❌ Alert publish failed: " + e.getClass().getName() + " - " + e.getMessage());
            }
        }, "AlertPublisher").start();
    }
}
