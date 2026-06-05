package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.repository.SmartReadRepository;
import com.hakimi.smartread.service.SmartReadService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {
    private final SmartReadService service;
    private final SmartReadRepository repository;

    public AnalyticsController(SmartReadService service, SmartReadRepository repository) {
        this.service = service;
        this.repository = repository;
    }

    @PostMapping("/events")
    public ApiResponse<Map<String, Object>> trackEvent(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.trackEvent(payload));
    }

    @PostMapping("/events/batch")
    public ApiResponse<Map<String, Object>> trackEventsBatch(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.trackEventsBatch(payload));
    }

    @GetMapping("/profile")
    public ApiResponse<Map<String, Object>> profile(@RequestParam(defaultValue = "10086") long userId) {
        return ApiResponse.ok(service.profileAnalysis(userId));
    }

    @GetMapping("/reading-stats")
    public ApiResponse<Map<String, Object>> readingStats(@RequestParam(defaultValue = "10086") long userId) {
        return ApiResponse.ok(repository.readingStats(userId));
    }

    @PostMapping("/profile/rebuild")
    public ApiResponse<Map<String, Object>> rebuildProfile(@RequestParam(defaultValue = "10086") long userId) {
        return ApiResponse.ok(service.rebuildProfileAnalysis(userId));
    }
}
