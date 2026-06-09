package com.hakimi.smartread.controller;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.repository.SmartReadRepository;
import com.hakimi.smartread.service.Payloads;
import com.hakimi.smartread.service.SmartReadService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

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
        long userId = Payloads.number(payload, "user_id", 10086L);
        String name = Payloads.text(payload, "name", "智阅同学");
        String nickname = Payloads.text(payload, "nickname", name);
        String avatarUrl = Payloads.text(payload, "avatarUrl", Payloads.text(payload, "avatar_url", ""));
        return ApiResponse.ok(repository.upsertProfileWithEmail(
                userId,
                name,
                nickname,
                Payloads.text(payload, "email", ""),
                Payloads.text(payload, "major", ""),
                Payloads.text(payload, "grade", ""),
                Payloads.text(payload, "interests", ""),
                Payloads.text(payload, "goal", ""),
                Payloads.text(payload, "intro", ""),
                avatarUrl,
                Payloads.text(payload, "channels", "library,jd,dangdang,second_hand")));
    }

    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<Map<String, Object>> uploadAvatar(@RequestParam("user_id") long userId,
                                                         @RequestParam("file") MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            return ApiResponse.ok(Map.of("avatarUrl", ""));
        }
        String original = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
        String suffix = ".jpg";
        int dot = original.lastIndexOf('.');
        if (dot >= 0 && dot < original.length() - 1) {
            String candidate = original.substring(dot).toLowerCase();
            if (candidate.matches("\\.(jpg|jpeg|png|webp)")) {
                suffix = candidate;
            }
        }
        Path dir = Path.of("uploads", "avatars").toAbsolutePath().normalize();
        Files.createDirectories(dir);
        String fileName = userId + "-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8) + suffix;
        Path target = dir.resolve(fileName).normalize();
        file.transferTo(target);
        String avatarUrl = "/uploads/avatars/" + fileName;
        Map<String, Object> profile = repository.findProfile(userId);
        repository.upsertProfile(
                userId,
                String.valueOf(profile.getOrDefault("name", "")),
                String.valueOf(profile.getOrDefault("nickname", profile.getOrDefault("name", ""))),
                String.valueOf(profile.getOrDefault("major", "")),
                String.valueOf(profile.getOrDefault("grade", "")),
                String.valueOf(profile.getOrDefault("interests", "")),
                String.valueOf(profile.getOrDefault("goal", "")),
                String.valueOf(profile.getOrDefault("intro", "")),
                avatarUrl,
                String.valueOf(profile.getOrDefault("channels", "")));
        return ApiResponse.ok(Map.of("avatarUrl", avatarUrl));
    }

    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.phoneLogin(payload));
    }

    @PostMapping("/register")
    public ApiResponse<Map<String, Object>> register(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.phoneRegister(payload));
    }

    @PostMapping("/provider-login")
    public ApiResponse<Map<String, Object>> providerLogin(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.providerLogin(payload));
    }

    @PostMapping("/email/bind")
    public ApiResponse<Map<String, Object>> bindEmail(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.bindEmail(payload));
    }

    @PostMapping("/password/change")
    public ApiResponse<Map<String, Object>> changePassword(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.changePassword(payload));
    }

    @PostMapping("/password/reset")
    public ApiResponse<Map<String, Object>> resetPassword(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.resetPassword(payload));
    }

    @PostMapping("/account/delete")
    public ApiResponse<Map<String, Object>> deleteAccount(@RequestBody Map<String, Object> payload) {
        return ApiResponse.ok(service.deleteAccount(payload));
    }
}
