package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.repository.SmartReadRepository;
import com.hakimi.smartread.service.SmartReadService;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/plans")
public class PlanController {
    private final SmartReadRepository repository;
    private final SmartReadService service;

    public PlanController(SmartReadRepository repository, SmartReadService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    public ApiResponse<Object> list(@RequestParam(defaultValue = "10086") long userId) {
        return ApiResponse.ok(repository.listPlans(userId));
    }

    @PostMapping
    public ApiResponse<Map<String, Object>> create(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.createPlan(payload));
    }

    @PatchMapping("/{id}")
    public ApiResponse<Map<String, Object>> update(@PathVariable long id,
                                                   @RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.updatePlan(id, payload));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> delete(@PathVariable long id,
                                                   @RequestParam(defaultValue = "10086") long userId) {
        return ApiResponse.ok(service.deletePlan(id, userId));
    }

    @DeleteMapping("/by-book")
    public ApiResponse<Map<String, Object>> deleteByBook(@RequestParam(defaultValue = "10086") long userId,
                                                         @RequestParam long bookId) {
        return ApiResponse.ok(service.deletePlanByBook(userId, bookId));
    }
}
