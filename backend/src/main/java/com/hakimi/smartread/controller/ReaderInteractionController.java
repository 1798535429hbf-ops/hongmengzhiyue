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
@RequestMapping("/api/reader")
public class ReaderInteractionController {
    private final SmartReadRepository repository;
    private final SmartReadService service;

    public ReaderInteractionController(SmartReadRepository repository, SmartReadService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping("/highlights")
    public ApiResponse<Object> highlights(@RequestParam(defaultValue = "10086") long userId,
                                          @RequestParam long bookId,
                                          @RequestParam String chapterId) {
        return ApiResponse.ok(repository.listReaderHighlights(userId, bookId, chapterId));
    }

    @PostMapping("/highlights")
    public ApiResponse<Map<String, Object>> createHighlight(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.createReaderHighlight(payload));
    }

    @GetMapping("/comments")
    public ApiResponse<Object> comments(@RequestParam(defaultValue = "10086") long userId,
                                        @RequestParam long bookId,
                                        @RequestParam String chapterId,
                                        @RequestParam(defaultValue = "0") int paragraphIndex) {
        return ApiResponse.ok(repository.listReaderComments(userId, bookId, chapterId, paragraphIndex));
    }

    @PostMapping("/comments")
    public ApiResponse<Map<String, Object>> createComment(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.createReaderComment(payload));
    }
}
