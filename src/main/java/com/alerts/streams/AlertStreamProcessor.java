package com.alerts.streams;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.processor.AbstractProcessor;
import org.apache.kafka.streams.state.KeyValueStore;
import org.apache.kafka.streams.state.StoreBuilder;
import org.apache.kafka.streams.state.Stores;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import java.util.Collections;

/**
 * AlertStreamProcessor - Simplified to only load thresholds into state store
 *
 * Alert processing now happens directly in REST API controller for lower latency
 * This processor only maintains the threshold state store
 */
@Configuration
@EnableKafkaStreams
public class AlertStreamProcessor {

    @Bean
    public KStream<String, String> processAlerts(StreamsBuilder builder) {

        // Use PERSISTENT state store with changelog for production reliability
        // Changelog topic: eagle-eye-stream-processor-threshold-store-changelog
        // This topic must be created manually in all environments (see create-topics.sh)
        // Benefits: Fast recovery (2-3s), state persistence, disk-backed storage
        StoreBuilder<KeyValueStore<String, String>> thresholdStoreBuilder =
            Stores.keyValueStoreBuilder(
                Stores.persistentKeyValueStore("threshold-store"),
                Serdes.String(),
                Serdes.String()
            ).withLoggingEnabled(Collections.emptyMap());

        builder.addStateStore(thresholdStoreBuilder);

        // Load thresholds from eagle-eye.config topic into state store
        KStream<String, String> thresholds = builder.stream("eagle-eye.config",
            Consumed.with(Serdes.String(), Serdes.String()));

        thresholds
            .process(() -> new AbstractProcessor<String, String>() {
                @Override
                public void process(String key, String value) {
                    KeyValueStore<String, String> store = context().getStateStore("threshold-store");
                    store.put(key, value);
                    System.out.println("THRESHOLD LOADED: " + key + " -> " + value);
                }
            }, "threshold-store");

        // Return thresholds stream (no dynamic stream processing needed)
        // Alert processing now happens directly in REST API controller
        return thresholds;
    }

}
