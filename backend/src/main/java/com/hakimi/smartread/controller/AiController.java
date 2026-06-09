package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.service.SmartReadService;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

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

    @PostMapping(value = "/recommend/stream", produces = "application/x-ndjson")
    public ResponseEntity<StreamingResponseBody> recommendStream(@RequestBody Map<String, Object> payload) {
        StreamingResponseBody body = outputStream -> service.recommendStream(payload, outputStream);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/x-ndjson"))
                .body(body);
    }

    @PostMapping("/chat")
    public ApiResponse<Map<String, Object>> chat(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.chat(payload));
    }

    @PostMapping(value = "/chat/stream", produces = "application/x-ndjson")
    public ResponseEntity<StreamingResponseBody> chatStream(@RequestBody Map<String, Object> payload) {
        StreamingResponseBody body = outputStream -> service.chatStream(payload, outputStream);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/x-ndjson"))
                .body(body);
    }
}
