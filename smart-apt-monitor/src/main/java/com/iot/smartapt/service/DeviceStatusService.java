package com.iot.smartapt.service;

import org.springframework.stereotype.Service;
import java.time.Instant;

@Service
public class DeviceStatusService {
    private volatile boolean online = false;
    private volatile Instant lastSeen = null;

    public void setOnline(boolean online) {
        this.online = online;
        this.lastSeen = Instant.now();
    }

    public boolean isOnline() {
        // Treat as offline if no message in last 15 seconds
        if (lastSeen == null) return false;
        return online && Instant.now().getEpochSecond() - lastSeen.getEpochSecond() < 15;
    }

    public Instant getLastSeen() {
        return lastSeen;
    }
}