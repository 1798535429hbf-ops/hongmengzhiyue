package com.hakimi.smartread.repository;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hakimi.smartread.service.SmartReadException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Repository
public class SmartReadRepository {
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public SmartReadRepository(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    public List<Map<String, Object>> searchBooks(String keyword, String tag, int page, int size) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, isbn, title, author, tags, summary, difficulty,
                       target_reader AS targetReader, cover_color AS coverColor
                FROM book WHERE 1=1
                """);
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            String like = "%" + keyword.trim() + "%";
            sql.append(" AND (title LIKE ? OR author LIKE ? OR tags LIKE ? OR summary LIKE ?)");
            args.add(like);
            args.add(like);
            args.add(like);
            args.add(like);
        }
        if (tag != null && !tag.isBlank()) {
            sql.append(" AND tags LIKE ?");
            args.add("%" + tag.trim() + "%");
        }
        sql.append(" ORDER BY id LIMIT ? OFFSET ?");
        args.add(Math.max(1, Math.min(size, 50)));
        args.add(Math.max(page, 0) * Math.max(1, Math.min(size, 50)));
        return jdbc.queryForList(sql.toString(), args.toArray());
    }

    public Map<String, Object> getBook(long id) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, isbn, title, author, tags, summary, difficulty,
                       target_reader AS targetReader, cover_color AS coverColor
                FROM book WHERE id = ?
                """, id);
        if (rows.isEmpty()) {
            throw SmartReadException.notFound("未找到图书：" + id);
        }
        Map<String, Object> book = new LinkedHashMap<>(rows.get(0));
        book.put("chunks", jdbc.queryForList("""
                SELECT id, source, chunk_text AS chunkText, chunk_index AS chunkIndex
                FROM book_chunk WHERE book_id = ? ORDER BY chunk_index
                """, id));
        return book;
    }

    public List<Map<String, Object>> findChunks(String keyword, Long bookId, int size) {
        StringBuilder sql = new StringBuilder("""
                SELECT c.id AS chunk_id, c.book_id, b.title, c.source, c.chunk_text AS text
                FROM book_chunk c
                JOIN book b ON b.id = c.book_id
                WHERE 1=1
                """);
        List<Object> args = new ArrayList<>();
        if (bookId != null && bookId > 0) {
            sql.append(" AND c.book_id = ?");
            args.add(bookId);
        }
        if (keyword != null && !keyword.isBlank()) {
            String like = "%" + keyword.trim() + "%";
            sql.append(" AND (b.title LIKE ? OR b.tags LIKE ? OR c.source LIKE ? OR c.chunk_text LIKE ?)");
            args.add(like);
            args.add(like);
            args.add(like);
            args.add(like);
        }
        sql.append(" ORDER BY c.book_id, c.chunk_index LIMIT ?");
        args.add(Math.max(1, Math.min(size, 12)));
        List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), args.toArray());
        if (!rows.isEmpty()) {
            return rows;
        }
        return jdbc.queryForList("""
                SELECT c.id AS chunk_id, c.book_id, b.title, c.source, c.chunk_text AS text
                FROM book_chunk c
                JOIN book b ON b.id = c.book_id
                ORDER BY c.book_id, c.chunk_index
                LIMIT ?
                """, Math.max(1, Math.min(size, 12)));
    }

    public Map<String, Object> findProfile(long userId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, name, major, grade, interests, goal, budget, channels
                FROM `user` WHERE id = ?
                """, userId);
        if (rows.isEmpty()) {
            throw SmartReadException.notFound("未找到用户画像：" + userId);
        }
        return rows.get(0);
    }

    public Map<String, Object> upsertProfile(long userId, String name, String major, String grade,
                                             String interests, String goal, BigDecimal budget, String channels) {
        jdbc.update("""
                INSERT INTO `user` (id, name, major, grade, interests, goal, budget, channels)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                  name = VALUES(name), major = VALUES(major), grade = VALUES(grade),
                  interests = VALUES(interests), goal = VALUES(goal), budget = VALUES(budget),
                  channels = VALUES(channels)
                """, userId, name, major, grade, interests, goal, budget, channels);
        return findProfile(userId);
    }

    public void addFavorite(long userId, long bookId) {
        jdbc.update("INSERT IGNORE INTO favorite (user_id, book_id) VALUES (?, ?)", userId, bookId);
    }

    public List<Map<String, Object>> listFavorites(long userId) {
        return jdbc.queryForList("""
                SELECT b.id, b.isbn, b.title, b.author, b.tags, b.summary, b.difficulty,
                       b.target_reader AS targetReader, b.cover_color AS coverColor, f.created_at AS favoritedAt
                FROM favorite f JOIN book b ON b.id = f.book_id
                WHERE f.user_id = ?
                ORDER BY f.created_at DESC
                """, userId);
    }

    public long createPlan(long userId, long bookId, int targetDays) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO reading_plan (user_id, book_id, target_days, progress, status)
                    VALUES (?, ?, ?, 0, 'active')
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, userId);
            ps.setLong(2, bookId);
            ps.setInt(3, targetDays);
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        return key == null ? 0 : key.longValue();
    }

    public void updatePlan(long planId, int progress, String status) {
        jdbc.update("""
                UPDATE reading_plan
                SET progress = ?, status = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """, Math.max(0, Math.min(progress, 100)), status, planId);
    }

    public List<Map<String, Object>> listPlans(long userId) {
        return jdbc.queryForList("""
                SELECT p.id, p.user_id AS userId, p.book_id AS bookId, p.target_days AS targetDays,
                       p.progress, p.status, p.created_at AS createdAt, p.updated_at AS updatedAt,
                       b.title, b.author, b.difficulty, b.cover_color AS coverColor
                FROM reading_plan p JOIN book b ON b.id = p.book_id
                WHERE p.user_id = ?
                ORDER BY p.updated_at DESC
                """, userId);
    }

    public long createNote(long userId, Long bookId, String content, String type) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO note (user_id, book_id, content, type)
                    VALUES (?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, userId);
            if (bookId == null || bookId <= 0) {
                ps.setObject(2, null);
            } else {
                ps.setLong(2, bookId);
            }
            ps.setString(3, content);
            ps.setString(4, type);
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        return key == null ? 0 : key.longValue();
    }

    public List<Map<String, Object>> listNotes(long userId) {
        return jdbc.queryForList("""
                SELECT n.id, n.user_id AS userId, n.book_id AS bookId, n.content, n.type,
                       n.created_at AS createdAt, b.title
                FROM note n LEFT JOIN book b ON b.id = n.book_id
                WHERE n.user_id = ?
                ORDER BY n.created_at DESC
                """, userId);
    }

    public void saveRecommendation(long userId, String query, Map<String, Object> result) {
        jdbc.update("""
                INSERT INTO recommend_record (user_id, query, result_json, sources_json)
                VALUES (?, ?, ?, ?)
                """, userId, query, json(result), json(result.getOrDefault("sources", List.of())));
    }

    public void saveChat(long userId, Long bookId, String question, String answer, Object sources) {
        jdbc.update("""
                INSERT INTO chat_record (user_id, book_id, question, answer, sources_json)
                VALUES (?, ?, ?, ?, ?)
                """, userId, bookId == null || bookId <= 0 ? null : bookId, question, answer, json(sources));
    }

    public List<Map<String, Object>> listChatRecords(long userId) {
        return jdbc.queryForList("""
                SELECT id, user_id AS userId, book_id AS bookId, question, answer,
                       sources_json AS sources, created_at AS createdAt
                FROM chat_record
                WHERE user_id = ?
                ORDER BY created_at DESC
                LIMIT 20
                """, userId);
    }

    public void saveCommerceResults(Long bookId, String isbn, List<Map<String, Object>> results) {
        for (Map<String, Object> result : results) {
            jdbc.update("""
                    INSERT INTO commerce_result (isbn, book_id, platform, price, stock, url, delivery, library_status, raw_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    isbn,
                    bookId == null || bookId <= 0 ? null : bookId,
                    string(result, "platform"),
                    decimal(result, "price"),
                    integer(result, "stock"),
                    string(result, "url"),
                    string(result, "delivery"),
                    string(result, "status"),
                    json(result));
        }
    }

    public long createPurchaseRecord(long userId, long bookId, String platform, String action,
                                     BigDecimal amount, String payStatus) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO purchase_record (user_id, book_id, platform, action, amount, pay_status, confirm_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, userId);
            ps.setLong(2, bookId);
            ps.setString(3, platform);
            ps.setString(4, action);
            ps.setBigDecimal(5, amount);
            ps.setString(6, payStatus);
            ps.setTimestamp(7, Timestamp.from(Instant.now()));
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        return key == null ? 0 : key.longValue();
    }

    private String json(Object value) {
        try {
            return objectMapper.writeValueAsString(value == null ? List.of() : value);
        } catch (JsonProcessingException ex) {
            throw new SmartReadException(HttpStatus.INTERNAL_SERVER_ERROR, "JSON 序列化失败");
        }
    }

    private static String string(Map<String, Object> map, String key) {
        Object value = map.get(key);
        return value == null ? "" : value.toString();
    }

    private static int integer(Map<String, Object> map, String key) {
        Object value = map.get(key);
        if (value instanceof Number number) {
            return number.intValue();
        }
        if (value == null || value.toString().isBlank()) {
            return 0;
        }
        return Integer.parseInt(value.toString());
    }

    private static BigDecimal decimal(Map<String, Object> map, String key) {
        Object value = map.get(key);
        if (value instanceof BigDecimal decimal) {
            return decimal;
        }
        if (value instanceof Number number) {
            return BigDecimal.valueOf(number.doubleValue());
        }
        if (value == null || value.toString().isBlank()) {
            return BigDecimal.ZERO;
        }
        return new BigDecimal(value.toString());
    }
}
