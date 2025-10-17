# Alert Processing System - Flow Diagram

## System Architecture Overview

This document explains the complete flow of the Alert Processing System using sequence diagrams.

---

## 1. System Startup & Threshold Loading

```mermaid
sequenceDiagram
    participant App as Spring Boot Application
    participant TL as ThresholdLoader
    participant KT as KafkaTemplate
    participant KTopic as Kafka Topic (thresholds)
    participant BF as BloomFilterService
    participant KS as Kafka Streams Processor

    Note over App,KS: Application Startup Phase

    App->>TL: run() - CommandLineRunner
    TL->>TL: Generate 100 random thresholds (0-100)

    loop For each property (1-100)
        TL->>TL: Create composite key
        TL->>TL: Generate hash (MD5, first 16 chars)
        TL->>BF: addHash(hash) - Add to Bloom filter
        TL->>TL: Create value (hash:threshold:alertTimes)
        TL->>KT: send("eagle-eye.thresholds", hash, value)
        KT->>KTopic: Publish threshold message
    end

    TL-->>App: 100 thresholds loaded

    Note over KS: Kafka Streams starts processing
    KS->>KTopic: Subscribe to eagle-eye.thresholds
    KS->>KS: Build state store (threshold-store)
    KTopic-->>KS: Stream threshold messages
    KS->>KS: Populate threshold-store with key-value pairs
```

---

## 2. Alert Request Processing Flow

```mermaid
sequenceDiagram
    participant Client as API Client
    participant Controller as TransactionController
    participant APS as AlertProcessingService
    participant BF as BloomFilterService
    participant Store as State Store
    participant Thread as Background Thread
    participant KT as KafkaTemplate
    participant ATopic as Kafka Topic (alerts)

    Note over Client,ATopic: Alert Processing Flow

    Client->>Controller: POST /api/alert {key, errorCount}
    Controller->>Controller: Parse request
    Controller->>Controller: Generate hash from composite key

    Controller->>APS: processAlert(hash, errorCount)

    alt Test Mode Enabled
        APS->>Store: Get threshold from testThresholdStore
    else Kafka Streams Mode
        APS->>BF: mightContain(hash)
        alt Hash exists in Bloom Filter
            BF-->>APS: true
            APS->>Store: Get threshold from Kafka state store
        else Hash not in Bloom Filter
            BF-->>APS: false
            APS-->>Controller: AlertResult no_threshold
        end
    end

    alt Threshold found
        APS->>APS: Compare errorCount vs threshold

        alt errorCount greater than threshold
            Note over APS: THRESHOLD BREACHED!
            APS->>APS: Increment alertTimes
            APS->>Thread: publishAlert(hash, errorCount, threshold, alertTimes)

            Note over Thread: Async publishing in background
            Thread->>KT: send to eagle-eye.eagle.max.alerts
            KT->>ATopic: Publish alert message
            Thread->>Thread: Log Alert published

            APS-->>Controller: AlertResult threshold_breached
        else errorCount less than or equal to threshold
            APS-->>Controller: AlertResult below_threshold
        end
    else Threshold not found
        APS-->>Controller: AlertResult no_threshold
    end

    Controller->>Controller: Build JSON response
    Controller-->>Client: HTTP 200 with status
```

---

## 3. Test Mode Flow (In-Memory Testing)

```mermaid
sequenceDiagram
    participant Client as API Client
    participant Controller as TransactionController
    participant APS as AlertProcessingService
    participant Store as testThresholdStore (ConcurrentHashMap)

    Note over Client,Store: Test Mode Activation

    Client->>Controller: POST /api/test-mode
    Controller->>APS: enableTestMode()

    loop For 100 properties
        APS->>APS: Generate hash from property_N
        APS->>APS: Generate random threshold (40-90)
        APS->>Store: Put(hash, "hash:threshold:0")
    end

    APS->>APS: Set testMode = true
    APS-->>Controller: Success
    Controller-->>Client: {"status":"success", "message":"Test mode enabled"}

    Note over Client,Store: Subsequent Alert Requests

    Client->>Controller: POST /api/alert {key, errorCount}
    Controller->>APS: processAlert(hash, errorCount)
    APS->>Store: Get threshold from testThresholdStore
    Store-->>APS: threshold data
    APS->>APS: Process alert logic
    APS-->>Controller: AlertResult
    Controller-->>Client: Response
```

---

## 4. Complete End-to-End Flow

```mermaid
sequenceDiagram
    participant User as User/Test Script
    participant API as REST API (:8080)
    participant App as Alert Application
    participant Kafka as Kafka Cluster
    participant Topics as Kafka Topics

    Note over User,Topics: Complete System Flow

    rect rgb(200, 220, 250)
        Note over App,Kafka: Phase 1: System Initialization
        App->>Kafka: Load 100 random thresholds (0-100)
        App->>Topics: Publish to eagle-eye.thresholds
        App->>App: Build Kafka Streams state store
    end

    rect rgb(220, 250, 200)
        Note over User,Topics: Phase 2: Alert Processing
        User->>API: POST /api/alert<br/>{property_42, errorCount=85}
        API->>App: Process alert request
        App->>App: Check Bloom filter
        App->>App: Get threshold from state store
        App->>App: Compare: 85 > threshold?

        alt Alert Triggered (85 > threshold)
            App->>Kafka: Async send to eagle-eye.eagle.max.alerts
            App->>Topics: Store alert message
            API-->>User: {"status":"alert_triggered", "errorCount":85, "threshold":60}
        else Below Threshold
            API-->>User: {"status":"below_threshold", "errorCount":85, "threshold":100}
        end
    end

    rect rgb(250, 220, 200)
        Note over User,Topics: Phase 3: Verification
        User->>Kafka: kcat - read eagle-eye.eagle.max.alerts
        Kafka-->>User: ALERT: Hash xxx exceeded threshold!
    end
```

---

## Key Components

### 1. **ThresholdLoader**
- Runs on application startup (CommandLineRunner)
- Generates 100 random thresholds (0-100 range)
- Publishes to `eagle-eye.thresholds` Kafka topic
- Adds hashes to Bloom filter for quick lookup

### 2. **AlertProcessingService**
- Core alert processing logic
- Supports two modes:
  - **Kafka Streams Mode**: Uses state store from Kafka
  - **Test Mode**: Uses in-memory ConcurrentHashMap
- Compares errorCount against threshold
- Triggers async alert publishing if threshold breached

### 3. **TransactionController**
- REST API endpoints:
  - `POST /api/alert` - Process alert request
  - `POST /api/test-mode` - Enable in-memory test mode
- Generates hash from composite key
- Returns alert status to client

### 4. **BloomFilterService**
- Fast probabilistic hash lookup
- Reduces unnecessary state store queries
- No false negatives (if it says "not present", it's definitely not)

### 5. **Kafka Topics**
- **eagle-eye.thresholds**: Stores threshold configurations
- **eagle-eye.eagle.max.alerts**: Stores triggered alerts
- **eagle-eye-stream-processor-threshold-store-changelog**: Kafka Streams state store changelog

---

## Data Flow Summary

```
1. Startup: ThresholdLoader → Kafka (thresholds) → Kafka Streams (state store)
2. Request: Client → REST API → AlertProcessingService
3. Lookup: Bloom Filter → State Store → Get Threshold
4. Compare: errorCount vs threshold
5. Alert: If breached → Background Thread → Kafka (alerts)
6. Response: Status → Client
```

---

## Alert Decision Logic

```
IF errorCount > threshold:
    ➜ status = "alert_triggered"
    ➜ Publish to eagle-eye.eagle.max.alerts
    ➜ Increment alertTimes

ELSE IF errorCount <= threshold:
    ➜ status = "below_threshold"
    ➜ No alert published

ELSE (no threshold found):
    ➜ status = "no_threshold"
    ➜ No alert published
```

---

## Testing Flow

### Random Test Execution
```bash
./test-random-alerts.sh
```

**Process:**
1. Generate 20 random requests
2. Random property IDs (1-100)
3. Random error counts (0-150)
4. Send to API endpoint
5. Collect results
6. Verify Kafka topics
7. Display summary

**Expected Results:**
- Mix of "alert_triggered" and "below_threshold"
- Alerts published to Kafka
- 100% request success rate

---

## Configuration

### Kafka Bootstrap Server
```properties
spring.kafka.bootstrap-servers=lab-stay-backplane.westus.cloudapp.azure.com:9092
```

### Threshold Range
- **Original**: Fixed at 50 for all properties
- **Random v1**: 40-90 range
- **Random v2 (Current)**: 0-100 range (completely random)

### Test Mode Range
- 40-90 (narrower range for testing)

---

## Performance Characteristics

- **Threshold Loading**: ~750ms for 100 properties
- **Alert Processing**: < 10ms per request
- **Async Publishing**: Non-blocking, ~5 second timeout
- **Throughput**: Tested with 100 concurrent requests
- **Success Rate**: 100% in controlled tests

---

Generated: 2025-10-17
