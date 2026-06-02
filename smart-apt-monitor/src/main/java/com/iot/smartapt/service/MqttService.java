package com.iot.smartapt.service;

import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import org.eclipse.paho.client.mqttv3.*;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import jakarta.annotation.PostConstruct;

import com.iot.smartapt.model.SensorData;
import com.iot.smartapt.repository.SensorDataRepository;

@Service
public class MqttService {

    private MqttClient client;

    @Autowired
    private SensorDataRepository repository;

    @Autowired
    private DeviceStatusService statusService;   // ← THIS was missing

    @PostConstruct
    public void connectToBroker() {
        try {
            // Read broker URL from environment (for Docker), default to localhost
            String brokerUrl = System.getenv("MQTT_BROKER_URL") != null
                    ? System.getenv("MQTT_BROKER_URL")
                    : "tcp://192.168.137.1:1883";

            client = new MqttClient(brokerUrl, MqttClient.generateClientId(), new MemoryPersistence());
            client.connect();
            System.out.println("✅ Spring Boot connected to Mosquitto Broker!");

            ObjectMapper mapper = new ObjectMapper();

            // Subscribe to device status topic (LWT messages)
            client.subscribe("apartment/status", (topic, msg) -> {
                String payload = new String(msg.getPayload());
                System.out.println("📡 Device status: " + payload);
                boolean online = payload.contains("\"online\":true");
                statusService.setOnline(online);
            });

            // Subscribe to sensor data topic (one combined handler)
            client.subscribe("apartment/sensors", (topic, msg) -> {
                statusService.setOnline(true);  // Sensor message = device alive

                String payload = new String(msg.getPayload());
                System.out.println("📥 Received Data: " + payload);

                try {
                    JsonNode json = mapper.readTree(payload);

                    double temp = json.get("temperature").asDouble();
                    int light = json.get("light").asInt();
                    int fan = json.get("fan").asInt();
                    int led = json.get("led").asInt();
                    boolean fanManual = json.has("fanManual") && json.get("fanManual").asBoolean();
                    boolean ledManual = json.has("ledManual") && json.get("ledManual").asBoolean();
                    SensorData reading = new SensorData(temp, light, fan, led, fanManual, ledManual);
                    repository.save(reading);
                    System.out.println("💾 Full state saved to MSSQL!");

                } catch (Exception e) {
                    System.out.println("⚠️ Error parsing JSON: " + e.getMessage());
                }
            });

        } catch (MqttException e) {
            System.out.println("❌ Failed to connect to MQTT broker");
            e.printStackTrace();
        }
    }

    public void publishCommand(String topic, String command) {
        try {
            MqttMessage message = new MqttMessage(command.getBytes());
            client.publish(topic, message);
            System.out.println("📤 Published to " + topic + ": " + command);
        } catch (MqttException e) {
            e.printStackTrace();
        }
    }
}