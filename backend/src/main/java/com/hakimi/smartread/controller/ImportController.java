package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.service.ImportBookService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/import")
public class ImportController {
    private final ImportBookService service;

    public ImportController(ImportBookService service) {
        this.service = service;
    }

    @PostMapping("/books")
    public ApiResponse<Map<String, Object>> importBook(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.importBook(payload));
    }
}
