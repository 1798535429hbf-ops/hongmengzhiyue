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

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private final SmartReadRepository repository;
    private final SmartReadService service;

    public UserController(SmartReadRepository repository, SmartReadService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping("/profile")
    public ApiResponse<Map<String, Object>> profile(@RequestParam(defaultValue = "10086") long userId) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("profile", repository.findProfile(userId));
        data.put("favorites", repository.listFavorites(userId));
        data.put("notes", repository.listNotes(userId));
        data.put("plans", repository.listPlans(userId));
        data.put("chat_records", repository.listChatRecords(userId));
        return ApiResponse.ok(data);
    }

    @PostMapping("/profile")
    public ApiResponse<Map<String, Object>> saveProfile(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.profile(payload));
    }
}
