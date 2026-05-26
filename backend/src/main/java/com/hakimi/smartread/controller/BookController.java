package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.repository.SmartReadRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/books")
public class BookController {
    private final SmartReadRepository repository;

    public BookController(SmartReadRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/search")
    public ApiResponse<Object> search(@RequestParam(defaultValue = "") String keyword,
                                      @RequestParam(defaultValue = "") String tag,
                                      @RequestParam(defaultValue = "0") int page,
                                      @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(repository.searchBooks(keyword, tag, page, size));
    }

    @GetMapping("/{id}")
    public ApiResponse<Map<String, Object>> detail(@PathVariable long id) {
        return ApiResponse.ok(repository.getBook(id));
    }
}
