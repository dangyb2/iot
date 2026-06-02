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

    @Autowired
    private SensorDataRepository repository;
    @Autowired
    private DeviceStatusService statusService;
    @Autowired
    private MqttService mqttService;

    // 1. GET ENDPOINT: Lịch sử dữ liệu
    @GetMapping("/data")
    public List<SensorData> getAllData() {
        return repository.findAll();
    }

    // 2. POST ENDPOINT: Điều khiển Quạt
    @PostMapping("/control/fan")
    public String controlFan(@RequestParam int status) {
        mqttService.publishCommand("apartment/control/fan", String.valueOf(status));
        return "Fan command sent: " + status;
    }

    // 3. POST ENDPOINT: Gửi cấu hình (CHỈ ADMIN ĐƯỢC GỌI)
    @PostMapping("/config")
    @PreAuthorize("hasRole('ADMIN')") // Thêm dòng này để bảo mật phân quyền
    public ResponseEntity<?> updateConfig(@RequestBody Map<String, Object> configData) {
        try {
            ObjectMapper mapper = new ObjectMapper();
            String jsonPayload = mapper.writeValueAsString(configData);

            mqttService.publishCommand("apartment/config", jsonPayload);
            return ResponseEntity.ok().body("Config updated");
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    // 4. POST ENDPOINT: Điều khiển Đèn
    @PostMapping("/control/led")
    public String controlLed(@RequestParam int status) {
        mqttService.publishCommand("apartment/control/led", String.valueOf(status));
        return "LED command sent: " + status;
    }

    // 5. GET ENDPOINT: Trạng thái thiết bị
    @GetMapping("/status")
    public Map<String, Object> getDeviceStatus() {
        Map<String, Object> response = new HashMap<>();
        response.put("online", statusService.isOnline());
        response.put("lastSeen", statusService.getLastSeen() != null
                ? statusService.getLastSeen().toString()
                : null);
        return response;
    }

    // 6. GET ENDPOINT: Thông tin User đang đăng nhập
    @GetMapping("/me")
    public Map<String, String> getCurrentUser(Authentication auth) {
        Map<String, String> response = new HashMap<>();

        String role = "UNKNOWN";
        if (auth != null) {
            auth.getAuthorities();
            if (!auth.getAuthorities().isEmpty()) {
                role = auth.getAuthorities().iterator().next().getAuthority();
            }
        }

        response.put("username", (auth != null && auth.getName() != null) ? auth.getName() : "anonymous");
        response.put("role", role);

        return response;
    }
}