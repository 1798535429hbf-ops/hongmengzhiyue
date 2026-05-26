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
@RequestMapping("/api/notes")
public class NoteController {
    private final SmartReadRepository repository;
    private final SmartReadService service;

    public NoteController(SmartReadRepository repository, SmartReadService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    public ApiResponse<Object> list(@RequestParam(defaultValue = "10086") long userId) {
        return ApiResponse.ok(repository.listNotes(userId));
    }

    @PostMapping
    public ApiResponse<Map<String, Object>> create(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.createNote(payload));
    }
}
