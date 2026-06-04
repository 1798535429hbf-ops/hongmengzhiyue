# 本地书库与阅读功能扩充 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扩展后端数据库与接口，并让 HarmonyOS 端能完成“搜索图书 -> 详情 -> 阅读章节 -> 保存进度/摘记 -> AI 伴读”的本地阅读闭环。

**Architecture:** 采用分阶段混合方案：第一阶段只落地数据库章节正文和现有接口闭环，TXT/EPUB 仅预留数据结构。后端以 `book_chapter` 作为统一阅读正文来源，前端继续消费 `chapters/content/reader` 现有 API，不根据来源格式分叉。

**Tech Stack:** Spring Boot 3.5 + Java 17 + JdbcTemplate + MySQL；HarmonyOS Stage + ArkTS + ArkUI；测试使用 JUnit 5、Spring Boot Test、Mockito。

---

## 文件结构与职责

### 后端
- Modify: `backend/src/main/resources/schema.sql`
  - 扩展 `book`、`reading_plan` 字段。
  - 新增 `book_chapter` 与 `book_import_record`。
- Modify: `backend/src/main/resources/data.sql`
  - 给至少 20 本现有图书补可读章节、导入记录与来源字段。
- Modify: `backend/src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java`
  - 查询可读元数据、章节目录、章节正文、阅读器聚合数据。
  - 保存章节级进度。
- Modify: `backend/src/main/java/com/hakimi/smartread/controller/BookController.java`
  - 增加 `/chapters`、`/content`、`/reader` 三个阅读接口。
- Modify: `backend/src/main/java/com/hakimi/smartread/service/SmartReadService.java`
  - 更新进度时写入 `chapter_id` 与 `scroll_offset`。
  - 伴读时把当前书籍的来源片段传给 AI 网关。
- Modify: `backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java`
  - 增加无需真实 MySQL 的服务级单元测试。

### HarmonyOS 前端
- Modify: `harmony-app/entry/src/main/ets/common/Models.ets`
  - 给 `Book` 增加 `sourceType/readable/importStatus/sourceNote/chapterCount`。
- Modify: `harmony-app/entry/src/main/ets/pages/BookDetailPage.ets`
  - 展示可读状态、章节数、来源说明。
  - 对不可读图书阻止直接进入阅读器并展示提示。
- Modify: `harmony-app/entry/src/main/ets/pages/SearchPage.ets`
  - 在搜索结果中标识可读书籍。
- Inspect/Modify if needed: `harmony-app/entry/src/main/ets/pages/ReaderPage.ets`
  - 只做兼容修复，不重做页面。

---

## Task 1: 后端 schema 支持可读章节

**Files:**
- Modify: `backend/src/main/resources/schema.sql`
- Test: `backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java`

- [ ] **Step 1: 写 schema 结构断言测试**

在 `HongmengZhiYueApplicationTests.java` 中保留现有 `apiResponseUsesPrdEnvelope`，追加以下测试方法和 imports：

```java
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

@Test
void schemaDefinesReadableChapterTablesAndProgressFields() throws Exception {
    String schema = Files.readString(Path.of("src/main/resources/schema.sql"), StandardCharsets.UTF_8);

    Assertions.assertTrue(schema.contains("source_type"));
    Assertions.assertTrue(schema.contains("readable"));
    Assertions.assertTrue(schema.contains("import_status"));
    Assertions.assertTrue(schema.contains("source_note"));
    Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS book_chapter"));
    Assertions.assertTrue(schema.contains("chapter_id VARCHAR(64) NOT NULL"));
    Assertions.assertTrue(schema.contains("paragraphs_json JSON"));
    Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS book_import_record"));
    Assertions.assertTrue(schema.contains("scroll_offset INT NOT NULL DEFAULT 0"));
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#schemaDefinesReadableChapterTablesAndProgressFields
```

Expected: FAIL，至少一个 `Assertions.assertTrue` 失败，因为 schema 还没有这些字段/表。

- [ ] **Step 3: 扩展 `schema.sql`**

在 `book` 表定义中 `cover_color` 后加入：

```sql
  source_type VARCHAR(32) NOT NULL DEFAULT 'manual_seed',
  readable TINYINT(1) NOT NULL DEFAULT 0,
  import_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  source_note VARCHAR(255) DEFAULT '',
```

在 `reading_plan` 表中 `status` 后加入：

```sql
  chapter_id VARCHAR(64) DEFAULT '',
  scroll_offset INT NOT NULL DEFAULT 0,
```

在 `book_chunk` 表之后新增：

```sql
CREATE TABLE IF NOT EXISTS book_chapter (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  book_id BIGINT NOT NULL,
  chapter_id VARCHAR(64) NOT NULL,
  title VARCHAR(160) NOT NULL,
  chapter_order INT NOT NULL,
  summary TEXT NOT NULL,
  content MEDIUMTEXT NOT NULL,
  paragraphs_json JSON,
  page_count INT NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_book_chapter (book_id, chapter_id),
  KEY idx_book_chapter_order (book_id, chapter_order),
  CONSTRAINT fk_book_chapter_book FOREIGN KEY (book_id) REFERENCES book(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS book_import_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  book_id BIGINT NOT NULL,
  source_type VARCHAR(32) NOT NULL,
  file_name VARCHAR(255) DEFAULT '',
  status VARCHAR(32) NOT NULL DEFAULT 'ready',
  message VARCHAR(500) DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_book_import_record_book (book_id),
  CONSTRAINT fk_book_import_record_book FOREIGN KEY (book_id) REFERENCES book(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#schemaDefinesReadableChapterTablesAndProgressFields
```

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add backend/src/main/resources/schema.sql backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: add readable book schema"
```

---

## Task 2: 后端返回阅读元数据与章节内容

**Files:**
- Modify: `backend/src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java`
- Modify: `backend/src/main/java/com/hakimi/smartread/controller/BookController.java`
- Test: `backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java`

- [ ] **Step 1: 写控制器映射测试**

在测试文件追加 imports：

```java
import com.hakimi.smartread.controller.BookController;
import com.hakimi.smartread.repository.SmartReadRepository;
import org.springframework.web.bind.annotation.GetMapping;
import java.lang.reflect.Method;
```

追加测试：

```java
@Test
void bookControllerExposesReaderEndpoints() throws Exception {
    Method chapters = BookController.class.getMethod("chapters", long.class);
    Method content = BookController.class.getMethod("content", long.class, String.class);
    Method reader = BookController.class.getMethod("reader", long.class, long.class, String.class);

    Assertions.assertArrayEquals(new String[]{"/{id}/chapters"}, chapters.getAnnotation(GetMapping.class).value());
    Assertions.assertArrayEquals(new String[]{"/{id}/content"}, content.getAnnotation(GetMapping.class).value());
    Assertions.assertArrayEquals(new String[]{"/{id}/reader"}, reader.getAnnotation(GetMapping.class).value());
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#bookControllerExposesReaderEndpoints
```

Expected: FAIL，提示 `NoSuchMethodException`。

- [ ] **Step 3: 扩展仓储查询字段**

在 `searchBooks` 的 SELECT 中加入：

```java
readable, source_type AS sourceType, import_status AS importStatus,
source_note AS sourceNote,
(SELECT COUNT(*) FROM book_chapter bc WHERE bc.book_id = book.id) AS chapterCount
```

完整 SELECT 片段应变为：

```java
SELECT id, isbn, title, author, tags, summary, difficulty,
       target_reader AS targetReader, cover_color AS coverColor,
       readable, source_type AS sourceType, import_status AS importStatus,
       source_note AS sourceNote,
       (SELECT COUNT(*) FROM book_chapter bc WHERE bc.book_id = book.id) AS chapterCount
FROM book WHERE 1=1
```

在 `getBook` 的 SELECT 中做同样扩展，注意子查询中的外层表名是 `book`：

```java
SELECT id, isbn, title, author, tags, summary, difficulty,
       target_reader AS targetReader, cover_color AS coverColor,
       readable, source_type AS sourceType, import_status AS importStatus,
       source_note AS sourceNote,
       (SELECT COUNT(*) FROM book_chapter bc WHERE bc.book_id = book.id) AS chapterCount
FROM book WHERE id = ?
```

- [ ] **Step 4: 在仓储中新增章节方法**

在 `SmartReadRepository` 的 `getBook` 方法后加入：

```java
public List<Map<String, Object>> listChapters(long bookId) {
    return jdbc.queryForList("""
            SELECT chapter_id AS id, chapter_id AS chapterId, book_id AS bookId,
                   title, chapter_order AS `order`, summary, page_count AS pageCount,
                   FALSE AS isCurrent
            FROM book_chapter
            WHERE book_id = ?
            ORDER BY chapter_order
            """, bookId);
}

public Map<String, Object> getReadingContent(long bookId, String chapterId) {
    List<Map<String, Object>> rows = jdbc.queryForList("""
            SELECT book_id AS bookId, chapter_id AS chapterId, title AS chapterTitle,
                   content, paragraphs_json AS paragraphsJson
            FROM book_chapter
            WHERE book_id = ? AND chapter_id = ?
            """, bookId, chapterId);
    if (rows.isEmpty()) {
        throw SmartReadException.notFound("未找到章节正文：" + bookId + "/" + chapterId);
    }
    Map<String, Object> row = new LinkedHashMap<>(rows.get(0));
    String content = string(row, "content");
    row.remove("paragraphsJson");
    row.put("paragraphs", paragraphs(content));
    List<Map<String, Object>> sources = findChunks("", bookId, 3);
    row.put("sources", sources);
    row.put("sourceRefs", sources);
    return row;
}

public Map<String, Object> readerBundle(long userId, long bookId, String chapterId) {
    Map<String, Object> book = getBook(bookId);
    List<Map<String, Object>> chapters = listChapters(bookId);
    if (chapters.isEmpty()) {
        throw SmartReadException.notFound("这本书还没有可阅读章节");
    }
    String selectedChapterId = chapterId == null || chapterId.isBlank()
            ? String.valueOf(chapters.get(0).get("chapterId"))
            : chapterId;
    Map<String, Object> content = getReadingContent(bookId, selectedChapterId);
    Map<String, Object> plan = findPlanForBook(userId, bookId);
    Map<String, Object> progress = null;
    if (plan != null) {
        progress = Map.of(
                "planId", plan.get("id"),
                "bookId", bookId,
                "chapterId", String.valueOf(plan.getOrDefault("chapterId", selectedChapterId)),
                "progress", plan.getOrDefault("progress", 0),
                "scrollOffset", plan.getOrDefault("scrollOffset", 0),
                "status", plan.getOrDefault("status", "reading"));
    }
    return Map.of(
            "book", book,
            "plan", plan,
            "chapters", chapters,
            "content", content,
            "progress", progress,
            "bookmarks", List.of());
}

public Map<String, Object> findPlanForBook(long userId, long bookId) {
    List<Map<String, Object>> rows = jdbc.queryForList("""
            SELECT p.id, p.user_id AS userId, p.book_id AS bookId, p.target_days AS targetDays,
                   p.progress, p.status, p.chapter_id AS chapterId, p.scroll_offset AS scrollOffset,
                   p.created_at AS createdAt, p.updated_at AS updatedAt,
                   b.title, b.author, b.difficulty, b.cover_color AS coverColor
            FROM reading_plan p JOIN book b ON b.id = p.book_id
            WHERE p.user_id = ? AND p.book_id = ?
            ORDER BY p.updated_at DESC
            LIMIT 1
            """, userId, bookId);
    return rows.isEmpty() ? null : rows.get(0);
}

private static List<String> paragraphs(String content) {
    if (content == null || content.isBlank()) {
        return List.of();
    }
    return List.of(content.split("\\n\\s*\\n"))
            .stream()
            .map(String::trim)
            .filter(text -> !text.isBlank())
            .toList();
}
```

- [ ] **Step 5: 在 `BookController` 新增接口**

在 `detail` 方法后加入：

```java
@GetMapping("/{id}/chapters")
public ApiResponse<Object> chapters(@PathVariable long id) {
    return ApiResponse.ok(repository.listChapters(id));
}

@GetMapping("/{id}/content")
public ApiResponse<Map<String, Object>> content(@PathVariable long id,
                                                @RequestParam String chapterId) {
    return ApiResponse.ok(repository.getReadingContent(id, chapterId));
}

@GetMapping("/{id}/reader")
public ApiResponse<Map<String, Object>> reader(@PathVariable long id,
                                               @RequestParam(defaultValue = "10086") long userId,
                                               @RequestParam(defaultValue = "") String chapterId) {
    return ApiResponse.ok(repository.readerBundle(userId, id, chapterId));
}
```

- [ ] **Step 6: 运行测试确认通过**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#bookControllerExposesReaderEndpoints
```

Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add backend/src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java backend/src/main/java/com/hakimi/smartread/controller/BookController.java backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: expose reader content APIs"
```

---

## Task 3: 保存章节级阅读进度

**Files:**
- Modify: `backend/src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java`
- Modify: `backend/src/main/java/com/hakimi/smartread/service/SmartReadService.java`
- Test: `backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java`

- [ ] **Step 1: 写方法签名测试**

追加 import：

```java
import java.lang.reflect.Parameter;
```

追加测试：

```java
@Test
void repositoryUpdatePlanAcceptsChapterProgressFields() throws Exception {
    Method method = SmartReadRepository.class.getMethod(
            "updatePlan", long.class, int.class, String.class, String.class, int.class);
    Assertions.assertEquals(5, method.getParameterCount());
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#repositoryUpdatePlanAcceptsChapterProgressFields
```

Expected: FAIL，提示方法不存在。

- [ ] **Step 3: 改造仓储 updatePlan**

把原 `updatePlan(long planId, int progress, String status)` 替换为：

```java
public void updatePlan(long planId, int progress, String status, String chapterId, int scrollOffset) {
    jdbc.update("""
            UPDATE reading_plan
            SET progress = ?, status = ?, chapter_id = ?, scroll_offset = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """, Math.max(0, Math.min(progress, 100)), status, chapterId, Math.max(0, scrollOffset), planId);
}
```

同时在 `listPlans` 的 SELECT 中加入：

```java
p.chapter_id AS chapterId, p.scroll_offset AS scrollOffset,
```

完整片段应包含：

```java
SELECT p.id, p.user_id AS userId, p.book_id AS bookId, p.target_days AS targetDays,
       p.progress, p.status, p.chapter_id AS chapterId, p.scroll_offset AS scrollOffset,
       p.created_at AS createdAt, p.updated_at AS updatedAt,
       b.title, b.author, b.difficulty, b.cover_color AS coverColor
```

- [ ] **Step 4: 改造服务层 updatePlan**

把 `SmartReadService.updatePlan` 替换为：

```java
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
```

- [ ] **Step 5: 运行测试确认通过**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#repositoryUpdatePlanAcceptsChapterProgressFields
```

Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add backend/src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java backend/src/main/java/com/hakimi/smartread/service/SmartReadService.java backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: persist chapter reading progress"
```

---

## Task 4: 为至少 20 本书补可读章节种子数据

**Files:**
- Modify: `backend/src/main/resources/data.sql`
- Test: `backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java`

- [ ] **Step 1: 写种子数据断言测试**

追加测试：

```java
@Test
void seedDataProvidesAtLeastTwentyReadableBooks() throws Exception {
    String data = Files.readString(Path.of("src/main/resources/data.sql"), StandardCharsets.UTF_8);

    Assertions.assertTrue(data.contains("UPDATE book SET source_type = 'manual_seed', readable = 1, import_status = 'ready'"));
    Assertions.assertTrue(data.contains("INSERT INTO book_chapter"));
    Assertions.assertTrue(data.contains("INSERT INTO book_import_record"));
    long chapterRows = data.lines().filter(line -> line.trim().startsWith("(") && line.contains("'ch-")).count();
    Assertions.assertTrue(chapterRows >= 40, "至少需要 20 本书 x 2 章 = 40 条章节种子数据");
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#seedDataProvidesAtLeastTwentyReadableBooks
```

Expected: FAIL，因为还没有 `book_chapter` 种子数据。

- [ ] **Step 3: 在 `data.sql` 末尾标记前 20 本为可读**

追加：

```sql
UPDATE book SET
  source_type = 'manual_seed',
  readable = 1,
  import_status = 'ready',
  source_note = '手工编写的演示章节，用于本地阅读闭环验收；不包含未授权图书原文。'
WHERE id BETWEEN 1 AND 20;
```

- [ ] **Step 4: 在 `data.sql` 追加 40 条章节种子数据**

追加以下 SQL。正文均为手工演示文本，不复制原书原文：

```sql
INSERT INTO book_chapter (book_id, chapter_id, title, chapter_order, summary, content, paragraphs_json, page_count)
VALUES
(1, 'ch-1', '智能体与学习目标', 1, '建立人工智能学习的基本问题意识。', '学习人工智能时，先把问题拆成环境、目标、行动和反馈四个部分。这样做的好处是，读者不会一开始就陷入模型名词，而是先理解智能系统为什么需要做判断。\n\n对大学生来说，第一轮阅读可以先记录三个问题：系统观察到了什么、它能采取什么行动、怎样评价行动结果。', JSON_ARRAY('学习人工智能时，先把问题拆成环境、目标、行动和反馈四个部分。这样做的好处是，读者不会一开始就陷入模型名词，而是先理解智能系统为什么需要做判断。', '对大学生来说，第一轮阅读可以先记录三个问题：系统观察到了什么、它能采取什么行动、怎样评价行动结果。'), 3),
(1, 'ch-2', '搜索问题的阅读路线', 2, '用状态空间理解搜索类算法。', '搜索算法可以理解为在许多可能路径中寻找更好路径。阅读时不要只背算法名称，而要画出状态、动作和代价。\n\n当你能解释为什么启发式函数会影响搜索效率，就说明已经从记忆概念进入理解结构。', JSON_ARRAY('搜索算法可以理解为在许多可能路径中寻找更好路径。阅读时不要只背算法名称，而要画出状态、动作和代价。', '当你能解释为什么启发式函数会影响搜索效率，就说明已经从记忆概念进入理解结构。'), 3),
(2, 'ch-1', '模型评估入门', 1, '区分训练效果和泛化能力。', '机器学习入门最容易混淆训练表现和真实表现。一个模型在训练集上分数很高，并不代表它能处理新数据。\n\n阅读这一部分时，建议把训练集、验证集、测试集画成三栏，并写下每一栏的用途。', JSON_ARRAY('机器学习入门最容易混淆训练表现和真实表现。一个模型在训练集上分数很高，并不代表它能处理新数据。', '阅读这一部分时，建议把训练集、验证集、测试集画成三栏，并写下每一栏的用途。'), 3),
(2, 'ch-2', '线性模型的直觉', 2, '把线性模型作为机器学习主线。', '线性模型不是简单模型的代名词，而是一条理解分类、回归和优化的主线。\n\n读者可以先从二维直线开始，再逐步过渡到高维超平面，这样更容易理解参数和损失函数的关系。', JSON_ARRAY('线性模型不是简单模型的代名词，而是一条理解分类、回归和优化的主线。', '读者可以先从二维直线开始，再逐步过渡到高维超平面，这样更容易理解参数和损失函数的关系。'), 3),
(3, 'ch-1', '神经网络的层次', 1, '用层次结构理解深度学习。', '深度学习的核心不是神秘的黑箱，而是多层表示逐步变换。输入经过一层层映射，最终变成可用于判断的特征。\n\n第一遍阅读时，可以把每一层看作一次信息重写，而不是急着推公式。', JSON_ARRAY('深度学习的核心不是神秘的黑箱，而是多层表示逐步变换。输入经过一层层映射，最终变成可用于判断的特征。', '第一遍阅读时，可以把每一层看作一次信息重写，而不是急着推公式。'), 3),
(3, 'ch-2', '优化与训练', 2, '理解训练过程中的梯度更新。', '训练神经网络就是不断根据误差调整参数。梯度告诉模型应该往哪个方向改变，学习率决定每一步迈多大。\n\n如果学习率太大，模型可能越过合适位置；如果太小，训练会非常缓慢。', JSON_ARRAY('训练神经网络就是不断根据误差调整参数。梯度告诉模型应该往哪个方向改变，学习率决定每一步迈多大。', '如果学习率太大，模型可能越过合适位置；如果太小，训练会非常缓慢。'), 3),
(4, 'ch-1', '算法复杂度直觉', 1, '用日常例子理解复杂度。', '算法复杂度描述的是输入规模增长时，运行时间如何变化。它不是精确秒数，而是增长趋势。\n\n学习时可以把线性查找和二分查找放在一起比较：一个逐个看，一个每次排除一半。', JSON_ARRAY('算法复杂度描述的是输入规模增长时，运行时间如何变化。它不是精确秒数，而是增长趋势。', '学习时可以把线性查找和二分查找放在一起比较：一个逐个看，一个每次排除一半。'), 2),
(4, 'ch-2', '贪心与局部选择', 2, '理解贪心算法的适用边界。', '贪心算法每一步都选择眼前看起来最好的方案。它很直观，但并不总能得到全局最优。\n\n阅读时要重点追问：为什么这个局部选择不会破坏后面的结果。', JSON_ARRAY('贪心算法每一步都选择眼前看起来最好的方案。它很直观，但并不总能得到全局最优。', '阅读时要重点追问：为什么这个局部选择不会破坏后面的结果。'), 2),
(5, 'ch-1', '从程序到机器', 1, '理解程序执行链路。', '一个简单程序从源代码变成可运行结果，要经历预处理、编译、汇编、链接和装载。\n\n理解这条链路后，很多看似奇怪的编译错误、链接错误和运行时问题都会更容易定位。', JSON_ARRAY('一个简单程序从源代码变成可运行结果，要经历预处理、编译、汇编、链接和装载。', '理解这条链路后，很多看似奇怪的编译错误、链接错误和运行时问题都会更容易定位。'), 3),
(5, 'ch-2', '存储层次', 2, '用局部性理解性能。', '计算机的存储系统不是一个平面，而是由寄存器、缓存、内存和磁盘构成的层次结构。\n\n程序如果能重复使用附近的数据，就更容易命中缓存，从而获得明显性能收益。', JSON_ARRAY('计算机的存储系统不是一个平面，而是由寄存器、缓存、内存和磁盘构成的层次结构。', '程序如果能重复使用附近的数据，就更容易命中缓存，从而获得明显性能收益。'), 3),
(6, 'ch-1', '关系模型', 1, '理解表、行、列与约束。', '关系模型把数据组织成表。表中的每一行表示一个对象或事实，每一列表示一个属性。\n\n阅读时要特别关注主键、外键和唯一约束，因为它们决定了数据能否保持一致。', JSON_ARRAY('关系模型把数据组织成表。表中的每一行表示一个对象或事实，每一列表示一个属性。', '阅读时要特别关注主键、外键和唯一约束，因为它们决定了数据能否保持一致。'), 2),
(6, 'ch-2', '事务与可靠性', 2, '理解 ACID 的实际价值。', '事务让多个数据库操作要么一起成功，要么一起失败。没有事务，订单、库存、账户这类数据很容易出现不一致。\n\n学习 ACID 时，不要只背四个词，要尝试给每个性质找一个项目中的例子。', JSON_ARRAY('事务让多个数据库操作要么一起成功，要么一起失败。没有事务，订单、库存、账户这类数据很容易出现不一致。', '学习 ACID 时，不要只背四个词，要尝试给每个性质找一个项目中的例子。'), 3),
(7, 'ch-1', '命名表达意图', 1, '从命名开始改善代码可读性。', '好的命名能告诉读者变量或函数为什么存在。坏命名会迫使读者在脑中反复翻译。\n\n写项目时，如果你需要用注释解释变量含义，通常说明名字还可以更具体。', JSON_ARRAY('好的命名能告诉读者变量或函数为什么存在。坏命名会迫使读者在脑中反复翻译。', '写项目时，如果你需要用注释解释变量含义，通常说明名字还可以更具体。'), 2),
(7, 'ch-2', '短函数与单一职责', 2, '让函数更容易测试和修改。', '函数越短，读者越容易看清它的输入、输出和副作用。\n\n当一个函数同时做查询、计算、格式化和写入时，任何修改都会牵动多个理由。', JSON_ARRAY('函数越短，读者越容易看清它的输入、输出和副作用。', '当一个函数同时做查询、计算、格式化和写入时，任何修改都会牵动多个理由。'), 2),
(8, 'ch-1', '应用层视角', 1, '从 HTTP 和 DNS 建立网络直觉。', '从应用层开始学习网络，更容易把协议和真实体验连接起来。浏览网页时，DNS 先帮你找到服务器，HTTP 再负责请求和响应。\n\n用抓包工具观察一次网页加载，比单纯背协议字段更有效。', JSON_ARRAY('从应用层开始学习网络，更容易把协议和真实体验连接起来。浏览网页时，DNS 先帮你找到服务器，HTTP 再负责请求和响应。', '用抓包工具观察一次网页加载，比单纯背协议字段更有效。'), 3),
(8, 'ch-2', '可靠传输', 2, '理解 TCP 为什么可靠。', 'TCP 通过序号、确认、重传和拥塞控制，让不可靠的网络尽量呈现可靠的数据流。\n\n阅读时可以把 TCP 想成一套持续确认的对话机制：没收到确认，就需要考虑重发。', JSON_ARRAY('TCP 通过序号、确认、重传和拥塞控制，让不可靠的网络尽量呈现可靠的数据流。', '阅读时可以把 TCP 想成一套持续确认的对话机制：没收到确认，就需要考虑重发。'), 3),
(9, 'ch-1', '词法分析', 1, '把字符流变成 token。', '编译器读到的最初输入是一串字符。词法分析负责把这些字符分组成有意义的 token。\n\n例如关键字、标识符、数字和符号都可以看作 token，不同 token 后续会进入语法分析。', JSON_ARRAY('编译器读到的最初输入是一串字符。词法分析负责把这些字符分组成有意义的 token。', '例如关键字、标识符、数字和符号都可以看作 token，不同 token 后续会进入语法分析。'), 3),
(9, 'ch-2', '语法树', 2, '理解程序结构如何被表达。', '语法分析会根据文法把 token 组织成树形结构。树的层级表达了语句、表达式和运算优先级。\n\n当你能手动画出简单表达式的语法树，就更容易理解编译器如何检查程序结构。', JSON_ARRAY('语法分析会根据文法把 token 组织成树形结构。树的层级表达了语句、表达式和运算优先级。', '当你能手动画出简单表达式的语法树，就更容易理解编译器如何检查程序结构。'), 3),
(10, 'ch-1', 'Linux 文件权限', 1, '理解 rwx 权限模型。', 'Linux 用读、写、执行三类权限控制文件访问。权限分给所有者、用户组和其他人。\n\n初学时可以用 ls -l 观察权限字符串，再用 chmod 做小范围实验。', JSON_ARRAY('Linux 用读、写、执行三类权限控制文件访问。权限分给所有者、用户组和其他人。', '初学时可以用 ls -l 观察权限字符串，再用 chmod 做小范围实验。'), 2),
(10, 'ch-2', 'Shell 管道', 2, '组合小工具完成复杂任务。', 'Shell 管道把一个命令的输出交给下一个命令。它体现了 Unix 工具链的小而专思想。\n\n掌握管道、重定向和环境变量后，日常开发和部署排查会高效很多。', JSON_ARRAY('Shell 管道把一个命令的输出交给下一个命令。它体现了 Unix 工具链的小而专思想。', '掌握管道、重定向和环境变量后，日常开发和部署排查会高效很多。'), 2),
(11, 'ch-1', '面向对象基础', 1, '理解封装和接口。', 'Java 的面向对象学习可以从封装开始。封装不是把字段藏起来，而是把稳定的使用方式暴露给外部。\n\n接口让调用方依赖能力而不是具体类，这对后端项目分层很重要。', JSON_ARRAY('Java 的面向对象学习可以从封装开始。封装不是把字段藏起来，而是把稳定的使用方式暴露给外部。', '接口让调用方依赖能力而不是具体类，这对后端项目分层很重要。'), 3),
(11, 'ch-2', '集合框架选择', 2, '根据访问模式选择集合。', 'List、Set 和 Map 解决的问题不同。List 保持顺序，Set 强调不重复，Map 通过键快速找到值。\n\n做项目时不要只凭习惯选集合，要先判断读写频率和查找方式。', JSON_ARRAY('List、Set 和 Map 解决的问题不同。List 保持顺序，Set 强调不重复，Map 通过键快速找到值。', '做项目时不要只凭习惯选集合，要先判断读写频率和查找方式。'), 2),
(12, 'ch-1', 'Python 语法节奏', 1, '用缩进和动态类型快速表达想法。', 'Python 用缩进表示代码块，这让代码结构更接近阅读结构。动态类型降低了入门门槛，但也要求命名更清晰。\n\n初学者可以先写小脚本处理文件和列表，再进入 Web 或数据分析项目。', JSON_ARRAY('Python 用缩进表示代码块，这让代码结构更接近阅读结构。动态类型降低了入门门槛，但也要求命名更清晰。', '初学者可以先写小脚本处理文件和列表，再进入 Web 或数据分析项目。'), 2),
(12, 'ch-2', '项目化练习', 2, '用小项目巩固语法。', '单纯看语法很容易遗忘，项目能把变量、循环、函数和模块组织在一起。\n\n建议从数据可视化或简单 Web 应用开始，因为结果可见，反馈更直接。', JSON_ARRAY('单纯看语法很容易遗忘，项目能把变量、循环、函数和模块组织在一起。', '建议从数据可视化或简单 Web 应用开始，因为结果可见，反馈更直接。'), 2),
(13, 'ch-1', '链表操作', 1, '理解指针和节点关系。', '链表的核心不是代码模板，而是节点之间的引用关系。插入和删除通常只改少量指针，但查找需要顺序扫描。\n\n画图是学习链表最有效的方法之一。', JSON_ARRAY('链表的核心不是代码模板，而是节点之间的引用关系。插入和删除通常只改少量指针，但查找需要顺序扫描。', '画图是学习链表最有效的方法之一。'), 2),
(13, 'ch-2', '散列表', 2, '理解哈希函数与冲突。', '散列表用函数把键映射到数组位置。理想情况下查找很快，但冲突不可避免。\n\n学习时要比较拉链法和开放定址法，理解它们如何处理多个键落到同一位置。', JSON_ARRAY('散列表用函数把键映射到数组位置。理想情况下查找很快，但冲突不可避免。', '学习时要比较拉链法和开放定址法，理解它们如何处理多个键落到同一位置。'), 2),
(14, 'ch-1', '进程与调度', 1, '理解操作系统如何分配 CPU。', '进程是正在运行的程序实例。操作系统通过调度器决定哪个进程获得 CPU 时间。\n\n理解进程状态转换后，再看阻塞、就绪和运行会更自然。', JSON_ARRAY('进程是正在运行的程序实例。操作系统通过调度器决定哪个进程获得 CPU 时间。', '理解进程状态转换后，再看阻塞、就绪和运行会更自然。'), 2),
(14, 'ch-2', '死锁条件', 2, '用四个必要条件判断死锁。', '死锁需要互斥、占有并等待、不可抢占和循环等待同时成立。\n\n排查并发问题时，可以逐个破坏这些条件，例如固定资源申请顺序来避免循环等待。', JSON_ARRAY('死锁需要互斥、占有并等待、不可抢占和循环等待同时成立。', '排查并发问题时，可以逐个破坏这些条件，例如固定资源申请顺序来避免循环等待。'), 2),
(15, 'ch-1', 'goroutine', 1, '理解轻量并发单元。', 'Go 的 goroutine 让并发代码写起来更轻。它不是线程的简单替代，而是由运行时调度的轻量任务。\n\n学习时可以先写两个 goroutine 打印消息，再观察调度顺序的不确定性。', JSON_ARRAY('Go 的 goroutine 让并发代码写起来更轻。它不是线程的简单替代，而是由运行时调度的轻量任务。', '学习时可以先写两个 goroutine 打印消息，再观察调度顺序的不确定性。'), 2),
(15, 'ch-2', 'channel 通信', 2, '用通信共享数据。', 'channel 让 goroutine 之间通过发送和接收值来协作。它鼓励用通信表达同步关系。\n\n如果一个 channel 没有人接收，发送方可能阻塞；这正是很多并发 bug 的起点。', JSON_ARRAY('channel 让 goroutine 之间通过发送和接收值来协作。它鼓励用通信表达同步关系。', '如果一个 channel 没有人接收，发送方可能阻塞；这正是很多并发 bug 的起点。'), 2),
(16, 'ch-1', '极限直觉', 1, '从接近过程理解极限。', '极限描述的是变量不断接近某个位置时，函数值趋向哪里。它强调趋势，而不是一定到达。\n\n学习导数前，先理解极限能帮助你把瞬时变化率看成割线斜率的极限。', JSON_ARRAY('极限描述的是变量不断接近某个位置时，函数值趋向哪里。它强调趋势，而不是一定到达。', '学习导数前，先理解极限能帮助你把瞬时变化率看成割线斜率的极限。'), 2),
(16, 'ch-2', '导数意义', 2, '连接几何和物理解释。', '导数既可以表示切线斜率，也可以表示瞬时变化率。\n\n做题时不要只套公式，先判断变量之间的变化关系，再选择求导规则。', JSON_ARRAY('导数既可以表示切线斜率，也可以表示瞬时变化率。', '做题时不要只套公式，先判断变量之间的变化关系，再选择求导规则。'), 2),
(17, 'ch-1', '多元函数', 1, '从一个变量扩展到多个变量。', '多元函数需要同时考虑多个方向上的变化。偏导数只观察一个方向，全微分描述整体近似变化。\n\n理解梯度时，可以把它看成函数增长最快的方向。', JSON_ARRAY('多元函数需要同时考虑多个方向上的变化。偏导数只观察一个方向，全微分描述整体近似变化。', '理解梯度时，可以把它看成函数增长最快的方向。'), 2),
(17, 'ch-2', '级数思想', 2, '用无限和表达函数。', '级数把复杂函数拆成许多简单项的和。判断级数是否收敛，是使用它之前必须回答的问题。\n\n幂级数和傅里叶级数都体现了用基础构件逼近复杂对象的思想。', JSON_ARRAY('级数把复杂函数拆成许多简单项的和。判断级数是否收敛，是使用它之前必须回答的问题。', '幂级数和傅里叶级数都体现了用基础构件逼近复杂对象的思想。'), 2),
(18, 'ch-1', '矩阵与线性方程组', 1, '把方程组写成矩阵形式。', '矩阵让多个线性方程可以被统一表示。行变换对应对方程组做等价变形。\n\n高斯消元的目标不是机械计算，而是逐步暴露变量之间的约束关系。', JSON_ARRAY('矩阵让多个线性方程可以被统一表示。行变换对应对方程组做等价变形。', '高斯消元的目标不是机械计算，而是逐步暴露变量之间的约束关系。'), 2),
(18, 'ch-2', '特征值直觉', 2, '理解变换中保持方向的向量。', '特征向量经过线性变换后方向不变，只是长度按特征值缩放。\n\n这个概念在降维、稳定性分析和搜索排序中都有应用。', JSON_ARRAY('特征向量经过线性变换后方向不变，只是长度按特征值缩放。', '这个概念在降维、稳定性分析和搜索排序中都有应用。'), 2),
(19, 'ch-1', '随机变量', 1, '把随机结果数值化。', '随机变量把实验结果映射为数字，使概率问题可以计算。离散变量用分布律，连续变量用密度函数。\n\n学习时要先判断变量类型，再选择对应的期望和方差计算方式。', JSON_ARRAY('随机变量把实验结果映射为数字，使概率问题可以计算。离散变量用分布律，连续变量用密度函数。', '学习时要先判断变量类型，再选择对应的期望和方差计算方式。'), 2),
(19, 'ch-2', '假设检验', 2, '用数据判断假设是否站得住。', '假设检验不是证明某个结论绝对正确，而是在给定显著性水平下判断是否拒绝原假设。\n\nP 值越小，观察到当前数据在原假设下越不寻常。', JSON_ARRAY('假设检验不是证明某个结论绝对正确，而是在给定显著性水平下判断是否拒绝原假设。', 'P 值越小，观察到当前数据在原假设下越不寻常。'), 2),
(20, 'ch-1', '命题逻辑', 1, '用真值理解推理结构。', '命题逻辑把句子抽象成真假值。通过真值表可以判断复合命题在各种情况下是否成立。\n\n它是学习证明、程序条件判断和数字电路的共同基础。', JSON_ARRAY('命题逻辑把句子抽象成真假值。通过真值表可以判断复合命题在各种情况下是否成立。', '它是学习证明、程序条件判断和数字电路的共同基础。'), 2),
(20, 'ch-2', '图论基础', 2, '用点和边建模关系。', '图由顶点和边组成，可以表达道路、社交关系、依赖关系和状态转移。\n\n阅读图论时，要先明确边是否有方向、是否有权重，再选择遍历或最短路算法。', JSON_ARRAY('图由顶点和边组成，可以表达道路、社交关系、依赖关系和状态转移。', '阅读图论时，要先明确边是否有方向、是否有权重，再选择遍历或最短路算法。'), 2)
ON DUPLICATE KEY UPDATE
  title = VALUES(title),
  chapter_order = VALUES(chapter_order),
  summary = VALUES(summary),
  content = VALUES(content),
  paragraphs_json = VALUES(paragraphs_json),
  page_count = VALUES(page_count);
```

- [ ] **Step 5: 追加导入记录种子数据**

```sql
INSERT INTO book_import_record (book_id, source_type, file_name, status, message)
SELECT id, 'manual_seed', CONCAT('seed-book-', id), 'ready', '手工演示章节已入库，可用于本地阅读闭环验收。'
FROM book
WHERE id BETWEEN 1 AND 20
ON DUPLICATE KEY UPDATE
  source_type = VALUES(source_type),
  file_name = VALUES(file_name),
  status = VALUES(status),
  message = VALUES(message);
```

If MySQL rejects `ON DUPLICATE KEY UPDATE` due to no unique key on `book_import_record`, replace the last block with:

```sql
INSERT INTO book_import_record (book_id, source_type, file_name, status, message)
SELECT b.id, 'manual_seed', CONCAT('seed-book-', b.id), 'ready', '手工演示章节已入库，可用于本地阅读闭环验收。'
FROM book b
WHERE b.id BETWEEN 1 AND 20
  AND NOT EXISTS (
    SELECT 1 FROM book_import_record r
    WHERE r.book_id = b.id AND r.source_type = 'manual_seed'
  );
```

- [ ] **Step 6: 运行测试确认通过**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#seedDataProvidesAtLeastTwentyReadableBooks
```

Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add backend/src/main/resources/data.sql backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: seed readable book chapters"
```

---

## Task 5: 前端模型支持可读元数据

**Files:**
- Modify: `harmony-app/entry/src/main/ets/common/Models.ets`

- [ ] **Step 1: 在 `Book` interface 增加字段**

把 `Book` interface 改为：

```ts
export interface Book {
  id: number;
  isbn: string;
  title: string;
  author: string;
  tags: string;
  summary: string;
  difficulty: string;
  targetReader: string;
  coverColor: string;
  sourceType?: string;
  readable?: number;
  importStatus?: string;
  sourceNote?: string;
  chapterCount?: number;
}
```

- [ ] **Step 2: 更新 `emptyBook` 默认值**

把返回对象改为：

```ts
export function emptyBook(): Book {
  return {
    id: 0,
    isbn: '',
    title: '',
    author: '',
    tags: '',
    summary: '',
    difficulty: '',
    targetReader: '',
    coverColor: '#151A22',
    sourceType: 'manual_seed',
    readable: 0,
    importStatus: 'pending',
    sourceNote: '',
    chapterCount: 0,
  };
}
```

- [ ] **Step 3: 运行 ArkTS 构建或检查命令**

Run from `harmony-app`:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: 构建成功。如果本机没有可用 HarmonyOS 构建环境，记录实际错误，并在最终验证中说明未能执行端侧构建。

- [ ] **Step 4: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add harmony-app/entry/src/main/ets/common/Models.ets
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: model readable book metadata"
```

---

## Task 6: 图书详情页展示可读状态并保护阅读入口

**Files:**
- Modify: `harmony-app/entry/src/main/ets/pages/BookDetailPage.ets`

- [ ] **Step 1: 增加可读判断方法**

在 `addFavorite` 方法后加入：

```ts
  isReadable(): boolean {
    return this.book.readable === 1 || this.book.readable === true || (this.book.chapterCount || 0) > 0;
  }

  readableStatusText(): string {
    if (this.isReadable()) {
      return `可阅读 · ${this.book.chapterCount || 0} 章 · ${this.book.sourceType || 'manual_seed'}`;
    }
    if (this.book.importStatus === 'failed') {
      return '正文导入失败，暂不可阅读';
    }
    return '正文准备中，暂不可阅读';
  }

  openReaderSafely(): void {
    if (!this.isReadable()) {
      this.errorText = this.book.sourceNote || '这本书还没有可阅读章节。';
      return;
    }
    openReader(this.book.id);
  }
```

- [ ] **Step 2: 在 `InfoPanel` 展示来源信息**

在 ISBN 文本后加入：

```ts
      Text(this.readableStatusText())
        .fontColor(this.isReadable() ? Theme.deepGreen : Theme.coral)
        .fontSize(12)
      if (this.book.sourceNote) {
        Text(this.book.sourceNote)
          .fontColor(Theme.slate)
          .fontSize(12)
          .lineHeight(18)
      }
```

- [ ] **Step 3: 修改开始阅读按钮行为**

把：

```ts
          .onClick(() => openReader(this.book.id))
```

替换为：

```ts
          .onClick(() => this.openReaderSafely())
```

同时把按钮背景色改成可读状态驱动：

```ts
          .backgroundColor(this.isReadable() ? Theme.primary : Theme.slate)
```

- [ ] **Step 4: 运行 ArkTS 构建或检查命令**

Run:

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\harmony-app" && hvigorw --mode module -p module=entry assembleHap
```

Expected: 构建成功；若环境缺失，记录实际错误。

- [ ] **Step 5: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add harmony-app/entry/src/main/ets/pages/BookDetailPage.ets
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: show readable state on book detail"
```

---

## Task 7: 搜索结果标识可读书籍

**Files:**
- Modify: `harmony-app/entry/src/main/ets/pages/SearchPage.ets`

- [ ] **Step 1: 找到搜索结果卡片渲染位置**

在 `SearchPage.ets` 中定位 `ForEach` 渲染 `Book` 的区域。目标是每本书标题、作者或标签附近。

- [ ] **Step 2: 增加可读标签 helper**

在页面组件方法区加入：

```ts
  readableBadge(book: Book): string {
    const chapterCount = book.chapterCount || 0;
    if (book.readable === 1 || book.readable === true || chapterCount > 0) {
      return `可读 ${chapterCount} 章`;
    }
    if (book.importStatus === 'failed') {
      return '导入失败';
    }
    return '待入库';
  }
```

- [ ] **Step 3: 在结果卡片中展示标签**

在每个搜索结果卡片内加入：

```ts
Text(this.readableBadge(book))
  .fontColor((book.readable === 1 || book.readable === true || (book.chapterCount || 0) > 0) ? Theme.deepGreen : Theme.slate)
  .fontSize(11)
  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
  .backgroundColor(Theme.softStone)
  .borderRadius(Theme.radius.pill)
```

如果该页面当前没有导入 `Book`，把 import 改为包含 `Book`：

```ts
import { Book } from '../common/Models';
```

- [ ] **Step 4: 运行 ArkTS 构建或检查命令**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\harmony-app" && hvigorw --mode module -p module=entry assembleHap
```

Expected: 构建成功；若环境缺失，记录实际错误。

- [ ] **Step 5: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add harmony-app/entry/src/main/ets/pages/SearchPage.ets
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: mark readable books in search"
```

---

## Task 8: 章节感知 AI 伴读上下文

**Files:**
- Modify: `backend/src/main/java/com/hakimi/smartread/service/SmartReadService.java`
- Test: `backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java`

- [ ] **Step 1: 写服务源码断言测试**

追加测试：

```java
@Test
void chatEnrichesPayloadWithBookSources() throws Exception {
    String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);
    Assertions.assertTrue(service.contains("enriched.put(\"sources\", repository.findChunks"));
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#chatEnrichesPayloadWithBookSources
```

Expected: FAIL，因为当前 chat 只放入 book，没有显式放入 sources。

- [ ] **Step 3: 修改 `SmartReadService.chat`**

在：

```java
if (bookId > 0) {
    enriched.put("book", repository.getBook(bookId));
}
```

替换为：

```java
if (bookId > 0) {
    enriched.put("book", repository.getBook(bookId));
    enriched.put("sources", repository.findChunks(question, bookId, 6));
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test -Dtest=HongmengZhiYueApplicationTests#chatEnrichesPayloadWithBookSources
```

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add backend/src/main/java/com/hakimi/smartread/service/SmartReadService.java backend/src/test/java/com/hakimi/smartread/HongmengZhiYueApplicationTests.java
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "feat: pass reading sources to companion chat"
```

---

## Task 9: 端到端验证后端接口

**Files:**
- No code changes unless verification finds defects.

- [ ] **Step 1: 运行完整后端测试**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw test
```

Expected: BUILD SUCCESS，所有测试通过。

- [ ] **Step 2: 启动后端**

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw spring-boot:run
```

Expected: 服务监听 `8081`。如果本机 MySQL 未启动，应启动 MySQL 或记录实际连接错误，不要声称后端已验证。

- [ ] **Step 3: 验证搜索接口**

```bash
curl "http://127.0.0.1:8081/api/books/search?keyword=%E7%AE%97%E6%B3%95&page=0&size=5"
```

Expected: JSON envelope `code:0`，`data` 中至少一条图书包含 `readable`、`chapterCount`。

- [ ] **Step 4: 验证章节接口**

```bash
curl "http://127.0.0.1:8081/api/books/1/chapters"
```

Expected: JSON envelope `code:0`，`data[0].chapterId` 为 `ch-1`。

- [ ] **Step 5: 验证正文接口**

```bash
curl "http://127.0.0.1:8081/api/books/1/content?chapterId=ch-1"
```

Expected: JSON envelope `code:0`，`data.paragraphs` 非空，`data.sourceRefs` 非空。

- [ ] **Step 6: 验证阅读器聚合接口**

```bash
curl "http://127.0.0.1:8081/api/books/1/reader?userId=10086"
```

Expected: JSON envelope `code:0`，`data.book`、`data.chapters`、`data.content` 存在。

- [ ] **Step 7: 验证进度回写接口**

```bash
curl -X POST "http://127.0.0.1:8081/api/plans" -H "Content-Type: application/json" -d "{\"user_id\":10086,\"book_id\":1,\"target_days\":14}"
```

记下返回的 `data.id`。然后执行：

```bash
curl -X PATCH "http://127.0.0.1:8081/api/plans/返回的计划ID" -H "Content-Type: application/json" -d "{\"user_id\":10086,\"book_id\":1,\"chapter_id\":\"ch-1\",\"progress\":25,\"scroll_offset\":0,\"status\":\"reading\"}"
```

Expected: JSON envelope `code:0`，`data.chapterId` 为 `ch-1`，`data.progress` 为 `25`。

- [ ] **Step 8: 验证摘记接口**

```bash
curl -X POST "http://127.0.0.1:8081/api/notes" -H "Content-Type: application/json" -d "{\"user_id\":10086,\"book_id\":1,\"content\":\"ch-1 摘录测试\",\"type\":\"reading_excerpt\"}"
```

Expected: JSON envelope `code:0`，`data.type` 为 `reading_excerpt`。

- [ ] **Step 9: 提交验证修复**

如果步骤 1-8 发现并修复了代码问题：

```bash
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" add backend harmony-app
git -C "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd" commit -m "fix: complete reader flow verification"
```

如果没有代码变化，不提交。

---

## Task 10: 前端手动验证阅读闭环

**Files:**
- No code changes unless verification finds defects.

- [ ] **Step 1: 启动后端和 AI 服务**

后端：

```bash
cd "C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend" && ./mvnw spring-boot:run
```

AI 服务按项目现有 README 或 docker-compose 启动；如果 AI 服务未启动，只验证到阅读器和摘记，不声称 AI 伴读已通过。

- [ ] **Step 2: 在 DevEco Studio 运行 HarmonyOS app**

打开目录：

```text
C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\harmony-app
```

运行 `entry` 模块。

- [ ] **Step 3: 验证搜索到可读书**

操作：搜索 `算法` 或 `人工智能`。

Expected: 搜索结果出现图书，并显示 `可读 N 章` 一类状态。

- [ ] **Step 4: 验证详情页**

操作：进入任意可读图书详情。

Expected: 详情页显示章节数、来源说明；“开始阅读”可进入阅读器。

- [ ] **Step 5: 验证阅读器**

操作：进入阅读器，打开目录，切换章节，点击上一章/下一章。

Expected: 正文段落展示，章节标题随切换变化，来源片段展示。

- [ ] **Step 6: 验证进度和摘记**

操作：点击保存进度、保存摘记。

Expected: 页面显示保存成功；后端 `/api/plans?userId=10086` 与 `/api/notes?userId=10086` 可查到记录。

- [ ] **Step 7: 验证伴读入口**

操作：从阅读器点击“去伴读”，提问 `这章适合怎么学习？`。

Expected: 如果 AI 服务可用，返回答案和来源；如果 AI 服务不可用，前端显示可读错误，不崩溃。

- [ ] **Step 8: 记录验证结果**

在最终汇报中逐项列出实际执行过的命令/手动步骤和结果。未执行的项必须说明原因。

---

## 自检结果

- Spec 覆盖：本计划覆盖 schema、种子数据、章节/正文/reader 接口、进度、摘记、AI 伴读来源、前端详情/搜索/模型、后端与前端验证。
- 占位扫描：未使用 TBD、TODO、implement later；所有任务都有具体文件、代码片段、命令和期望结果。
- 类型一致性：后端返回字段与前端现有 `Book`、`ReadingChapter`、`ReadingContent`、`ReadingProgress` 对齐；新增字段使用 ArkTS optional 字段避免破坏现有页面。
