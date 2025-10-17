package com.alerts.service;

import com.google.common.hash.BloomFilter;
import com.google.common.hash.Funnels;
import org.springframework.stereotype.Service;

@Service
public class BloomFilterService {

    private BloomFilter<String> thresholdFilter;
    private static final int EXPECTED_PROPERTIES = 60000;
    private static final double FALSE_POSITIVE_RATE = 0.01;

    public BloomFilterService() {
        thresholdFilter = BloomFilter.create(
            Funnels.stringFunnel(java.nio.charset.StandardCharsets.UTF_8),
            EXPECTED_PROPERTIES,
            FALSE_POSITIVE_RATE
        );
        System.out.println("Bloom Filter initialized for " + EXPECTED_PROPERTIES + " properties, FP rate: " + (FALSE_POSITIVE_RATE * 100) + "%");
    }

    public void addHash(String hash) {
        thresholdFilter.put(hash);
    }

    public boolean mightContain(String hash) {
        return thresholdFilter.mightContain(hash);
    }
}
