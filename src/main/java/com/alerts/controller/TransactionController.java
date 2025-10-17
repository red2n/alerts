package com.alerts.controller;

import com.alerts.model.PropertyThreshold;
import com.alerts.service.AlertProcessingService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class TransactionController {

    private final AlertProcessingService alertProcessingService;

    public TransactionController(AlertProcessingService alertProcessingService) {
        this.alertProcessingService = alertProcessingService;
    }

    public static class AlertRequest {
        private String key;
        private String errorCount;

        public String getKey() { return key; }
        public void setKey(String key) { this.key = key; }
        public String getErrorCount() { return errorCount; }
        public void setErrorCount(String errorCount) { this.errorCount = errorCount; }
    }

    @PostMapping("/alert")
    public ResponseEntity<Map<String, Object>> receiveAlert(@RequestBody AlertRequest request) {
        try {
            String hash = PropertyThreshold.generateHashFromCompositeKey(request.getKey());
            long errorCount = Long.parseLong(request.getErrorCount());

            AlertProcessingService.AlertResult result = alertProcessingService.processAlert(hash, errorCount);

            Map<String, Object> response = new HashMap<>();

            if ("threshold_breached".equals(result.getReason())) {
                response.put("status", "alert_triggered");
                response.put("key", request.getKey());
                response.put("errorCount", errorCount);
                response.put("threshold", result.getThreshold());
                response.put("alertTimes", result.getAlertTimes());
                return ResponseEntity.ok(response);
            } else if ("below_threshold".equals(result.getReason())) {
                response.put("status", "below_threshold");
                response.put("key", request.getKey());
                response.put("errorCount", errorCount);
                response.put("threshold", result.getThreshold());
                return ResponseEntity.ok(response);
            } else {
                response.put("status", "no_threshold");
                response.put("key", request.getKey());
                response.put("errorCount", errorCount);
                return ResponseEntity.ok(response);
            }
        } catch (Exception e) {
            Map<String, Object> error = new HashMap<>();
            error.put("status", "error");
            error.put("message", "Internal server error");
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
        }
    }

    @PostMapping("/test-mode")
    public ResponseEntity<Map<String, Object>> enableTestMode() {
        alertProcessingService.enableTestMode();
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "Test mode enabled with 100 thresholds");
        return ResponseEntity.ok(response);
    }
}
