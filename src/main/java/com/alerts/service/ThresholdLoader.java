package com.alerts.service;

import com.alerts.model.PropertyThreshold;
import org.springframework.boot.CommandLineRunner;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class ThresholdLoader implements CommandLineRunner {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final BloomFilterService bloomFilterService;

    public ThresholdLoader(KafkaTemplate<String, String> kafkaTemplate, BloomFilterService bloomFilterService) {
        this.kafkaTemplate = kafkaTemplate;
        this.bloomFilterService = bloomFilterService;
    }

    // Enabled to load random thresholds on startup
    @Override
    public void run(String... args) throws Exception {
        System.out.println("Loading random thresholds to Kafka...");
        long startTime = System.currentTimeMillis();

        int numProperties = 100;

        for (int i = 1; i <= numProperties; i++) {
            String compositeKey = String.format("property_%d;tenant_0;type_error;interface_api", i);
            String hash = PropertyThreshold.generateHashFromCompositeKey(compositeKey);

            bloomFilterService.addHash(hash);

            // Random threshold between 0-100 for each property
            long threshold = (long)(Math.random() * 101);
            long alertTimes = 0;
            String value = String.format("%s:%d:%d", hash, threshold, alertTimes);

            kafkaTemplate.send("eagle-eye.config", hash, value);

            if (i % 25 == 0) {
                System.out.printf("  Loaded %d/100 (last threshold: %d)%n", i, threshold);
            }
        }

        long elapsed = System.currentTimeMillis() - startTime;
        System.out.printf("✅ Random thresholds loaded (%d properties, range: 0-100, time: %dms)%n", numProperties, elapsed);

        Thread.sleep(2000);
        System.out.println("Ready to process alerts");
    }
}
