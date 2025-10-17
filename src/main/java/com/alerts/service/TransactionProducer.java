package com.alerts.service;

import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

/**
 * TransactionProducer - Sends alerts to Kafka
 *
 * Sends error count data from REST endpoint to "alerts" topic
 * where AlertStreamProcessor compares with static thresholds
 */
@Service
public class TransactionProducer {

    private final KafkaTemplate<String, String> kafkaTemplate;

    public TransactionProducer(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    /**
     * Send alert to Kafka
     *
     * @param key Format: property_id;tenant_id;type;interface
     * @param errorCount Error count as string (e.g., "75")
     */
    public void sendAlert(String key, String errorCount) {
        // Key: property_id;tenant_id;type;interface
        // Value: error count (just the number)
        kafkaTemplate.send("eagle-eye.alerts", key, errorCount);
        System.out.println("Alert sent - Key: " + key + ", ErrorCount: " + errorCount);
    }
}
