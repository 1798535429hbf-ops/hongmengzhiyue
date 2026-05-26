package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.repository.SmartReadRepository;
import com.hakimi.smartread.service.Payloads;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/favorites")
public class FavoriteController {
    private final SmartReadRepository repository;

    public FavoriteController(SmartReadRepository repository) {
        this.repository = repository;
    }

    @PostMapping
    public ApiResponse<Object> add(@RequestBody Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        repository.addFavorite(userId, bookId);
        return ApiResponse.ok(repository.listFavorites(userId));
    }
}
