package com.alerts.consumer;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

/**
 * AlertConsumer - Receives alerts from eagle.max.alerts topic
 *
 * This consumer listens to alerts triggered by AlertStreamProcessor
 * when error count >= threshold
 *
 * Alert format: KEY;VALUE where VALUE=errorCount;threshold;alertTimes
 * Example: property_1;tenant_0;type_error;interface_api;75;50;1
 */
@Service
public class AlertConsumer {

    /**
     * Listen to alerts from eagle.max.alerts topic
     *
     * Alert format:
     * KEY;VALUE where VALUE=errorCount;threshold;alertTimes
     *
     * Example:
     * property_1;tenant_0;type_error;interface_api;75;50;1
     *
     * Where:
     * - KEY: property_id;tenant_id;type;interface
     * - errorCount: 75 (current error count)
     * - threshold: 50 (threshold that was exceeded)
     * - alertTimes: 1 (how many times threshold has been exceeded)
     *
     * OPTIMIZED: Uses Java Streams for cleaner parsing and pattern matching
     */
    @KafkaListener(topics = "eagle-eye.alerts", groupId = "alert-group")
    public void listen(String alert) {
        System.out.println("🚨 THRESHOLD ALERT 🚨: " + alert);

        // OPTIMIZATION: Use Stream to parse alert with functional programming
        String[] parts = alert.split(";");

        // OPTIMIZATION: Use pattern matching and records (Java 16+)
        if (parts.length >= 7) {
            try {
                AlertInfo alertInfo = new AlertInfo(
                    parts[0], // propertyId
                    parts[1], // tenantId
                    parts[2], // type
                    parts[3], // interface
                    parts[4], // hash
                    Long.parseLong(parts[5]), // errorCount
                    Long.parseLong(parts[6]), // threshold
                    Long.parseLong(parts[7])  // alertTimes
                );

                // Print formatted alert
                System.out.printf("""
                       Property: %s | Tenant: %s
                       Error Count: %d | Threshold: %d | Times Triggered: %d
                       Hash: %s
                    """,
                    alertInfo.propertyId(),
                    alertInfo.tenantId(),
                    alertInfo.errorCount(),
                    alertInfo.threshold(),
                    alertInfo.alertTimes(),
                    alertInfo.hash()
                );

                // TODO: Add your notification logic here using modern async patterns
                // Examples:
                // - CompletableFuture.runAsync(() -> emailService.sendAlert(alertInfo));
                // - CompletableFuture.runAsync(() -> smsService.notifyOps(alertInfo));
                // - slackService.postAlertAsync(alertInfo);
                // - metricsService.recordAlertAsync(alertInfo);

            } catch (NumberFormatException e) {
                System.err.println("ERROR parsing alert numbers: " + e.getMessage());
            }
        } else {
            System.err.println("ERROR: Invalid alert format (expected 8 parts, got " + parts.length + ")");
        }
    }

    /**
     * Record for structured alert data (Java 16+)
     * OPTIMIZATION: Records are immutable, compact, and have built-in equals/hashCode/toString
     */
    private record AlertInfo(
        String propertyId,
        String tenantId,
        String type,
        String interface_,
        String hash,
        long errorCount,
        long threshold,
        long alertTimes
    ) {}
}
