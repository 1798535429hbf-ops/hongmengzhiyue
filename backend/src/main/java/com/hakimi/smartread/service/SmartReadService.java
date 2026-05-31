package com.hakimi.smartread.service;

import com.hakimi.smartread.repository.SmartReadRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class SmartReadService {
    private final SmartReadRepository repository;
    private final AiGateway aiGateway;

    public SmartReadService(SmartReadRepository repository, AiGateway aiGateway) {
        this.repository = repository;
        this.aiGateway = aiGateway;
    }

    public Map<String, Object> recommend(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        String query = Payloads.text(payload, "query");
        String keyword = normalizeKeyword(query);
        List<Map<String, Object>> candidateBooks = repository.searchBooks(keyword, "", 0, 8);
        if (candidateBooks.isEmpty()) {
            candidateBooks = repository.searchBooks("", "", 0, 8);
        }
        Map<String, Object> enriched = new LinkedHashMap<>(payload);
        enriched.put("user_profile", repository.findProfile(userId));
        enriched.put("candidate_books", candidateBooks);
        Map<String, Object> result = aiGateway.recommend(enriched);
        repository.saveRecommendation(userId, query, result);
        return result;
    }

    public Map<String, Object> chat(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        String question = Payloads.text(payload, "question");
        Map<String, Object> enriched = new LinkedHashMap<>(payload);
        enriched.put("user_profile", repository.findProfile(userId));
        if (bookId > 0) {
            enriched.put("book", repository.getBook(bookId));
            enriched.put("sources", repository.findChunks(question, bookId, 6));
        }
        Map<String, Object> result = aiGateway.chat(enriched);
        repository.saveChat(userId, bookId, question,
                String.valueOf(result.getOrDefault("answer", "")),
                result.getOrDefault("sources", List.of()));
        return result;
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> commerceSearch(Map<String, Object> payload) {
        long bookId = Payloads.number(payload, "book_id", 0L);
        String isbn = Payloads.text(payload, "isbn", "");
        Map<String, Object> enriched = new LinkedHashMap<>(payload);
        if (bookId > 0) {
            Map<String, Object> book = repository.getBook(bookId);
            enriched.put("book", book);
            if (isbn.isBlank()) {
                isbn = String.valueOf(book.get("isbn"));
                enriched.put("isbn", isbn);
            }
        }
        Map<String, Object> result = aiGateway.commerceSearch(enriched);
        Object results = result.get("results");
        if (results instanceof List<?> list) {
            repository.saveCommerceResults(bookId > 0 ? bookId : null, isbn, (List<Map<String, Object>>) list);
        }
        return result;
    }

    private String normalizeKeyword(String query) {
        if (query == null || query.isBlank()) {
            return "";
        }
        Map<String, String> aliases = Map.ofEntries(
                Map.entry("人工智能", "人工智能"),
                Map.entry("AI", "人工智能"),
                Map.entry("机器学习", "机器学习"),
                Map.entry("深度学习", "深度学习"),
                Map.entry("算法", "算法"),
                Map.entry("考研", "考研"),
                Map.entry("英语", "英语"),
                Map.entry("通识", "通识"),
                Map.entry("数据库", "数据库"),
                Map.entry("系统", "系统"),
                Map.entry("设计", "设计"),
                Map.entry("代码", "代码")
        );
        for (Map.Entry<String, String> entry : aliases.entrySet()) {
            if (query.contains(entry.getKey())) {
                return entry.getValue();
            }
        }
        return query.length() > 12 ? "" : query;
    }

    public Map<String, Object> profile(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        return repository.upsertProfile(
                userId,
                Payloads.text(payload, "name", "测试同学"),
                Payloads.text(payload, "major", "计算机科学"),
                Payloads.text(payload, "grade", "大二"),
                Payloads.text(payload, "interests", "人工智能,算法"),
                Payloads.text(payload, "goal", "课程拓展"),
                Payloads.decimal(payload, "budget", BigDecimal.valueOf(80)),
                Payloads.text(payload, "channels", "library,jd,dangdang,second_hand"));
    }

    public Map<String, Object> createPlan(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        if (bookId <= 0) {
            throw SmartReadException.badRequest("缺少 book_id");
        }
        int targetDays = Payloads.integer(payload, "target_days", 14);
        long id = repository.createPlan(userId, bookId, targetDays);
        return Map.of("id", id, "status", "active");
    }

    public Map<String, Object> updatePlan(long planId, Map<String, Object> payload) {
        long bookId = Payloads.number(payload, "book_id", 0L);
        int progress = Payloads.integer(payload, "progress", 0);
        String chapterId = Payloads.text(payload, "chapter_id", "");
        int scrollOffset = Payloads.integer(payload, "scroll_offset", 0);
        String status = Payloads.text(payload, "status", progress >= 100 ? "finished" : "reading");
        repository.updatePlan(planId, progress, status, chapterId, scrollOffset);
        return Map.of(
                "planId", planId,
                "bookId", bookId,
                "chapterId", chapterId,
                "progress", progress,
                "scrollOffset", scrollOffset,
                "status", status);
    }

    public Map<String, Object> createNote(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        String content = Payloads.text(payload, "content");
        String type = Payloads.text(payload, "type", "ai_answer");
        long id = repository.createNote(userId, bookId, content, type);
        return Map.of("id", id, "type", type);
    }

    public Map<String, Object> confirmPurchase(Map<String, Object> payload) {
        boolean confirmed = Payloads.bool(payload, "confirmed", false);
        if (!confirmed) {
            return Map.of("status", "cancelled", "message", "用户未确认，未生成购买或借阅记录");
        }
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        if (bookId <= 0) {
            throw SmartReadException.badRequest("缺少 book_id");
        }
        String platform = Payloads.text(payload, "platform", "library");
        String action = Payloads.text(payload, "action", "reserve");
        BigDecimal amount = Payloads.decimal(payload, "amount", BigDecimal.ZERO);
        String status = "reserve".equals(action) || "borrow".equals(action) ? "reserved" : "draft_created";
        long recordId = repository.createPurchaseRecord(userId, bookId, platform, action, amount, status);
        if ("reserve".equals(action) || "borrow".equals(action)) {
            repository.createPlan(userId, bookId, 14);
        }
        return Map.of("record_id", recordId, "status", status, "message", "已确认并写入行为闭环");
    }
}
