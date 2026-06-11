package com.iot.smartapt.controller;

import com.iot.smartapt.model.SensorData;
import com.iot.smartapt.repository.SensorDataRepository;
import com.iot.smartapt.service.DeviceStatusService;
import com.iot.smartapt.service.MqttService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.Authentication;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ApiController {

    @Autowired private SensorDataRepository repository;
    @Autowired private DeviceStatusService  statusService;
    @Autowired private MqttService          mqttService;

    // ───── BIẾN STATIC LƯU CẤU HÌNH HIỆN TẠI ─────
    private static volatile double tempOn      = 30.0;
    private static volatile double tempOff     = 27.0;
    private static volatile double tempDanger  = 35.0;
    private static volatile double humiOn      = 80.0;
    private static volatile double humiOff     = 72.0;
    private static volatile int    lightOn     = 1000;
    private static volatile int    lightOff    = 1200;

    // 1. Lịch sử dữ liệu
    @GetMapping("/data")
    public List<SensorData> getAllData() {
        return repository.findAll();
    }

    // 2. Điều khiển Quạt
    @PostMapping("/control/fan")
    public String controlFan(@RequestParam int status) {
        mqttService.publishCommand("apartment/control/fan", String.valueOf(status));
        return "Fan command sent: " + status;
    }

    // 3. Điều khiển tất cả LED
    @PostMapping("/control/led")
    public String controlLed(@RequestParam int status) {
        for (int i = 0; i < 5; i++) {
            mqttService.publishCommand("apartment/control/led/" + i, String.valueOf(status));
        }
        return "All LED command sent: " + status;
    }

    // 4. Điều khiển từng LED riêng lẻ
    @PostMapping("/control/led/{index}")
    public ResponseEntity<?> controlLedByIndex(
            @PathVariable int index,
            @RequestParam int status) {
        if (index < 0 || index > 4) {
            return ResponseEntity.badRequest().body("LED index phải từ 0 đến 4");
        }
        mqttService.publishCommand("apartment/control/led/" + index, String.valueOf(status));
        return ResponseEntity.ok("LED " + index + " command sent: " + status);
    }

    // 5. Tắt còi khẩn cấp
    @PostMapping("/control/buzzer")
    public String controlBuzzer(@RequestParam int status) {
        mqttService.publishCommand("apartment/control/buzzer", String.valueOf(status));
        return "Buzzer command sent: " + status;
    }

    // 6. LẤY cấu hình hiện tại (MỚI - cho Flutter)
    @GetMapping("/config")
    public Map<String, Object> getConfig() {
        Map<String, Object> response = new HashMap<>();
        response.put("tempOn",     tempOn);
        response.put("tempOff",    tempOff);
        response.put("tempDanger", tempDanger);
        response.put("humiOn",     humiOn);
        response.put("humiOff",    humiOff);
        response.put("lightOn",    lightOn);
        response.put("lightOff",   lightOff);
        return response;
    }

    // 7. Cập nhật cấu hình (chỉ Admin)
    @PostMapping("/config")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> updateConfig(@RequestBody Map<String, Object> configData) {
        try {
            // Lưu vào biến static của server
            if (configData.containsKey("tempOn"))
                tempOn = ((Number) configData.get("tempOn")).doubleValue();
            if (configData.containsKey("tempOff"))
                tempOff = ((Number) configData.get("tempOff")).doubleValue();
            if (configData.containsKey("tempDanger"))
                tempDanger = ((Number) configData.get("tempDanger")).doubleValue();
            if (configData.containsKey("humiOn"))
                humiOn = ((Number) configData.get("humiOn")).doubleValue();
            if (configData.containsKey("humiOff"))
                humiOff = ((Number) configData.get("humiOff")).doubleValue();
            if (configData.containsKey("lightOn"))
                lightOn = ((Number) configData.get("lightOn")).intValue();
            if (configData.containsKey("lightOff"))
                lightOff = ((Number) configData.get("lightOff")).intValue();

            // Gửi xuống ESP32 qua MQTT
            ObjectMapper mapper = new ObjectMapper();
            String jsonPayload = mapper.writeValueAsString(configData);
            mqttService.publishCommand("apartment/config", jsonPayload);

            System.out.println("📝 Cấu hình mới: tempOn=" + tempOn + " tempDanger=" + tempDanger);
            return ResponseEntity.ok("Config updated");
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    // 8. Trạng thái thiết bị
    @GetMapping("/status")
    public Map<String, Object> getDeviceStatus() {
        Map<String, Object> response = new HashMap<>();
        response.put("online", statusService.isOnline());
        response.put("lastSeen", statusService.getLastSeen() != null
                ? statusService.getLastSeen().toString() : null);
        return response;
    }

    // 9. Thông tin user đăng nhập
    @GetMapping("/me")
    public Map<String, String> getCurrentUser(Authentication auth) {
        Map<String, String> response = new HashMap<>();
        String role = "UNKNOWN";
        if (auth != null && !auth.getAuthorities().isEmpty()) {
            role = auth.getAuthorities().iterator().next().getAuthority();
        }
        response.put("username", auth != null ? auth.getName() : "anonymous");
        response.put("role", role);
        return response;
    }
}
