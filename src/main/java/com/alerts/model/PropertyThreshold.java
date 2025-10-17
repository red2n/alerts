package com.alerts.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PropertyThreshold {

    private String tenantId;
    private String propertyId;
    private String interfaceId;
    private String transactionType;
    private int thresholdValue;

    public String generateHashKey() {
        String composite = String.format("%s:%s:%s:%s",
            tenantId, propertyId, interfaceId, transactionType);

        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(composite.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            
            StringBuilder hexString = new StringBuilder();
            for (int i = 0; i < 8; i++) {
                String hex = Integer.toHexString(0xff & hash[i]);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not found", e);
        }
    }

    public static String generateHashFromCompositeKey(String compositeKey) {
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(compositeKey.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            
            StringBuilder hexString = new StringBuilder();
            for (int i = 0; i < 8; i++) {
                String hex = Integer.toHexString(0xff & hash[i]);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not found", e);
        }
    }

    public static class ThresholdData {
        public String hash;
        public long threshold;
        public long alertTimes;

        public ThresholdData(String hash, long threshold, long alertTimes) {
            this.hash = hash;
            this.threshold = threshold;
            this.alertTimes = alertTimes;
        }
    }

    public static ThresholdData parseThresholdValue(String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        String[] parts = value.split(":");
        if (parts.length != 3) {
            return null;
        }
        return new ThresholdData(parts[0], Long.parseLong(parts[1]), Long.parseLong(parts[2]));
    }
}
