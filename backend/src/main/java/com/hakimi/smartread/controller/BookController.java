package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.repository.SmartReadRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
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

    @GetMapping("/tags")
    public ApiResponse<Map<String, Object>> tags() {
        return ApiResponse.ok(repository.listBookTags());
    }

    @GetMapping("/store")
    public ApiResponse<List<Map<String, Object>>> store(@RequestParam(defaultValue = "featured") String section,
                                                        @RequestParam(defaultValue = "10086") long userId,
                                                        @RequestParam(defaultValue = "0") int page,
                                                        @RequestParam(defaultValue = "30") int size) {
        return ApiResponse.ok(repository.storeBooks(section, userId, page, size));
    }

    @GetMapping("/{id:\\d+}")
    public ApiResponse<Map<String, Object>> detail(@PathVariable long id) {
        return ApiResponse.ok(repository.getBook(id));
    }

    @GetMapping("/{id:\\d+}/chapters")
    public ApiResponse<Object> chapters(@PathVariable long id) {
        return ApiResponse.ok(repository.listChapters(id));
    }

    @GetMapping("/{id:\\d+}/content")
    public ApiResponse<Map<String, Object>> content(@PathVariable long id,
                                                    @RequestParam String chapterId) {
        return ApiResponse.ok(repository.getReadingContent(id, chapterId));
    }

    @GetMapping("/{id:\\d+}/reader")
    public ApiResponse<Map<String, Object>> reader(@PathVariable long id,
                                                   @RequestParam(defaultValue = "10086") long userId,
                                                   @RequestParam(defaultValue = "") String chapterId) {
        return ApiResponse.ok(repository.readerBundle(userId, id, chapterId));
    }
}
