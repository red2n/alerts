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

    // Disabled - use load-thresholds.sh script instead
    // @Override
    public void run(String... args) throws Exception {
        System.out.println("Loading thresholds to Kafka...");
        long startTime = System.currentTimeMillis();

        int numProperties = 100;

        for (int i = 1; i <= numProperties; i++) {
            String compositeKey = String.format("property_%d;tenant_0;type_error;interface_api", i);
            String hash = PropertyThreshold.generateHashFromCompositeKey(compositeKey);

            bloomFilterService.addHash(hash);

            long threshold = 50;
            long alertTimes = 0;
            String value = String.format("%s:%d:%d", hash, threshold, alertTimes);

            kafkaTemplate.send("eagle-eye.thresholds", hash, value);
        }

        long elapsed = System.currentTimeMillis() - startTime;
        System.out.printf("Thresholds loaded (%d properties in %dms)%n", numProperties, elapsed);

        Thread.sleep(2000);
        System.out.println("Ready to process alerts");
    }
}
