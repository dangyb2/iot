package com.iot.smartapt.model;


import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "sensor_readings")
public class SensorData {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private double temperature;
    private int lightLevel;
    private int fanStatus;
    private int ledStatus;
    private boolean fanManual;
    private boolean ledManual;

    private LocalDateTime timestamp;

    public SensorData() {}

    public SensorData(double temperature, int lightLevel, int fanStatus,
                      int ledStatus, boolean fanManual, boolean ledManual) {
        this.temperature = temperature;
        this.lightLevel = lightLevel;
        this.fanStatus = fanStatus;
        this.ledStatus = ledStatus;
        this.fanManual = fanManual;
        this.ledManual = ledManual;
        this.timestamp = LocalDateTime.now();
    }
    public Long getId() { return id; }
    public double getTemperature() { return temperature; }
    public int getLightLevel() { return lightLevel; }
    public int getFanStatus() { return fanStatus; }
    public int getLedStatus() { return ledStatus; }
    public LocalDateTime getTimestamp() { return timestamp; }
    public boolean isFanManual() { return fanManual; }
    public void setFanManual(boolean fanManual) { this.fanManual = fanManual; }
    public boolean isLedManual() { return ledManual; }
    public void setLedManual(boolean ledManual) { this.ledManual = ledManual; }
}