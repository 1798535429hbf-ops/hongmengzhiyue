package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.service.SmartReadService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class CommerceController {
    private final SmartReadService service;

    public CommerceController(SmartReadService service) {
        this.service = service;
    }

    @PostMapping("/commerce/search")
    public ApiResponse<Map<String, Object>> search(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.commerceSearch(payload));
    }

    @PostMapping("/purchase/confirm")
    public ApiResponse<Map<String, Object>> confirm(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.confirmPurchase(payload));
    }
}
