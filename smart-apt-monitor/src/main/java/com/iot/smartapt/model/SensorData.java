package com.iot.smartapt.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "sensor_readings")
public class SensorData {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ── Cũ (giữ nguyên cho tương thích) ──────────────────────────────
    private double temperature;   // Nhiệt độ phòng 0 (phòng khách)
    private int    lightLevel;
    private int    fanStatus;
    private int    ledStatus;     // Trạng thái LED phòng 0
    private boolean fanManual;
    private boolean ledManual;

    // ── Mới: 5 phòng ─────────────────────────────────────────────────
    private Double temp0; private Double temp1; private Double temp2;
    private Double temp3; private Double temp4;

    private Double humi0; private Double humi1; private Double humi2;
    private Double humi3; private Double humi4;

    private Integer led0; private Integer led1; private Integer led2;
    private Integer led3; private Integer led4;

    // ── Mới: cảm biến khác ────────────────────────────────────────────
    private Double  distance;   // HC-SR04 (cm)
    private Integer wind;       // Biến trở mô phỏng gió (0-100%)

    private LocalDateTime timestamp;

    public SensorData() {}

    // Constructor cũ — vẫn giữ để không lỗi
    public SensorData(double temperature, int lightLevel, int fanStatus,
                      int ledStatus, boolean fanManual, boolean ledManual) {
        this.temperature = temperature;
        this.lightLevel  = lightLevel;
        this.fanStatus   = fanStatus;
        this.ledStatus   = ledStatus;
        this.fanManual   = fanManual;
        this.ledManual   = ledManual;
        this.timestamp   = LocalDateTime.now();
    }

    // Constructor mới — đầy đủ
    public SensorData(double[] temps, double[] humis, int light,
                      int fan, int[] leds, boolean fanManual, boolean ledManual,
                      double distance, int wind) {
        // Phòng 0 = giá trị chính (tương thích ngược)
        this.temperature = temps[0];
        this.lightLevel  = light;
        this.fanStatus   = fan;
        this.ledStatus   = leds[0];
        this.fanManual   = fanManual;
        this.ledManual   = ledManual;

        // 5 phòng
        this.temp0 = temps[0]; this.temp1 = temps[1]; this.temp2 = temps[2];
        this.temp3 = temps[3]; this.temp4 = temps[4];

        this.humi0 = humis[0]; this.humi1 = humis[1]; this.humi2 = humis[2];
        this.humi3 = humis[3]; this.humi4 = humis[4];

        this.led0 = leds[0]; this.led1 = leds[1]; this.led2 = leds[2];
        this.led3 = leds[3]; this.led4 = leds[4];

        this.distance  = distance;
        this.wind      = wind;
        this.timestamp = LocalDateTime.now();
    }

    // ── Getters ───────────────────────────────────────────────────────
    public Long          getId()          { return id; }
    public double        getTemperature() { return temperature; }
    public int           getLightLevel()  { return lightLevel; }
    public int           getFanStatus()   { return fanStatus; }
    public int           getLedStatus()   { return ledStatus; }
    public boolean       isFanManual()    { return fanManual; }
    public boolean       isLedManual()    { return ledManual; }
    public LocalDateTime getTimestamp()   { return timestamp; }

    public Double  getTemp0() { return temp0; } public Double  getTemp1() { return temp1; }
    public Double  getTemp2() { return temp2; } public Double  getTemp3() { return temp3; }
    public Double  getTemp4() { return temp4; }

    public Double  getHumi0() { return humi0; } public Double  getHumi1() { return humi1; }
    public Double  getHumi2() { return humi2; } public Double  getHumi3() { return humi3; }
    public Double  getHumi4() { return humi4; }

    public Integer getLed0()  { return led0;  } public Integer getLed1()  { return led1;  }
    public Integer getLed2()  { return led2;  } public Integer getLed3()  { return led3;  }
    public Integer getLed4()  { return led4;  }

    public Double  getDistance() { return distance; }
    public Integer getWind()     { return wind; }

    // ── Setters ───────────────────────────────────────────────────────
    public void setFanManual(boolean fanManual) { this.fanManual = fanManual; }
    public void setLedManual(boolean ledManual) { this.ledManual = ledManual; }
}
