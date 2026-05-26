package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.service.SmartReadService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/ai")
public class AiController {
    private final SmartReadService service;

    public AiController(SmartReadService service) {
        this.service = service;
    }

    @PostMapping("/recommend")
    public ApiResponse<Map<String, Object>> recommend(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.recommend(payload));
    }

    @PostMapping("/chat")
    public ApiResponse<Map<String, Object>> chat(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.chat(payload));
    }
}
