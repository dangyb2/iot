package com.iot.smartapt.service;

import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.eclipse.paho.client.mqttv3.*;
import org.springframework.beans.factory.annotation.Value;
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
    private DeviceStatusService statusService;

    @Value("${mqtt.broker.url}")
    private String brokerUrl;

    @Value("${mqtt.username:}")
    private String mqttUsername;

    @Value("${mqtt.password:}")
    private String mqttPassword;

    @Value("${mqtt.client.id}")
    private String clientId;
    @PostConstruct
    public void connectToBroker() {
        try {
            System.out.println("🔌 Connecting to MQTT: " + brokerUrl);
            client = new MqttClient(brokerUrl, clientId, new MemoryPersistence());

            MqttConnectOptions options = new MqttConnectOptions();
            options.setAutomaticReconnect(true);
            options.setCleanSession(true);
            options.setConnectionTimeout(30);
            options.setKeepAliveInterval(60);

            if (mqttUsername != null && !mqttUsername.isEmpty()) {
                options.setUserName(mqttUsername);
                options.setPassword(mqttPassword.toCharArray());
                System.out.println("🔐 Using MQTT auth: " + mqttUsername);
            }

            client.connect(options);
            System.out.println("✅ Spring Boot connected to MQTT Broker!");
            ObjectMapper mapper = new ObjectMapper();

            // Subscribe trạng thái thiết bị (LWT)
            client.subscribe("apartment/status", (topic, msg) -> {
                String payload = new String(msg.getPayload());
                System.out.println("📡 Device status: " + payload);
                statusService.setOnline(payload.contains("\"online\":true"));
            });

            // Subscribe dữ liệu cảm biến
            client.subscribe("apartment/sensors", (topic, msg) -> {
                statusService.setOnline(true);
                String payload = new String(msg.getPayload());
                System.out.println("📥 Received Data: " + payload);

                try {
                    JsonNode json = mapper.readTree(payload);

                    // ── Đọc mảng 5 nhiệt độ ──────────────────────────
                    double[] temps = new double[5];
                    double[] humis = new double[5];
                    int[]    leds  = new int[5];

                    if (json.has("temperatures") && json.get("temperatures").isArray()) {
                        JsonNode arr = json.get("temperatures");
                        for (int i = 0; i < Math.min(5, arr.size()); i++)
                            temps[i] = arr.get(i).asDouble();
                    } else {
                        // Tương thích ngược với JSON cũ
                        temps[0] = json.has("temperature") ? json.get("temperature").asDouble() : 0;
                    }

                    if (json.has("humidities") && json.get("humidities").isArray()) {
                        JsonNode arr = json.get("humidities");
                        for (int i = 0; i < Math.min(5, arr.size()); i++)
                            humis[i] = arr.get(i).asDouble();
                    }

                    if (json.has("leds") && json.get("leds").isArray()) {
                        JsonNode arr = json.get("leds");
                        for (int i = 0; i < Math.min(5, arr.size()); i++)
                            leds[i] = arr.get(i).asInt();
                    } else {
                        leds[0] = json.has("led") ? json.get("led").asInt() : 0;
                    }

                    // ── Đọc các field khác ────────────────────────────
                    int     light     = json.has("light")     ? json.get("light").asInt()         : 0;
                    int     fan       = json.has("fan")       ? json.get("fan").asInt()           : 0;
                    boolean fanManual = json.has("fanManual") && json.get("fanManual").asBoolean();
                    boolean ledManual = json.has("ledManual") && json.get("ledManual").asBoolean();
                    double  distance  = json.has("distance")  ? json.get("distance").asDouble()   : 0;
                    int     wind      = json.has("wind")      ? json.get("wind").asInt()          : 0;

                    // ── Lưu vào MSSQL ─────────────────────────────────
                    SensorData reading = new SensorData(
                            temps, humis, light, fan, leds,
                            fanManual, ledManual, distance, wind
                    );
                    repository.save(reading);
                    System.out.println("💾 Saved to MSSQL! T0=" + temps[0]
                            + " H0=" + humis[0] + " Dist=" + distance + " Wind=" + wind + "%");

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
