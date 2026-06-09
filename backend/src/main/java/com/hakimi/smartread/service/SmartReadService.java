package com.hakimi.smartread.service;

import com.hakimi.smartread.repository.SmartReadRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

@Service
public class SmartReadService {
    private final SmartReadRepository repository;
    private final AiGateway aiGateway;

    public SmartReadService(SmartReadRepository repository, AiGateway aiGateway) {
        this.repository = repository;
        this.aiGateway = aiGateway;
    }

    public Map<String, Object> recommend(Map<String, Object> payload) {
        RecommendContext context = buildRecommendContext(payload);
        Map<String, Object> result;
        try {
            result = aiGateway.recommend(context.enriched());
        } catch (SmartReadException ex) {
            if (!ex.status().is5xxServerError()) {
                throw ex;
            }
            result = topRatedFallbackResult(context.query(), repository.topRatedBooks(context.page(), 8), List.of(),
                    "ai_gateway_failed");
        }
        if (!isContextOnlyResult(result) && isWeakRecommendResult(result)) {
            Object trace = result.getOrDefault("tool_trace", List.of());
            result = topRatedFallbackResult(context.query(), repository.topRatedBooks(context.page(), 8), trace,
                    "weak_ai_result");
        }
        repository.saveRecommendation(context.userId(), context.query(), result);
        return result;
    }

    public void recommendStream(Map<String, Object> payload, java.io.OutputStream output) {
        RecommendContext context = buildRecommendContext(payload);
        Consumer<Map<String, Object>> saveFinal = result ->
                repository.saveRecommendation(context.userId(), context.query(), result);
        aiGateway.recommendStream(context.enriched(), output, saveFinal);
    }

    private RecommendContext buildRecommendContext(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        String query = Payloads.text(payload, "query", "");
        int offset = Payloads.integer(payload, "offset", 0);
        int page = Math.max(0, offset / 8);
        Map<String, Object> profile = repository.findProfile(userId);
        List<Map<String, Object>> plans = repository.listPlans(userId);
        List<Map<String, Object>> favorites = repository.listFavorites(userId);
        List<Map<String, Object>> chatRecords = repository.listChatRecords(userId);
        boolean hasHabitSignals = hasHabitSignals(plans, favorites, chatRecords);
        String keyword = normalizeKeyword(query);
        if (keyword.isBlank() && hasHabitSignals) {
            keyword = normalizeKeyword(String.valueOf(profile.getOrDefault("interests", "")) + ","
                    + profile.getOrDefault("goal", ""));
        }
        boolean topRatedFallback = query.isBlank() && !hasHabitSignals;
        List<Map<String, Object>> candidateBooks = topRatedFallback
                ? repository.topRatedBooks(page, 8)
                : repository.searchBooks(keyword, "", page, 8);
        if (candidateBooks.isEmpty() && !query.isBlank()) {
            candidateBooks = repository.searchBooks(query, "", page, 8);
        }
        if (candidateBooks.isEmpty()) {
            candidateBooks = repository.topRatedBooks(page, 8);
            topRatedFallback = true;
        }
        if (candidateBooks.isEmpty()) {
            candidateBooks = repository.storeBooks("featured", userId, page, 8);
        }
        if (candidateBooks.isEmpty() && Payloads.bool(payload, "auto_import_missing_books", false)) {
            candidateBooks = repository.importMetadataBooks(defaultExternalBooks(keyword.isBlank() ? query : keyword),
                    "推荐链路发现数据库暂无候选书，已先写入真实书籍元数据；正文和章节需后续通过导入或版权渠道补齐。");
        }
        Map<String, Object> enriched = new LinkedHashMap<>(payload);
        enriched.put("user_profile", profile);
        enriched.put("profile_analysis", repository.findProfileAnalysis(userId));
        enriched.put("candidate_books", candidateBooks);
        if (topRatedFallback) {
            enriched.put("fallback_strategy", "top_rated_fallback");
            enriched.put("fallback_reason", "用户习惯线索不足，优先使用数据库高评分和高热度图书");
        }
        enriched.put("reading_history", plans);
        enriched.put("plans", plans);
        enriched.put("favorites", favorites);
        enriched.put("chat_records", chatRecords);
        enriched.put("retrieved_chunks", repository.findChunks(keyword, null, 8));
        return new RecommendContext(userId, query, page, enriched);
    }

    public Map<String, Object> chat(Map<String, Object> payload) {
        ChatContext context = buildChatContext(payload);
        Map<String, Object> result = aiGateway.chat(context.enriched());
        persistChatResult(context, result);
        return result;
    }

    public void chatStream(Map<String, Object> payload, java.io.OutputStream output) {
        ChatContext context = buildChatContext(payload);
        aiGateway.chatStream(context.enriched(), output, result -> persistChatResult(context, result));
    }

    private ChatContext buildChatContext(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        String question = Payloads.text(payload, "question");
        String chapterId = Payloads.text(payload, "chapter_id", "");
        String paragraph = Payloads.text(payload, "paragraph", "");
        Map<String, Object> enriched = new LinkedHashMap<>(payload);
        enriched.put("user_profile", repository.findProfile(userId));
        enriched.put("profile_analysis", repository.findProfileAnalysis(userId));
        enriched.putIfAbsent("tone", "warm_companion");
        enriched.putIfAbsent("allow_external_search", true);
        enriched.putIfAbsent("reasoning_policy", "grounded_sources_plus_deepseek_reasoning");
        enriched.putIfAbsent("answer_scope",
                "Use retrieved book evidence for book facts, and use DeepSeek general reasoning for explanation, analogies, reading advice, and concept connections. If evidence is insufficient, label the answer as general guidance instead of inventing book content.");
        if (bookId > 0) {
            enriched.put("book", repository.getBook(bookId));
            if (!chapterId.isBlank()) {
                try {
                    enriched.put("chapter", repository.getReadingContent(bookId, chapterId));
                } catch (RuntimeException ignored) {
                    enriched.put("chapter_id", chapterId);
                }
            }
            String retrievalQuery = paragraph.isBlank() ? question : question + " " + paragraph;
            enriched.put("paragraph", paragraph);
            enriched.put("sources", repository.findChunks(retrievalQuery, bookId, 6));
        }
        return new ChatContext(userId, bookId, question, chapterId, enriched);
    }

    private void persistChatResult(ChatContext context, Map<String, Object> result) {
        String answer = String.valueOf(result.getOrDefault("answer", ""));
        Object sources = result.getOrDefault("sources", List.of());
        long chatRecordId = repository.saveChat(context.userId(), context.bookId(), context.question(), answer, sources);
        repository.saveQuestionAnalysis(chatRecordId, context.userId(), context.bookId(), context.chapterId(),
                context.question(), answer, classifyQuestion(context.question()), depthLevel(context.question()), sources);
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
                Map.entry("研究生", "考研"),
                Map.entry("备考", "考研"),
                Map.entry("英语", "英语"),
                Map.entry("写作", "写作"),
                Map.entry("词汇", "词汇"),
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

    private boolean hasHabitSignals(List<Map<String, Object>> plans, List<Map<String, Object>> favorites,
                                    List<Map<String, Object>> chatRecords) {
        return !plans.isEmpty() || !favorites.isEmpty() || !chatRecords.isEmpty();
    }

    private boolean isContextOnlyResult(Map<String, Object> result) {
        String intent = String.valueOf(result.getOrDefault("intent", "")).toLowerCase();
        String status = String.valueOf(result.getOrDefault("llm_status", "")).toLowerCase();
        return intent.equals("smalltalk") || intent.equals("clarify") || intent.equals("interest_analysis")
                || intent.equals("chat") || status.equals("context_analysis") || status.equals("general_guidance");
    }

    private boolean isWeakRecommendResult(Map<String, Object> result) {
        Object rawBooks = result.get("book_list");
        boolean emptyBooks = !(rawBooks instanceof List<?> books) || books.isEmpty();
        String status = String.valueOf(result.getOrDefault("llm_status", "")).toLowerCase();
        return emptyBooks || status.contains("insufficient") || status.contains("parse") || status.contains("parser")
                || status.contains("invalid") || status.contains("blocked") || status.contains("guardrail");
    }

    private Map<String, Object> topRatedFallbackResult(String query, List<Map<String, Object>> books,
                                                       Object previousTrace, String detail) {
        List<Map<String, Object>> bookList = new ArrayList<>();
        for (Map<String, Object> book : books) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", book.get("id"));
            item.put("title", book.getOrDefault("title", ""));
            item.put("author", book.getOrDefault("author", ""));
            item.put("difficulty", book.getOrDefault("difficulty", ""));
            item.put("reason", topRatedReason(book));
            item.put("coverColor", book.getOrDefault("coverColor", "#F5F0E8"));
            bookList.add(item);
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("intent", "recommend");
        result.put("book_list", bookList);
        result.put("reason", topRatedLead(query, books));
        result.put("difficulty", books.isEmpty() ? "资料不足" : String.valueOf(books.get(0).getOrDefault("difficulty", "")));
        result.put("follow_up_suggestion", books.isEmpty() ? "" : "先点开第一本看目录和简介；如果难度不对，再换下一本。");
        result.put("sources", List.of());
        result.put("tool_trace", topRatedTrace(previousTrace, detail, bookList.size()));
        result.put("llm_status", "top_rated_fallback");
        return result;
    }

    private String topRatedLead(String query, List<Map<String, Object>> books) {
        if (books.isEmpty()) {
            return "当前个性化线索不足，书库里也暂时没有可用的高评分候选，我先不硬凑书单。";
        }
        String title = String.valueOf(books.get(0).getOrDefault("title", ""));
        String rating = String.valueOf(books.get(0).getOrDefault("rating", "0"));
        String prefix = query == null || query.isBlank()
                ? "当前个性化线索不足"
                : "这次没有拿到足够稳定的个性化判断";
        return prefix + "，先按书库评分和阅读热度推荐。《" + title + "》排在最前面，评分 " + rating
                + "，适合作为这轮挑书的起点。你可以先点开目录和简介，如果它的节奏太快，再把范围收窄到更具体的主题。";
    }

    private String topRatedReason(Map<String, Object> book) {
        String summary = String.valueOf(book.getOrDefault("summary", "")).trim();
        String rating = String.valueOf(book.getOrDefault("rating", "0"));
        String ratingCount = String.valueOf(book.getOrDefault("ratingCount", "0"));
        String base = "书库评分 " + rating + "，" + ratingCount + " 人评分。";
        if (summary.isBlank()) {
            return base + "可以先看目录判断难度和节奏，适合当作这一轮挑书的起点。";
        }
        return base + (summary.length() > 56 ? summary.substring(0, 56) + "..." : summary)
                + "。如果你想继续收窄范围，可以再把专业、考试目标或阅读时间加进去。";
    }

    private List<Object> topRatedTrace(Object previousTrace, String detail, int count) {
        List<Object> trace = new ArrayList<>();
        if (previousTrace instanceof List<?> list) {
            trace.addAll(list);
        }
        trace.add(Map.of(
                "tool", "top_rated_fallback",
                "tool_name", "top_rated_fallback",
                "status", "ok",
                "detail", detail,
                "count", count));
        return trace;
    }

    private List<Map<String, Object>> defaultExternalBooks(String query) {
        String text = query == null ? "" : query;
        if (text.contains("人工智能") || text.contains("机器学习") || text.contains("AI")) {
            return List.of(
                    metadataBook("9787111631700", "动手学深度学习", "阿斯顿·张 等", "人工智能,深度学习,入门", "入门",
                            "通过代码和实例解释深度学习概念，适合大学生从实践角度进入人工智能。"),
                    metadataBook("9787111544932", "机器学习", "周志华", "人工智能,机器学习,教材", "进阶",
                            "系统讲解机器学习基本概念、模型与评估方法，适合课程拓展和竞赛基础。"),
                    metadataBook("9787115612361", "人工智能：一种现代的方法", "斯图尔特·罗素 / 彼得·诺维格", "人工智能,经典教材,通识", "进阶",
                            "人工智能领域经典教材，覆盖搜索、知识表示、学习和规划等核心主题。")
            );
        }
        if (text.contains("算法") || text.contains("代码")) {
            return List.of(
                    metadataBook("9787111407010", "算法（第4版）", "Robert Sedgewick / Kevin Wayne", "算法,计算机,教材", "入门到进阶",
                            "用清晰示例讲解基础数据结构和算法，适合课程学习与刷题前建立体系。"),
                    metadataBook("9787111187776", "算法导论", "Thomas H. Cormen 等", "算法,计算机,经典教材", "进阶",
                            "覆盖算法设计与分析的经典教材，适合需要系统提升算法能力的学生。")
            );
        }
        if (text.contains("英语") || text.contains("考研")) {
            return List.of(
                    metadataBook("9787519301692", "考研英语词汇词根+联想记忆法", "俞敏洪", "考研,英语,词汇", "入门",
                            "围绕考研高频词汇组织记忆路径，适合备考早期建立词汇底座。"),
                    metadataBook("9787519307748", "考研英语阅读的逻辑", "唐迟", "考研,英语,阅读", "入门到进阶",
                            "聚焦阅读题型和解题逻辑，适合有阅读提分需求的学生。")
            );
        }
        return List.of(
                metadataBook("9787544291170", "活着", "余华", "文学,经典,小说", "入门",
                        "篇幅克制、情感力量强，适合想读经典但不想一开始压力太大的读者。"),
                metadataBook("9787536692930", "三体", "刘慈欣", "科幻,文学,想象力", "入门到进阶",
                        "以科幻问题牵引宏大叙事，适合想读故事性和思想性兼具作品的学生。"),
                metadataBook("9787108063176", "乡土中国", "费孝通", "通识,社会学,经典", "入门",
                        "用短章节解释中国基层社会结构，适合通识阅读和课程延伸。")
        );
    }

    private Map<String, Object> metadataBook(String isbn, String title, String author, String tags,
                                             String difficulty, String summary) {
        Map<String, Object> book = new LinkedHashMap<>();
        book.put("isbn", isbn);
        book.put("title", title);
        book.put("author", author);
        book.put("tags", tags);
        book.put("difficulty", difficulty);
        book.put("summary", summary);
        book.put("targetReader", "需要真实可检索书籍推荐和后续伴读的大学生");
        book.put("coverColor", "#F5F0E8");
        return book;
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
                Payloads.text(payload, "channels", "library,jd,dangdang,second_hand"));
    }

    public Map<String, Object> phoneLogin(Map<String, Object> payload) {
        String account = Payloads.text(payload, "account", Payloads.text(payload, "phone", "")).trim();
        String password = Payloads.text(payload, "password", "");
        validatePassword(password);
        Map<String, Object> user = null;
        if (account.replaceAll("\\D", "").matches("1\\d{10}")) {
            String phone = normalizePhone(account);
            user = repository.findUserByPhone(phone);
            if (user == null) {
                user = repository.findUserByAccount(phone);
            }
        } else if (!account.isBlank()) {
            user = repository.findUserByAccount(account);
        }
        if (user != null) {
            ensureActiveUser(user);
            String phone = String.valueOf(user.getOrDefault("phone", account));
            String expectedHash = String.valueOf(user.getOrDefault("passwordHash", ""));
            if (!expectedHash.equals(hashPassword(phone, password))) {
                throw SmartReadException.badRequest("手机号或密码不正确。");
            }
            return repository.findProfile(((Number) user.get("id")).longValue());
        }

        String phone = normalizePhone(account);
        Map<String, Object> auth = repository.findAuthIdentity("phone", phone);
        if (auth == null) {
            throw SmartReadException.badRequest("手机号未注册，请先注册。");
        }
        Map<String, Object> authUser = repository.findUserById(((Number) auth.get("userId")).longValue());
        ensureActiveUser(authUser);
        String expectedHash = String.valueOf(auth.getOrDefault("passwordHash", ""));
        if (!expectedHash.equals(hashPassword(phone, password))) {
            throw SmartReadException.badRequest("手机号或密码不正确。");
        }
        return repository.findProfile(((Number) auth.get("userId")).longValue());
    }

    public Map<String, Object> phoneRegister(Map<String, Object> payload) {
        String phone = normalizePhone(Payloads.text(payload, "phone", ""));
        String password = Payloads.text(payload, "password", "");
        validatePassword(password);
        String passwordHash = hashPassword(phone, password);
        Map<String, Object> existing = repository.findUserByPhone(phone);
        if (existing == null) {
            existing = repository.findUserByAccount(phone);
        }
        if (existing != null) {
            String existingHash = String.valueOf(existing.getOrDefault("passwordHash", ""));
            if (!passwordHash.equals(existingHash)) {
                throw SmartReadException.badRequest("手机号已注册，请直接登录或更换手机号。");
            }
            return repository.findProfile(((Number) existing.get("id")).longValue());
        }

        long userId = repository.createPhoneUser(
                phone,
                passwordHash,
                Payloads.text(payload, "name", "智阅同学 " + phone.substring(7)),
                Payloads.text(payload, "major", "待完善专业"),
                Payloads.text(payload, "grade", "新注册账号"),
                Payloads.text(payload, "interests", "课程延伸阅读,专业入门,AI 伴读"),
                Payloads.text(payload, "goal", "找到合适的书并持续读下去"),
                Payloads.text(payload, "channels", "library,jd,dangdang,second_hand"));
        repository.upsertAuthIdentity("phone", phone, userId, passwordHash);
        return repository.findProfile(userId);
    }

    public Map<String, Object> providerLogin(Map<String, Object> payload) {
        String provider = Payloads.text(payload, "provider", "").trim().toLowerCase();
        if (!"wechat".equals(provider) && !"qq".equals(provider)) {
            throw SmartReadException.badRequest("暂只支持微信或 QQ 登录。");
        }
        String subject = Payloads.text(payload, "subject", provider + "_demo").trim();
        if (subject.isBlank()) {
            subject = provider + "_demo";
        }
        Map<String, Object> existing = repository.findAuthIdentity(provider, subject);
        if (existing != null) {
            return repository.findProfile(((Number) existing.get("userId")).longValue());
        }
        String providerName = "wechat".equals(provider) ? "微信" : "QQ";
        String account = (provider + ":" + subject).length() > 80
                ? provider + ":" + Integer.toUnsignedString(subject.hashCode())
                : provider + ":" + subject;
        String phone = provider + "-" + Integer.toUnsignedString((provider + ":" + subject).hashCode());
        long userId = repository.createProviderUser(
                account,
                phone,
                providerName + "读者",
                "校园阅读",
                providerName + "账号",
                "课程延伸阅读,专业入门,AI 伴读",
                "按当前账号同步独立书架和推荐",
                "library,jd,dangdang,second_hand");
        repository.upsertAuthIdentity(provider, subject, userId, "");
        return repository.findProfile(userId);
    }

    public Map<String, Object> bindEmail(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 0L);
        if (userId <= 0) {
            throw SmartReadException.badRequest("请先登录后再绑定邮箱");
        }
        String email = Payloads.text(payload, "email", "").trim().toLowerCase();
        if (!email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) {
            throw SmartReadException.badRequest("请输入有效邮箱");
        }
        Map<String, Object> user = repository.findUserById(userId);
        ensureActiveUser(user);
        repository.updateUserEmail(userId, email);
        return repository.findProfile(userId);
    }

    public Map<String, Object> changePassword(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 0L);
        if (userId <= 0) {
            throw SmartReadException.badRequest("请先登录后再修改密码");
        }
        String oldPassword = Payloads.text(payload, "old_password", Payloads.text(payload, "oldPassword", ""));
        String newPassword = Payloads.text(payload, "new_password", Payloads.text(payload, "newPassword", ""));
        validatePassword(oldPassword);
        validatePassword(newPassword);
        Map<String, Object> user = repository.findUserById(userId);
        ensureActiveUser(user);
        String phone = String.valueOf(user.getOrDefault("phone", ""));
        String expectedHash = String.valueOf(user.getOrDefault("passwordHash", ""));
        if (!expectedHash.equals(hashPassword(phone, oldPassword))) {
            throw SmartReadException.badRequest("当前密码不正确");
        }
        String nextHash = hashPassword(phone, newPassword);
        repository.updateUserPassword(userId, nextHash);
        repository.upsertAuthIdentity("phone", phone, userId, nextHash);
        return Map.of("status", "ok", "message", "密码已修改");
    }

    public Map<String, Object> resetPassword(Map<String, Object> payload) {
        String phone = normalizePhone(Payloads.text(payload, "phone", ""));
        Map<String, Object> user = repository.findUserByPhone(phone);
        if (user == null) {
            throw SmartReadException.notFound("手机号未注册，无法重置密码");
        }
        ensureActiveUser(user);
        long userId = ((Number) user.get("id")).longValue();
        String generatedPassword = generateSystemPassword();
        String nextHash = hashPassword(phone, generatedPassword);
        repository.updateUserPassword(userId, nextHash);
        repository.upsertAuthIdentity("phone", phone, userId, nextHash);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("phone", phone);
        result.put("generatedPassword", generatedPassword);
        result.put("message", "密码已重置为系统生成密码");
        return result;
    }

    public Map<String, Object> deleteAccount(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 0L);
        if (userId <= 0) {
            throw SmartReadException.badRequest("缺少 user_id");
        }
        Map<String, Object> user = repository.findUserById(userId);
        ensureActiveUser(user);
        int updated = repository.markUserDeleted(userId);
        if (updated <= 0) {
            throw SmartReadException.notFound("未找到需要注销的账号");
        }
        return Map.of("status", "deleted", "message", "账号已注销");
    }

    public Map<String, Object> trackEvent(Map<String, Object> payload) {
        repository.saveBehaviorEvent(payload);
        return Map.of("status", "ok");
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> trackEventsBatch(Map<String, Object> payload) {
        Object rawEvents = payload.get("events");
        if (rawEvents instanceof List<?> list) {
            repository.saveBehaviorEvents((List<Map<String, Object>>) list);
            return Map.of("status", "ok", "count", list.size());
        }
        repository.saveBehaviorEvent(payload);
        return Map.of("status", "ok", "count", 1);
    }

    public Map<String, Object> profileAnalysis(long userId) {
        Map<String, Object> analysis = repository.findProfileAnalysis(userId);
        return analysis.isEmpty() ? repository.rebuildProfileAnalysis(userId) : analysis;
    }

    public Map<String, Object> rebuildProfileAnalysis(long userId) {
        return repository.rebuildProfileAnalysis(userId);
    }

    public Map<String, Object> createPlan(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        if (bookId <= 0) {
            throw SmartReadException.badRequest("缺少 book_id");
        }
        int targetDays = Payloads.integer(payload, "target_days", 14);
        int dailyMinutesTarget = Payloads.integer(payload, "daily_minutes_target", 30);
        int weeklyMinutesTarget = Payloads.integer(payload, "weekly_minutes_target", Math.max(1, dailyMinutesTarget * 7));
        long id = repository.createPlan(userId, bookId, targetDays, dailyMinutesTarget, weeklyMinutesTarget);
        return Map.of("id", id, "status", "active");
    }

    public Map<String, Object> deletePlan(long planId, long userId) {
        int deleted = repository.deletePlan(userId, planId);
        return Map.of("deleted", deleted);
    }

    public Map<String, Object> deletePlanByBook(long userId, long bookId) {
        int deleted = repository.deletePlanByBook(userId, bookId);
        return Map.of("deleted", deleted);
    }

    public Map<String, Object> updatePlan(long planId, Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        int progress = Payloads.integer(payload, "progress", 0);
        String chapterId = Payloads.text(payload, "chapter_id", "");
        int scrollOffset = Payloads.integer(payload, "scroll_offset", 0);
        String status = Payloads.text(payload, "status", progress >= 100 ? "finished" : "reading");
        Integer targetDays = optionalInteger(payload, "target_days");
        Integer dailyMinutesTarget = optionalInteger(payload, "daily_minutes_target");
        Integer weeklyMinutesTarget = optionalInteger(payload, "weekly_minutes_target");
        int updated = repository.updatePlan(userId, planId, progress, status, chapterId, scrollOffset,
                targetDays, dailyMinutesTarget, weeklyMinutesTarget);
        if (updated <= 0) {
            throw SmartReadException.notFound("未找到当前用户的阅读计划：" + planId);
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("planId", planId);
        result.put("bookId", bookId);
        result.put("chapterId", chapterId);
        result.put("progress", progress);
        result.put("scrollOffset", scrollOffset);
        result.put("status", status);
        if (targetDays != null) {
            result.put("targetDays", targetDays);
        }
        if (dailyMinutesTarget != null) {
            result.put("dailyMinutesTarget", dailyMinutesTarget);
        }
        if (weeklyMinutesTarget != null) {
            result.put("weeklyMinutesTarget", weeklyMinutesTarget);
        }
        return result;
    }

    public Map<String, Object> createNote(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        String content = Payloads.text(payload, "content");
        String type = Payloads.text(payload, "type", "ai_answer");
        long id = repository.createNote(userId, bookId, content, type);
        return Map.of("id", id, "type", type);
    }

    public Map<String, Object> createReaderHighlight(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        String chapterId = Payloads.text(payload, "chapter_id", "");
        int paragraphIndex = Payloads.integer(payload, "paragraph_index", -1);
        String selectedText = Payloads.text(payload, "selected_text", "").trim();
        int startOffset = Math.max(0, Payloads.integer(payload, "start_offset", 0));
        int endOffset = Math.max(startOffset, Payloads.integer(payload, "end_offset", selectedText.length()));
        if (userId <= 0) {
            throw SmartReadException.badRequest("请先登录后再标记文本");
        }
        if (bookId <= 0 || chapterId.isBlank() || paragraphIndex < 0) {
            throw SmartReadException.badRequest("缺少标记位置参数");
        }
        if (selectedText.isBlank()) {
            throw SmartReadException.badRequest("请选择需要标记的文本");
        }
        return repository.createReaderHighlight(
                userId,
                bookId,
                chapterId,
                paragraphIndex,
                startOffset,
                endOffset,
                selectedText,
                Payloads.text(payload, "book_title", ""),
                Payloads.text(payload, "chapter_title", ""));
    }

    public Map<String, Object> createReaderComment(Map<String, Object> payload) {
        long userId = Payloads.number(payload, "user_id", 10086L);
        long bookId = Payloads.number(payload, "book_id", 0L);
        String chapterId = Payloads.text(payload, "chapter_id", "");
        int paragraphIndex = Payloads.integer(payload, "paragraph_index", -1);
        String selectedText = Payloads.text(payload, "selected_text", "").trim();
        String content = Payloads.text(payload, "content", "").trim();
        if (userId <= 0) {
            throw SmartReadException.badRequest("请先登录后再评论");
        }
        if (bookId <= 0 || chapterId.isBlank() || paragraphIndex < 0) {
            throw SmartReadException.badRequest("缺少评论位置参数");
        }
        if (selectedText.isBlank()) {
            throw SmartReadException.badRequest("请选择需要评论的文本");
        }
        if (content.isBlank()) {
            throw SmartReadException.badRequest("评论内容不能为空");
        }
        return repository.createReaderComment(userId, bookId, chapterId, paragraphIndex, selectedText, content);
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

    private String normalizePhone(String phone) {
        String normalized = phone == null ? "" : phone.replaceAll("\\D", "");
        if (!normalized.matches("1\\d{10}")) {
            throw SmartReadException.badRequest("请输入 11 位中国大陆手机号。");
        }
        return normalized;
    }

    private void ensureActiveUser(Map<String, Object> user) {
        if (user == null) {
            throw SmartReadException.notFound("未找到用户");
        }
        String status = String.valueOf(user.getOrDefault("status", "active"));
        if ("deleted".equalsIgnoreCase(status) || "cancelled".equalsIgnoreCase(status)) {
            throw SmartReadException.badRequest("账号已注销，不能继续登录或修改资料");
        }
    }

    private String generateSystemPassword() {
        final String alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
        SecureRandom random = new SecureRandom();
        StringBuilder builder = new StringBuilder("SR");
        for (int i = 0; i < 8; i++) {
            builder.append(alphabet.charAt(random.nextInt(alphabet.length())));
        }
        return builder.toString();
    }

    private void validatePassword(String password) {
        if (password == null || password.length() < 6) {
            throw SmartReadException.badRequest("请输入至少 6 位密码。");
        }
    }

    private String classifyQuestion(String question) {
        String text = question == null ? "" : question;
        if (text.contains("什么意思") || text.contains("怎么理解") || text.contains("这个词")) {
            return "VOCABULARY";
        }
        if (text.contains("谁是") || text.contains("什么关系") || text.contains("人物关系")) {
            return "CHARACTER_RELATION";
        }
        if (text.contains("背景") || text.contains("朝代") || text.contains("制度") || text.contains("为什么会有")) {
            return "BACKGROUND";
        }
        if (text.contains("为什么") || text.contains("动机") || text.contains("原因")) {
            return "PLOT_LOGIC";
        }
        if (text.contains("考试") || text.contains("考点") || text.contains("作业") || text.contains("论文")) {
            return "EXAM";
        }
        if (text.contains("写法") || text.contains("修辞") || text.contains("手法")) {
            return "WRITING_TECHNIQUE";
        }
        return "OTHER";
    }

    private int depthLevel(String question) {
        String text = question == null ? "" : question;
        if (text.length() > 80 || text.contains("比较") || text.contains("分析") || text.contains("评价")) {
            return 3;
        }
        if (text.length() > 30 || text.contains("为什么") || text.contains("如何")) {
            return 2;
        }
        return 1;
    }

    private Integer optionalInteger(Map<String, Object> payload, String key) {
        Object value = payload.get(key);
        if (value == null) {
            value = payload.get(toCamel(key));
        }
        if (value == null || value.toString().isBlank()) {
            return null;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        return Integer.parseInt(value.toString());
    }

    private String toCamel(String key) {
        int index = key.indexOf('_');
        if (index < 0 || index == key.length() - 1) {
            return key;
        }
        return key.substring(0, index) + Character.toUpperCase(key.charAt(index + 1)) + key.substring(index + 2);
    }

    private String hashPassword(String phone, String password) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest((phone + ":" + password).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 不可用", ex);
        }
    }

    private record RecommendContext(long userId, String query, int page, Map<String, Object> enriched) {
    }

    private record ChatContext(long userId, long bookId, String question, String chapterId,
                               Map<String, Object> enriched) {
    }
}
