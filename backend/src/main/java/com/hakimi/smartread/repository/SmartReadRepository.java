package com.hakimi.smartread.repository;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hakimi.smartread.service.SmartReadException;
import jakarta.annotation.PostConstruct;
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
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

@Repository
public class SmartReadRepository {
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public SmartReadRepository(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    @PostConstruct
    public void ensureUserSchema() {
        ensureUserIdAutoIncrement();
        addColumnIfMissing("user", "account", "account VARCHAR(80) NULL AFTER id");
        addColumnIfMissing("user", "phone", "phone VARCHAR(80) NULL AFTER account");
        addColumnIfMissing("user", "email", "email VARCHAR(160) NOT NULL DEFAULT '' AFTER phone");
        addColumnIfMissing("user", "password_hash", "password_hash VARCHAR(128) NOT NULL DEFAULT '' AFTER email");
        addColumnIfMissing("user", "nickname", "nickname VARCHAR(64) NOT NULL DEFAULT '' AFTER name");
        addColumnIfMissing("user", "intro", "intro VARCHAR(255) NOT NULL DEFAULT '' AFTER goal");
        addColumnIfMissing("user", "avatar_url", "avatar_url VARCHAR(500) NOT NULL DEFAULT '' AFTER intro");
        addColumnIfMissing("user", "status", "status VARCHAR(32) NOT NULL DEFAULT 'active' AFTER channels");
        jdbc.update("""
                UPDATE `user`
                SET account = CASE WHEN account IS NULL OR account = '' THEN CAST(id AS CHAR) ELSE account END,
                    phone = CASE WHEN phone IS NULL OR phone = '' THEN CAST(id AS CHAR) ELSE phone END
                WHERE account IS NULL OR account = '' OR phone IS NULL OR phone = ''
                """);
        jdbc.update("UPDATE `user` SET account = '13800010086', phone = '13800010086' WHERE id = 10086");
        modifyColumnIfExists("user", "account", "account VARCHAR(80) NOT NULL");
        modifyColumnIfExists("user", "phone", "phone VARCHAR(80) NOT NULL");
        addIndexIfMissing("user", "uk_user_account", "ALTER TABLE `user` ADD UNIQUE KEY uk_user_account (account)");
        addIndexIfMissing("user", "uk_user_phone", "ALTER TABLE `user` ADD UNIQUE KEY uk_user_phone (phone)");
        addIndexIfMissing("user", "idx_user_email", "ALTER TABLE `user` ADD KEY idx_user_email (email)");
        ensureReadingPlanUniqueIndex();
        ensureReadingPlanSettingsSchema();
        dropColumnIfExists("user", "budget");
        ensureAnalyticsSchema();
        ensureReaderInteractionSchema();
        ensureBookMetadataSchema();
        cleanupDerivedAudienceTags();
        backfillBookMetadata();
        applyManualSeedBookMetadata();
    }

    private void ensureUserIdAutoIncrement() {
        if (columnExists("user", "id") && !columnIsAutoIncrement("user", "id")) {
            jdbc.execute("ALTER TABLE `user` MODIFY id BIGINT NOT NULL AUTO_INCREMENT");
        }
    }

    private void ensureAnalyticsSchema() {
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS user_behavior_event (
                  id BIGINT PRIMARY KEY AUTO_INCREMENT,
                  user_id BIGINT NOT NULL,
                  event_type VARCHAR(50) NOT NULL,
                  book_id BIGINT NULL,
                  chapter_id VARCHAR(64) NULL,
                  keyword VARCHAR(255) NULL,
                  tag VARCHAR(100) NULL,
                  duration_seconds INT DEFAULT 0,
                  progress DECIMAL(5,2) DEFAULT 0,
                  extra JSON NULL,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_behavior_user_time (user_id, created_at),
                  KEY idx_behavior_type_time (event_type, created_at),
                  KEY idx_behavior_book (book_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """);
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS user_question_analysis (
                  id BIGINT PRIMARY KEY AUTO_INCREMENT,
                  chat_record_id BIGINT NULL,
                  user_id BIGINT NOT NULL,
                  book_id BIGINT NULL,
                  chapter_id VARCHAR(64) DEFAULT '',
                  question TEXT NOT NULL,
                  answer TEXT NULL,
                  question_type VARCHAR(50) DEFAULT 'OTHER',
                  depth_level TINYINT DEFAULT 1,
                  topic_keywords JSON NULL,
                  mentioned_characters JSON NULL,
                  knowledge_gaps JSON NULL,
                  source_count INT DEFAULT 0,
                  saved_as_note TINYINT(1) DEFAULT 0,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_question_user_time (user_id, created_at),
                  KEY idx_question_type (question_type),
                  KEY idx_question_book (book_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """);
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS user_profile_analysis (
                  user_id BIGINT PRIMARY KEY,
                  explicit_interests JSON NULL,
                  inferred_interests JSON NULL,
                  genre_weights JSON NULL,
                  author_weights JSON NULL,
                  difficulty_preference VARCHAR(50) DEFAULT '',
                  reading_goal VARCHAR(50) DEFAULT '',
                  reading_stage VARCHAR(50) DEFAULT '',
                  reading_level VARCHAR(50) DEFAULT '',
                  avg_reading_minutes_per_day DECIMAL(8,2) DEFAULT 0,
                  reading_streak_days INT DEFAULT 0,
                  completion_rate DECIMAL(5,2) DEFAULT 0,
                  abandonment_rate DECIMAL(5,2) DEFAULT 0,
                  dominant_question_types JSON NULL,
                  knowledge_gaps JSON NULL,
                  interest_topics JSON NULL,
                  channel_preference JSON NULL,
                  ai_summary TEXT NULL,
                  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """);
    }

    private void ensureReaderInteractionSchema() {
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS reader_highlight (
                  id BIGINT PRIMARY KEY AUTO_INCREMENT,
                  user_id BIGINT NOT NULL,
                  book_id BIGINT NOT NULL,
                  chapter_id VARCHAR(64) NOT NULL,
                  paragraph_index INT NOT NULL DEFAULT 0,
                  start_offset INT NOT NULL DEFAULT 0,
                  end_offset INT NOT NULL DEFAULT 0,
                  selected_text TEXT NOT NULL,
                  book_title VARCHAR(255) NOT NULL DEFAULT '',
                  chapter_title VARCHAR(255) NOT NULL DEFAULT '',
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  UNIQUE KEY uk_reader_highlight_scope (user_id, book_id, chapter_id, paragraph_index),
                  KEY idx_reader_highlight_chapter (book_id, chapter_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """);
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS reader_comment (
                  id BIGINT PRIMARY KEY AUTO_INCREMENT,
                  user_id BIGINT NOT NULL,
                  book_id BIGINT NOT NULL,
                  chapter_id VARCHAR(64) NOT NULL,
                  paragraph_index INT NOT NULL DEFAULT 0,
                  selected_text TEXT NOT NULL,
                  content TEXT NOT NULL,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  KEY idx_reader_comment_scope (book_id, chapter_id, paragraph_index, created_at),
                  KEY idx_reader_comment_user_time (user_id, created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """);
        addColumnIfMissing("reader_highlight", "start_offset",
                "start_offset INT NOT NULL DEFAULT 0 AFTER paragraph_index");
        addColumnIfMissing("reader_highlight", "end_offset",
                "end_offset INT NOT NULL DEFAULT 0 AFTER start_offset");
    }

    private void cleanupDerivedAudienceTags() {
        jdbc.update("""
                UPDATE book
                SET tags = TRIM(BOTH ',' FROM REPLACE(REPLACE(REPLACE(REPLACE(tags,
                    ',男生向', ''), '男生向,', ''), ',女生向', ''), '女生向,', ''))
                WHERE tags LIKE '%男生向%' OR tags LIKE '%女生向%'
                """);
    }

    private void ensureBookMetadataSchema() {
        addColumnIfMissing("book", "category", "category VARCHAR(80) NOT NULL DEFAULT '通识阅读' AFTER tags");
        addColumnIfMissing("book", "rating", "rating DECIMAL(3, 1) NOT NULL DEFAULT 0.0 AFTER target_reader");
        addColumnIfMissing("book", "rating_count", "rating_count INT NOT NULL DEFAULT 0 AFTER rating");
        addColumnIfMissing("book", "word_count", "word_count INT NOT NULL DEFAULT 0 AFTER rating_count");
        addColumnIfMissing("book", "reader_count", "reader_count INT NOT NULL DEFAULT 0 AFTER word_count");
        addColumnIfMissing("book", "publisher", "publisher VARCHAR(120) NOT NULL DEFAULT '待补充' AFTER reader_count");
        addColumnIfMissing("book", "publish_date", "publish_date VARCHAR(32) NOT NULL DEFAULT '待补充' AFTER publisher");
        addColumnIfMissing("book", "translator", "translator VARCHAR(160) NOT NULL DEFAULT '' AFTER publish_date");
        addColumnIfMissing("book", "edition_note", "edition_note VARCHAR(160) NOT NULL DEFAULT '' AFTER translator");
        addColumnIfMissing("book", "book_info", "book_info TEXT AFTER edition_note");
    }

    private void backfillBookMetadata() {
        jdbc.update("""
                UPDATE book
                SET category = CASE
                    WHEN tags LIKE '%人工智能%' OR tags LIKE '%机器学习%' OR tags LIKE '%深度学习%' OR tags LIKE '%算法%' OR tags LIKE '%计算机%' OR tags LIKE '%数据库%' OR tags LIKE '%Linux%' OR tags LIKE '%Java%' OR tags LIKE '%Python%' OR tags LIKE '%Go%' THEN '计算机科学'
                    WHEN tags LIKE '%高等数学%' OR tags LIKE '%线性代数%' OR tags LIKE '%概率论%' OR tags LIKE '%统计%' OR tags LIKE '%离散数学%' OR tags LIKE '%微积分%' THEN '数学与统计'
                    WHEN tags LIKE '%英语%' OR tags LIKE '%考研%' OR tags LIKE '%六级%' THEN '英语与考试'
                    WHEN tags LIKE '%文学%' OR tags LIKE '%小说%' OR tags LIKE '%人文%' OR tags LIKE '%历史%' OR tags LIKE '%哲学%' THEN '文学与人文'
                    WHEN tags LIKE '%经济%' OR tags LIKE '%管理%' OR tags LIKE '%创业%' THEN '经济管理'
                    WHEN tags LIKE '%设计%' THEN '设计艺术'
                    ELSE COALESCE(NULLIF(category, ''), '通识阅读')
                  END,
                  rating = COALESCE(rating, 0),
                  rating_count = COALESCE(rating_count, 0),
                  word_count = COALESCE(word_count, 0),
                  reader_count = COALESCE(reader_count, 0),
                  publisher = CASE
                    WHEN publisher IN ('人民邮电出版社 / 机械工业出版社', '高等教育出版社', '群言出版社 / 新东方',
                                       '人民文学出版社', '生活·读书·新知三联书店', '中国人民大学出版社', '高校阅读书库') THEN '待补充'
                    WHEN publisher IS NOT NULL AND publisher <> '' THEN publisher
                    ELSE '待补充'
                  END,
                  publish_date = CASE
                    WHEN publish_date IN ('2017-2022', '2016-2021', '2018-2023', '经典版本', '近年修订版') THEN '待补充'
                    WHEN publish_date IS NOT NULL AND publish_date <> '' THEN publish_date
                    ELSE '待补充'
                  END,
                  translator = CASE
                    WHEN translator = '中译本' THEN ''
                    WHEN translator IS NOT NULL THEN translator
                    ELSE ''
                  END
                WHERE tags IS NOT NULL AND tags <> ''
                """);
        jdbc.update("""
                UPDATE book
                SET edition_note = CASE
                    WHEN edition_note IS NOT NULL AND edition_note <> '' THEN edition_note
                    ELSE CONCAT(category, ' · ', difficulty, ' · ', target_reader)
                  END,
                  book_info = CONCAT(
                    '分类：', category,
                    '；标签：', tags,
                    '；评分：', CASE WHEN rating > 0 THEN CONCAT(rating, '（', rating_count, '人评分）') ELSE '暂无真实评分来源' END,
                    '；适合读者：', target_reader
                  )
                WHERE tags IS NOT NULL AND tags <> ''
                """);
    }

    private void applyManualSeedBookMetadata() {
        jdbc.update("""
                UPDATE book b
                JOIN (
                  SELECT 1 id, 'AI与计算智能' category, '人工智能,AI基础,智能体,搜索算法,经典教材,专业进阶' tags UNION ALL
                  SELECT 2, 'AI与计算智能', '机器学习,监督学习,模型评估,算法理论,专业基础' UNION ALL
                  SELECT 3, 'AI与计算智能', '深度学习,神经网络,优化方法,生成模型,科研进阶' UNION ALL
                  SELECT 4, '算法与数据结构', '算法入门,图解学习,递归,图算法,动态规划,竞赛入门' UNION ALL
                  SELECT 5, '计算机系统', '计算机系统,体系结构,C语言,存储层次,底层原理' UNION ALL
                  SELECT 6, '数据库与后端', '数据库,SQL,事务,索引,后端开发,专业基础' UNION ALL
                  SELECT 7, '软件工程', '编程实践,代码质量,重构,测试,团队项目,软件工程' UNION ALL
                  SELECT 8, '计算机网络', '计算机网络,协议,TCP/IP,应用层,网络实验,专业基础' UNION ALL
                  SELECT 9, '编译与程序语言', '编译原理,词法分析,语法分析,程序语言,系统进阶' UNION ALL
                  SELECT 10, '操作系统与运维', 'Linux,命令行,Shell,文件系统,服务器基础,运维入门' UNION ALL
                  SELECT 11, '编程语言', 'Java,面向对象,集合框架,并发,后端入门' UNION ALL
                  SELECT 12, '编程语言', 'Python,编程入门,项目实战,数据可视化,Web应用' UNION ALL
                  SELECT 13, '算法与数据结构', '数据结构,C语言,复杂度分析,树,散列,图算法' UNION ALL
                  SELECT 14, '操作系统', '操作系统,进程调度,内存管理,文件系统,并发控制' UNION ALL
                  SELECT 15, '后端与云原生', 'Go语言,并发编程,接口,后端开发,系统编程' UNION ALL
                  SELECT 16, '高等数学', '高等数学,微积分,工科基础,考研数学,大一课程' UNION ALL
                  SELECT 17, '高等数学', '高等数学,多元微积分,级数,曲面积分,考研数学' UNION ALL
                  SELECT 18, '线性代数', '线性代数,矩阵,向量空间,特征值,机器学习数学' UNION ALL
                  SELECT 19, '概率统计', '概率论,数理统计,随机变量,假设检验,考研数学' UNION ALL
                  SELECT 20, '离散数学', '离散数学,逻辑证明,图论,组合数学,计算机理论' UNION ALL
                  SELECT 21, '机器学习理论', '统计学习,SVM,决策树,EM算法,条件随机场,理论进阶' UNION ALL
                  SELECT 22, '数学科普', '数学科普,信息论,NLP,PageRank,互联网算法,通识阅读' UNION ALL
                  SELECT 23, '微积分自学', '微积分,自学,极限,导数,积分,入门辅导' UNION ALL
                  SELECT 24, '考研英语', '考研英语,写作,作文模板,素材积累,备考规划' UNION ALL
                  SELECT 25, '考研英语', '考研英语,词汇,词根词缀,联想记忆,备考基础' UNION ALL
                  SELECT 26, '考研英语', '考研英语,真题解析,阅读理解,翻译,刷题阶段' UNION ALL
                  SELECT 27, '英语能力提升', '英语,精读,句型训练,综合能力,自学提升' UNION ALL
                  SELECT 28, '英语能力提升', '英语,进阶阅读,表达能力,翻译,六级后提升' UNION ALL
                  SELECT 29, '大学英语六级', '六级,英语词汇,词根联想,考试备考,词汇扩展' UNION ALL
                  SELECT 30, '考研英语', '考研英语,长难句,语法,阅读理解,句子结构' UNION ALL
                  SELECT 31, '社会学与通识', '社会学,乡土社会,通识阅读,课程阅读,写作素材' UNION ALL
                  SELECT 32, '古典文学', '古典文学,红楼梦,小说,中国文学,大学语文' UNION ALL
                  SELECT 33, '当代文学', '当代文学,小说,生命叙事,人文通识,短篇幅' UNION ALL
                  SELECT 34, '世界文学', '世界文学,魔幻现实主义,拉美文学,小说,叙事艺术' UNION ALL
                  SELECT 35, '历史通识', '历史,明史,大历史观,制度分析,跨学科阅读' UNION ALL
                  SELECT 36, '现代文学', '现代文学,讽刺小说,语言艺术,知识分子,大学语文' UNION ALL
                  SELECT 37, '人类学与历史', '人类学,世界历史,地理因素,文明比较,科普通识' UNION ALL
                  SELECT 38, '当代文学', '当代文学,成长,奋斗,农村青年,改革开放,长篇小说' UNION ALL
                  SELECT 39, '经济学入门', '微观经济学,供需,市场效率,外部性,通识课程' UNION ALL
                  SELECT 40, '经济学入门', '宏观经济学,GDP,通货膨胀,失业,货币政策' UNION ALL
                  SELECT 41, '软件工程管理', '软件工程,项目管理,团队协作,经典案例,研发管理' UNION ALL
                  SELECT 42, '创新创业', '创业,产品方法,MVP,敏捷实验,创业竞赛' UNION ALL
                  SELECT 43, '创新创业', '创业,商业思维,创新,垄断优势,通识阅读' UNION ALL
                  SELECT 44, '心理与决策', '心理学,行为经济学,认知偏差,决策科学,通识阅读' UNION ALL
                  SELECT 45, '大学物理', '物理,力学,电磁学,工科基础,大学物理' UNION ALL
                  SELECT 46, '电子电路', '电路分析,电工基础,动态电路,正弦稳态,电子信息' UNION ALL
                  SELECT 47, '设计与用户体验', '设计心理学,用户体验,产品设计,交互设计,可用性' UNION ALL
                  SELECT 48, '视觉设计', '平面设计,排版,视觉原则,PPT设计,海报设计' UNION ALL
                  SELECT 49, '信号处理', '信号与系统,傅里叶分析,系统响应,通信工程,电子信息' UNION ALL
                  SELECT 50, '算法与数据结构', '数据结构,C++,算法,树,图,字符串,课程作业'
                ) m ON b.id = m.id
                SET b.category = m.category,
                    b.tags = m.tags,
                    b.rating = CASE
                        WHEN b.rating > 0 THEN b.rating
                        WHEN m.id IN (2, 4, 5, 21, 31, 33, 47) THEN 4.9
                        WHEN m.id IN (1, 3, 6, 14, 18, 25, 32, 35, 44) THEN 4.8
                        WHEN m.id IN (7, 8, 13, 19, 22, 24, 26, 34, 37, 43) THEN 4.7
                        ELSE 4.4 + ((m.id % 3) * 0.1)
                      END,
                    b.rating_count = CASE WHEN b.rating_count > 0 THEN b.rating_count ELSE 420 + m.id * 37 END,
                    b.word_count = CASE WHEN b.word_count > 0 THEN b.word_count ELSE 0 END,
                    b.reader_count = CASE WHEN b.reader_count > 0 THEN b.reader_count ELSE 80 + m.id * 11 END,
                    b.publisher = '待补充',
                    b.publish_date = '待补充',
                    b.translator = '',
                    b.edition_note = CONCAT(m.category, ' · ', b.difficulty, ' · ', b.target_reader),
                    b.book_info = CONCAT(
                        '分类：', m.category,
                        '；标签：', m.tags,
                        '；评分：', CASE
                            WHEN b.rating > 0 THEN CONCAT(b.rating, '（', b.rating_count, '人评分）')
                            ELSE '演示评分待刷新'
                          END,
                        '；适合读者：', b.target_reader
                      )
                """);
        jdbc.update("""
                UPDATE book
                SET book_info = CONCAT(
                    '分类：', category,
                    '；标签：', tags,
                    '；评分：', CASE WHEN rating > 0 THEN CONCAT(rating, '（', rating_count, '人评分）') ELSE '暂无真实评分来源' END,
                    '；适合读者：', target_reader
                  )
                WHERE id BETWEEN 1 AND 50
                """);
        appendSeedTag("男生向", "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,35,37,39,40,41,42,43,45,46,49,50");
        appendSeedTag("女生向", "24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,44,47,48");
        appendSeedTag("人文", "22,24,25,26,27,28,29,30,31,32,33,34,36,37,38,39,40,42,44,47,48");
        appendSeedTag("地理", "31,34,37");
        appendSeedTag("历史", "31,32,35,37,38");
        appendSeedTag("政治", "7,31,35,39,40,41,42,43,44");
        appendSeedTag("科学", "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,37,41,44,45,46,47,49,50");
        appendSeedTag("哲学", "1,22,31,32,33,34,35,36,43,44,47");
    }

    private void appendSeedTag(String tag, String ids) {
        jdbc.update("""
                UPDATE book
                SET tags = CONCAT_WS(',', NULLIF(tags, ''), ?)
                WHERE FIND_IN_SET(CAST(id AS CHAR), ?) > 0
                  AND FIND_IN_SET(?, tags) = 0
                """, tag, ids, tag);
    }

    public List<Map<String, Object>> topRatedBooks(int page, int size) {
        String sql = bookSelect() + """
                ORDER BY rating DESC, rating_count DESC, readerCount DESC, readable DESC, chapterCount DESC, id DESC
                LIMIT ? OFFSET ?
                """;
        int boundedSize = Math.max(1, Math.min(size, 50));
        return jdbc.queryForList(sql, boundedSize, Math.max(page, 0) * boundedSize);
    }

    public List<Map<String, Object>> searchBooks(String keyword, String tag, int page, int size) {
        StringBuilder sql = new StringBuilder(bookSelect());
        sql.append(" WHERE 1=1");
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.isBlank()) {
            String like = "%" + keyword.trim() + "%";
            sql.append(" AND (title LIKE ? OR author LIKE ? OR tags LIKE ? OR category LIKE ? OR summary LIKE ? OR publisher LIKE ?)");
            args.add(like);
            args.add(like);
            args.add(like);
            args.add(like);
            args.add(like);
            args.add(like);
        }
        if (tag != null && !tag.isBlank()) {
            sql.append(" AND (tags LIKE ? OR category LIKE ?)");
            args.add("%" + tag.trim() + "%");
            args.add("%" + tag.trim() + "%");
        }
        sql.append(" ORDER BY rating DESC, rating_count DESC, readerCount DESC, readable DESC, chapterCount DESC, id DESC LIMIT ? OFFSET ?");
        args.add(Math.max(1, Math.min(size, 50)));
        args.add(Math.max(page, 0) * Math.max(1, Math.min(size, 50)));
        return jdbc.queryForList(sql.toString(), args.toArray());
    }

    public Map<String, Object> listBookTags() {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT tags, category
                FROM book
                WHERE (tags IS NOT NULL AND tags <> '') OR (category IS NOT NULL AND category <> '')
                ORDER BY rating DESC, rating_count DESC, readerCount DESC, id DESC
                """);
        Set<String> study = new LinkedHashSet<>();
        Set<String> general = new LinkedHashSet<>();
        Set<String> all = new LinkedHashSet<>();
        for (Map<String, Object> row : rows) {
            collectBookTags(String.valueOf(row.getOrDefault("category", "")), study, general, all);
            collectBookTags(String.valueOf(row.getOrDefault("tags", "")), study, general, all);
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("study", limitTags(study, 80));
        result.put("general", limitTags(general, 80));
        result.put("all", limitTags(all, 160));
        return result;
    }

    private void collectBookTags(String raw, Set<String> study, Set<String> general, Set<String> all) {
        if (raw == null || raw.isBlank()) {
            return;
        }
        String[] parts = raw.split("[,，、/\\s]+");
        for (String part : parts) {
            String tag = part == null ? "" : part.trim();
            if (tag.isBlank() || isInfrastructureTag(tag)) {
                continue;
            }
            all.add(tag);
            if (isStudyTag(tag)) {
                study.add(tag);
            } else {
                general.add(tag);
            }
        }
    }

    private boolean isInfrastructureTag(String tag) {
        return tag.equals("男生向") || tag.equals("女生向") || tag.equals("本地导入")
                || tag.equals("可读") || tag.equals("AI伴读") || tag.equals("外部检索")
                || tag.equals("真实入库") || tag.equals("待补章节");
    }

    private boolean isStudyTag(String tag) {
        String text = tag == null ? "" : tag;
        String[] keywords = new String[] {
                "计算机", "人工智能", "AI", "算法", "机器学习", "深度学习", "智能体", "编程",
                "数据库", "系统", "Linux", "Java", "Python", "Go", "数学", "统计", "概率",
                "线性代数", "微积分", "英语", "考研", "备考", "六级", "课程", "专业", "竞赛",
                "科研", "方法", "经管", "经济管理", "管理", "设计", "学习", "教材", "入门",
                "进阶", "基础"
        };
        for (String keyword : keywords) {
            if (text.contains(keyword)) {
                return true;
            }
        }
        return false;
    }

    private List<String> limitTags(Set<String> tags, int limit) {
        List<String> result = new ArrayList<>();
        for (String tag : tags) {
            if (result.size() >= limit) {
                break;
            }
            result.add(tag);
        }
        return result;
    }

    public List<Map<String, Object>> storeBooks(String section, long userId, int page, int size) {
        String normalized = section == null ? "" : section.trim().toLowerCase();
        StringBuilder sql = new StringBuilder(bookSelect());
        sql.append(" WHERE 1=1");
        List<Object> args = new ArrayList<>();
        switch (normalized) {
            case "male" -> {
            }
            case "female" -> {
            }
            case "audio" -> {
                sql.append(" AND (tags LIKE ? OR tags LIKE ?)");
                args.add("%有声%");
                args.add("%听书%");
            }
            case "comic" -> {
                sql.append(" AND tags LIKE ?");
                args.add("%漫画%");
            }
            case "publish" -> {
                sql.append(" AND (tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR (source_type <> 'local_txt' AND source_type <> 'local_epub'))");
                args.add("%人文%");
                args.add("%文学%");
                args.add("%考研%");
            }
            default -> {
            }
        }
        sql.append(" ORDER BY ");
        if ("featured".equals(normalized) || normalized.isBlank()) {
            List<String> profileTerms = profileTerms(userId);
            if (!profileTerms.isEmpty()) {
                sql.append("(");
                for (int i = 0; i < profileTerms.size(); i++) {
                    if (i > 0) {
                        sql.append(" + ");
                    }
                    sql.append("CASE WHEN (tags LIKE ? OR summary LIKE ? OR target_reader LIKE ?) THEN 1 ELSE 0 END");
                    String like = "%" + profileTerms.get(i) + "%";
                    args.add(like);
                    args.add(like);
                    args.add(like);
                }
                sql.append(") DESC, ");
            }
            sql.append("rating DESC, rating_count DESC, readerCount DESC, readable DESC, chapterCount DESC, id DESC");
        } else if ("male".equals(normalized) || "female".equals(normalized)) {
            sql.append("rating DESC, rating_count DESC, readerCount DESC, readable DESC, chapterCount DESC, id DESC");
        } else {
            sql.append("rating DESC, rating_count DESC, readerCount DESC, readable DESC, chapterCount DESC, id DESC");
        }
        sql.append(" LIMIT ? OFFSET ?");
        args.add(Math.max(1, Math.min(size, 50)));
        args.add(Math.max(page, 0) * Math.max(1, Math.min(size, 50)));
        return jdbc.queryForList(sql.toString(), args.toArray());
    }

    public Map<String, Object> getBook(long id) {
        List<Map<String, Object>> rows = jdbc.queryForList(bookSelect() + " WHERE id = ?", id);
        if (rows.isEmpty()) {
            throw SmartReadException.notFound("未找到图书：" + id);
        }
        Map<String, Object> book = new LinkedHashMap<>(rows.get(0));
        book.putIfAbsent("rating", 0);
        book.putIfAbsent("ratingCount", 0);
        book.putIfAbsent("wordCount", 0);
        book.putIfAbsent("readerCount", 0);
        book.put("chunks", jdbc.queryForList("""
                SELECT id, source, chunk_text AS chunkText, chunk_index AS chunkIndex
                FROM book_chunk WHERE book_id = ? ORDER BY chunk_index
                """, id));
        return book;
    }

    public List<Map<String, Object>> listChapters(long bookId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT chapter_id AS id, chapter_id AS chapterId, book_id AS bookId,
                       title, chapter_order AS `order`, summary, page_count AS pageCount,
                       FALSE AS isCurrent, LEFT(content, 2400) AS frontMatterProbe
                FROM book_chapter
                WHERE book_id = ?
                ORDER BY chapter_order
                """, bookId);
        List<Map<String, Object>> readable = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            if (!isFrontMatterChapter(row)) {
                readable.add(cleanChapterRow(row));
            }
        }
        return readable.isEmpty() ? cleanChapterRows(rows) : readable;
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
        Object paragraphsJson = row.remove("paragraphsJson");
        row.put("paragraphs", paragraphs(paragraphsJson, content));
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
        String selectedChapterId = validChapterId(chapters, chapterId)
                ? chapterId
                : String.valueOf(chapters.get(0).get("chapterId"));
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
        Map<String, Object> bundle = new LinkedHashMap<>();
        bundle.put("book", book);
        bundle.put("plan", plan);
        bundle.put("chapters", chapters);
        bundle.put("content", content);
        bundle.put("progress", progress);
        bundle.put("bookmarks", List.of());
        return bundle;
    }

    public Map<String, Object> findPlanForBook(long userId, long bookId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT p.id, p.user_id AS userId, p.book_id AS bookId, p.target_days AS targetDays,
                       p.daily_minutes_target AS dailyMinutesTarget,
                       p.weekly_minutes_target AS weeklyMinutesTarget,
                       p.progress, p.status, p.chapter_id AS chapterId, p.scroll_offset AS scrollOffset,
                       p.created_at AS createdAt, p.updated_at AS updatedAt,
                       CASE WHEN p.status = 'finished' OR p.progress >= 100 THEN p.updated_at ELSE NULL END AS completedAt,
                       b.title, b.author, b.difficulty, b.cover_color AS coverColor
                FROM reading_plan p JOIN book b ON b.id = p.book_id
                WHERE p.user_id = ? AND p.book_id = ?
                ORDER BY p.updated_at DESC
                LIMIT 1
                """, userId, bookId);
        return rows.isEmpty() ? null : rows.get(0);
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
        if (bookId != null && bookId > 0) {
            return jdbc.queryForList("""
                    SELECT c.id AS chunk_id, c.book_id, b.title, c.source, c.chunk_text AS text
                    FROM book_chunk c
                    JOIN book b ON b.id = c.book_id
                    WHERE c.book_id = ?
                    ORDER BY c.chunk_index
                    LIMIT ?
                    """, bookId, Math.max(1, Math.min(size, 12)));
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
                SELECT id, account, phone, email, name, nickname, major, grade, interests, goal,
                       intro, avatar_url AS avatarUrl, channels
                FROM `user` WHERE id = ?
                """, userId);
        if (rows.isEmpty()) {
            throw SmartReadException.notFound("未找到用户画像：" + userId);
        }
        return rows.get(0);
    }

    public Map<String, Object> upsertProfile(long userId, String name, String major, String grade,
                                             String interests, String goal, String channels) {
        return upsertProfile(userId, name, name, major, grade, interests, goal, "", "", channels);
    }

    public Map<String, Object> upsertProfile(long userId, String name, String nickname, String major, String grade,
                                             String interests, String goal, String intro, String avatarUrl,
                                             String channels) {
        return upsertProfileWithEmail(userId, name, nickname, "", major, grade, interests, goal, intro, avatarUrl, channels);
    }

    public Map<String, Object> upsertProfileWithEmail(long userId, String name, String nickname, String email,
                                                      String major, String grade, String interests, String goal,
                                                      String intro, String avatarUrl, String channels) {
        jdbc.update("""
                INSERT INTO `user` (id, account, phone, email, password_hash, name, nickname, major, grade, interests, goal, intro, avatar_url, channels)
                VALUES (?, ?, ?, ?, '', ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                  email = CASE WHEN VALUES(email) = '' THEN email ELSE VALUES(email) END,
                  name = VALUES(name), nickname = VALUES(nickname), major = VALUES(major), grade = VALUES(grade),
                  interests = VALUES(interests), goal = VALUES(goal),
                  intro = VALUES(intro), avatar_url = CASE WHEN VALUES(avatar_url) = '' THEN avatar_url ELSE VALUES(avatar_url) END,
                  channels = VALUES(channels)
                """, userId, String.valueOf(userId), String.valueOf(userId), email == null ? "" : email, name, nickname, major, grade,
                interests, goal, intro, avatarUrl, channels);
        return findProfile(userId);
    }

    public Map<String, Object> findUserByPhone(String phone) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, account, phone, email, password_hash AS passwordHash, name, nickname, major, grade,
                       interests, goal, intro, avatar_url AS avatarUrl, channels, status
                FROM `user`
                WHERE phone = ?
                LIMIT 1
                """, phone);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public Map<String, Object> findUserByAccount(String account) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, account, phone, email, password_hash AS passwordHash, name, nickname, major, grade,
                       interests, goal, intro, avatar_url AS avatarUrl, channels, status
                FROM `user`
                WHERE account = ?
                LIMIT 1
                """, account);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public long createPhoneUser(String phone, String passwordHash, String name, String major, String grade,
                                String interests, String goal, String channels) {
        return createUser(phone, phone, passwordHash, name, major, grade, interests, goal, channels);
    }

    public long createProviderUser(String account, String phone, String name, String major, String grade,
                                   String interests, String goal, String channels) {
        return createUser(account, phone, "", name, major, grade, interests, goal, channels);
    }

    public Map<String, Object> findUserById(long userId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, account, phone, email, password_hash AS passwordHash, name, nickname, major, grade,
                       interests, goal, intro, avatar_url AS avatarUrl, channels, status
                FROM `user`
                WHERE id = ?
                LIMIT 1
                """, userId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public void updateUserPassword(long userId, String passwordHash) {
        jdbc.update("UPDATE `user` SET password_hash = ? WHERE id = ?", passwordHash, userId);
    }

    public void updateUserEmail(long userId, String email) {
        jdbc.update("UPDATE `user` SET email = ? WHERE id = ?", email == null ? "" : email, userId);
    }

    public int markUserDeleted(long userId) {
        return jdbc.update("UPDATE `user` SET status = 'deleted' WHERE id = ?", userId);
    }

    private long createUser(String account, String phone, String passwordHash, String name, String major, String grade,
                            String interests, String goal, String channels) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO `user` (account, phone, email, password_hash, name, nickname, major, grade, interests, goal, channels)
                    VALUES (?, ?, '', ?, ?, ?, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, account);
            ps.setString(2, phone);
            ps.setString(3, passwordHash == null ? "" : passwordHash);
            ps.setString(4, name);
            ps.setString(5, name);
            ps.setString(6, major);
            ps.setString(7, grade);
            ps.setString(8, interests);
            ps.setString(9, goal);
            ps.setString(10, channels);
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        return key == null ? 0 : key.longValue();
    }

    public Map<String, Object> findAuthIdentity(String provider, String subject) {
        ensureAuthTable();
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, provider, subject, user_id AS userId, password_hash AS passwordHash
                FROM user_auth
                WHERE provider = ? AND subject = ?
                LIMIT 1
                """, provider, subject);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public void upsertAuthIdentity(String provider, String subject, long userId, String passwordHash) {
        ensureAuthTable();
        jdbc.update("""
                INSERT INTO user_auth (provider, subject, user_id, password_hash)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                  user_id = VALUES(user_id),
                  password_hash = VALUES(password_hash),
                  updated_at = CURRENT_TIMESTAMP
                """, provider, subject, userId, passwordHash == null ? "" : passwordHash);
    }

    public void ensureAuthTable() {
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS user_auth (
                  id BIGINT PRIMARY KEY AUTO_INCREMENT,
                  provider VARCHAR(32) NOT NULL,
                  subject VARCHAR(80) NOT NULL,
                  user_id BIGINT NOT NULL,
                  password_hash VARCHAR(128) DEFAULT '',
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  UNIQUE KEY uk_user_auth_provider_subject (provider, subject),
                  KEY idx_user_auth_user (user_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """);
    }

    public void addFavorite(long userId, long bookId) {
        jdbc.update("INSERT IGNORE INTO favorite (user_id, book_id) VALUES (?, ?)", userId, bookId);
    }

    public int deleteFavorite(long userId, long bookId) {
        return jdbc.update("DELETE FROM favorite WHERE user_id = ? AND book_id = ?", userId, bookId);
    }

    public List<Map<String, Object>> listFavorites(long userId) {
        return jdbc.queryForList("""
                SELECT b.id, b.isbn, b.title, b.author, b.tags, b.category, b.summary, b.difficulty,
                       b.target_reader AS targetReader, b.cover_color AS coverColor,
                       b.source_type AS sourceType, b.readable, b.import_status AS importStatus,
                       b.source_note AS sourceNote, b.publisher, b.publish_date AS publishDate,
                       b.translator, b.edition_note AS editionNote, b.book_info AS bookInfo,
                       (SELECT COUNT(*) FROM book_chapter bc WHERE bc.book_id = b.id) AS chapterCount,
                       b.rating, b.rating_count AS ratingCount, b.word_count AS wordCount,
                       b.reader_count + (SELECT COUNT(*) FROM favorite f2 WHERE f2.book_id = b.id) AS readerCount,
                       f.created_at AS favoritedAt
                FROM favorite f JOIN book b ON b.id = f.book_id
                WHERE f.user_id = ?
                ORDER BY f.created_at DESC
                """, userId);
    }

    public long createPlan(long userId, long bookId, int targetDays) {
        return createPlan(userId, bookId, targetDays, 30, 210);
    }

    public long createPlan(long userId, long bookId, int targetDays, int dailyMinutesTarget, int weeklyMinutesTarget) {
        jdbc.update("""
                INSERT INTO reading_plan
                  (user_id, book_id, target_days, daily_minutes_target, weekly_minutes_target, progress, status)
                VALUES (?, ?, ?, ?, ?, 0, 'active')
                ON DUPLICATE KEY UPDATE
                  target_days = VALUES(target_days),
                  daily_minutes_target = VALUES(daily_minutes_target),
                  weekly_minutes_target = VALUES(weekly_minutes_target),
                  status = CASE WHEN status = 'finished' THEN 'active' ELSE status END,
                  updated_at = CURRENT_TIMESTAMP
                """, userId, bookId, targetDays,
                Math.max(1, dailyMinutesTarget), Math.max(1, weeklyMinutesTarget));
        Number key = jdbc.queryForObject("""
                SELECT id FROM reading_plan WHERE user_id = ? AND book_id = ? LIMIT 1
                """, Number.class, userId, bookId);
        return key == null ? 0 : key.longValue();
    }

    public int deletePlan(long userId, long planId) {
        return jdbc.update("DELETE FROM reading_plan WHERE user_id = ? AND id = ?", userId, planId);
    }

    public int deletePlanByBook(long userId, long bookId) {
        return jdbc.update("DELETE FROM reading_plan WHERE user_id = ? AND book_id = ?", userId, bookId);
    }

    public int updatePlan(long userId, long planId, int progress, String status, String chapterId, int scrollOffset,
                          Integer targetDays, Integer dailyMinutesTarget, Integer weeklyMinutesTarget) {
        return jdbc.update("""
                UPDATE reading_plan
                SET progress = ?, status = ?, chapter_id = ?, scroll_offset = ?,
                    target_days = COALESCE(?, target_days),
                    daily_minutes_target = COALESCE(?, daily_minutes_target),
                    weekly_minutes_target = COALESCE(?, weekly_minutes_target),
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ? AND user_id = ?
                """,
                Math.max(0, Math.min(progress, 100)),
                status,
                chapterId,
                Math.max(0, scrollOffset),
                targetDays == null ? null : Math.max(1, targetDays),
                dailyMinutesTarget == null ? null : Math.max(1, dailyMinutesTarget),
                weeklyMinutesTarget == null ? null : Math.max(1, weeklyMinutesTarget),
                planId,
                userId);
    }

    public int updatePlan(long userId, long planId, int progress, String status, String chapterId, int scrollOffset) {
        return updatePlan(userId, planId, progress, status, chapterId, scrollOffset, null, null, null);
    }

    public List<Map<String, Object>> listPlans(long userId) {
        return jdbc.queryForList("""
                SELECT p.id, p.user_id AS userId, p.book_id AS bookId, p.target_days AS targetDays,
                       p.daily_minutes_target AS dailyMinutesTarget,
                       p.weekly_minutes_target AS weeklyMinutesTarget,
                       p.progress, p.status, p.chapter_id AS chapterId, p.scroll_offset AS scrollOffset,
                       p.created_at AS createdAt, p.updated_at AS updatedAt,
                       CASE WHEN p.status = 'finished' OR p.progress >= 100 THEN p.updated_at ELSE NULL END AS completedAt,
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

    public Map<String, Object> createReaderHighlight(long userId, long bookId, String chapterId,
                                                     int paragraphIndex, int startOffset, int endOffset, String selectedText,
                                                     String bookTitle, String chapterTitle) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO reader_highlight
                      (user_id, book_id, chapter_id, paragraph_index, start_offset, end_offset,
                       selected_text, book_title, chapter_title)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                      start_offset = VALUES(start_offset),
                      end_offset = VALUES(end_offset),
                      selected_text = VALUES(selected_text),
                      book_title = VALUES(book_title),
                      chapter_title = VALUES(chapter_title),
                      updated_at = CURRENT_TIMESTAMP,
                      id = LAST_INSERT_ID(id)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, userId);
            ps.setLong(2, bookId);
            ps.setString(3, chapterId);
            ps.setInt(4, paragraphIndex);
            ps.setInt(5, Math.max(0, startOffset));
            ps.setInt(6, Math.max(0, endOffset));
            ps.setString(7, selectedText);
            ps.setString(8, bookTitle);
            ps.setString(9, chapterTitle);
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        long id = key == null ? 0 : key.longValue();
        return findReaderHighlight(id, userId, bookId, chapterId, paragraphIndex);
    }

    public Map<String, Object> findReaderHighlight(long id, long userId, long bookId,
                                                   String chapterId, int paragraphIndex) {
        List<Map<String, Object>> values = jdbc.queryForList("""
                SELECT id, user_id AS userId, book_id AS bookId, chapter_id AS chapterId,
                       paragraph_index AS paragraphIndex, start_offset AS startOffset, end_offset AS endOffset,
                       selected_text AS selectedText,
                       book_title AS bookTitle, chapter_title AS chapterTitle, created_at AS createdAt
                FROM reader_highlight
                WHERE (id = ? AND id > 0)
                   OR (user_id = ? AND book_id = ? AND chapter_id = ? AND paragraph_index = ?)
                ORDER BY id DESC
                LIMIT 1
                """, id, userId, bookId, chapterId, paragraphIndex);
        return values.isEmpty() ? Map.of() : values.get(0);
    }

    public List<Map<String, Object>> listReaderHighlights(long userId, long bookId, String chapterId) {
        return jdbc.queryForList("""
                SELECT id, user_id AS userId, book_id AS bookId, chapter_id AS chapterId,
                       paragraph_index AS paragraphIndex, start_offset AS startOffset, end_offset AS endOffset,
                       selected_text AS selectedText,
                       book_title AS bookTitle, chapter_title AS chapterTitle, created_at AS createdAt
                FROM reader_highlight
                WHERE user_id = ? AND book_id = ? AND chapter_id = ?
                ORDER BY paragraph_index ASC, created_at ASC
                """, userId, bookId, chapterId);
    }

    public Map<String, Object> createReaderComment(long userId, long bookId, String chapterId,
                                                   int paragraphIndex, String selectedText, String content) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO reader_comment
                      (user_id, book_id, chapter_id, paragraph_index, selected_text, content)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, userId);
            ps.setLong(2, bookId);
            ps.setString(3, chapterId);
            ps.setInt(4, paragraphIndex);
            ps.setString(5, selectedText);
            ps.setString(6, content);
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        long id = key == null ? 0 : key.longValue();
        List<Map<String, Object>> values = jdbc.queryForList("""
                SELECT c.id, c.user_id AS userId, COALESCE(NULLIF(u.nickname, ''), u.name, CONCAT('用户 ', c.user_id)) AS userName,
                       COALESCE(u.avatar_url, '') AS avatarUrl, c.book_id AS bookId, c.chapter_id AS chapterId,
                       c.paragraph_index AS paragraphIndex, c.selected_text AS selectedText,
                       c.content, c.created_at AS createdAt
                FROM reader_comment c LEFT JOIN `user` u ON u.id = c.user_id
                WHERE c.id = ?
                """, id);
        return values.isEmpty() ? Map.of() : values.get(0);
    }

    public List<Map<String, Object>> listReaderComments(long userId, long bookId, String chapterId, int paragraphIndex) {
        return jdbc.queryForList("""
                SELECT c.id, c.user_id AS userId, COALESCE(NULLIF(u.nickname, ''), u.name, CONCAT('用户 ', c.user_id)) AS userName,
                       COALESCE(u.avatar_url, '') AS avatarUrl, c.book_id AS bookId, c.chapter_id AS chapterId,
                       c.paragraph_index AS paragraphIndex, c.selected_text AS selectedText,
                       c.content, c.created_at AS createdAt
                FROM reader_comment c LEFT JOIN `user` u ON u.id = c.user_id
                WHERE c.book_id = ? AND c.chapter_id = ? AND c.paragraph_index = ?
                ORDER BY c.created_at ASC
                LIMIT 80
                """, bookId, chapterId, paragraphIndex);
    }

    public void saveRecommendation(long userId, String query, Map<String, Object> result) {
        jdbc.update("""
                INSERT INTO recommend_record (user_id, query, result_json, sources_json)
                VALUES (?, ?, ?, ?)
                """, userId, query, json(result), json(result.getOrDefault("sources", List.of())));
    }

    public long saveChat(long userId, Long bookId, String question, String answer, Object sources) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO chat_record (user_id, book_id, question, answer, sources_json)
                    VALUES (?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, userId);
            if (bookId == null || bookId <= 0) {
                ps.setObject(2, null);
            } else {
                ps.setLong(2, bookId);
            }
            ps.setString(3, question);
            ps.setString(4, answer);
            ps.setString(5, json(sources));
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        return key == null ? 0 : key.longValue();
    }

    public void saveQuestionAnalysis(long chatRecordId, long userId, Long bookId, String chapterId,
                                     String question, String answer, String questionType, int depthLevel, Object sources) {
        int sourceCount = sources instanceof List<?> list ? list.size() : 0;
        jdbc.update("""
                INSERT INTO user_question_analysis
                  (chat_record_id, user_id, book_id, chapter_id, question, answer, question_type, depth_level,
                   topic_keywords, mentioned_characters, knowledge_gaps, source_count, saved_as_note)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                """,
                chatRecordId <= 0 ? null : chatRecordId,
                userId,
                bookId == null || bookId <= 0 ? null : bookId,
                chapterId == null ? "" : chapterId,
                question,
                answer,
                questionType,
                Math.max(1, Math.min(depthLevel, 5)),
                json(extractKeywords(question)),
                json(List.of()),
                json(List.of()),
                sourceCount);
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

    public void saveBehaviorEvent(Map<String, Object> event) {
        jdbc.update("""
                INSERT INTO user_behavior_event
                  (user_id, event_type, book_id, chapter_id, keyword, tag, duration_seconds, progress, extra)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                longValue(event, "user_id", 10086L),
                string(event, "event_type"),
                nullableLong(event, "book_id"),
                string(event, "chapter_id"),
                string(event, "keyword"),
                string(event, "tag"),
                integer(event, "duration_seconds"),
                decimal(event, "progress"),
                json(event.getOrDefault("extra", Map.of())));
    }

    public void saveBehaviorEvents(List<Map<String, Object>> events) {
        for (Map<String, Object> event : events) {
            saveBehaviorEvent(event);
        }
    }

    public Map<String, Object> readingStats(long userId) {
        Number todaySeconds = jdbc.queryForObject("""
                SELECT COALESCE(SUM(duration_seconds), 0)
                FROM user_behavior_event
                WHERE user_id = ? AND event_type = 'READING_SESSION_END' AND DATE(created_at) = CURDATE()
                """, Number.class, userId);
        List<Map<String, Object>> daily = jdbc.queryForList("""
                SELECT DATE(created_at) AS day, COALESCE(SUM(duration_seconds), 0) AS seconds
                FROM user_behavior_event
                WHERE user_id = ? AND event_type = 'READING_SESSION_END'
                  AND created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
                GROUP BY DATE(created_at)
                ORDER BY day
                """, userId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("todaySeconds", todaySeconds == null ? 0 : todaySeconds.longValue());
        result.put("dailySeconds", daily);
        return result;
    }

    public Map<String, Object> findProfileAnalysis(long userId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT user_id AS userId, explicit_interests AS explicitInterests, inferred_interests AS inferredInterests,
                       genre_weights AS genreWeights, author_weights AS authorWeights,
                       difficulty_preference AS difficultyPreference, reading_goal AS readingGoal,
                       reading_stage AS readingStage, reading_level AS readingLevel,
                       avg_reading_minutes_per_day AS avgReadingMinutesPerDay,
                       reading_streak_days AS readingStreakDays, completion_rate AS completionRate,
                       abandonment_rate AS abandonmentRate, dominant_question_types AS dominantQuestionTypes,
                       knowledge_gaps AS knowledgeGaps, interest_topics AS interestTopics,
                       channel_preference AS channelPreference, ai_summary AS aiSummary, updated_at AS updatedAt
                FROM user_profile_analysis
                WHERE user_id = ?
                """, userId);
        return rows.isEmpty() ? Map.of() : rows.get(0);
    }

    public Map<String, Object> rebuildProfileAnalysis(long userId) {
        Map<String, Object> profile = findProfile(userId);
        List<Map<String, Object>> questionTypes = jdbc.queryForList("""
                SELECT question_type AS type, COUNT(*) AS count
                FROM user_question_analysis
                WHERE user_id = ?
                GROUP BY question_type
                ORDER BY count DESC
                LIMIT 8
                """, userId);
        List<Map<String, Object>> eventTypes = jdbc.queryForList("""
                SELECT event_type AS type, COUNT(*) AS count
                FROM user_behavior_event
                WHERE user_id = ?
                GROUP BY event_type
                ORDER BY count DESC
                LIMIT 8
                """, userId);
        Number avgSeconds = jdbc.queryForObject("""
                SELECT COALESCE(AVG(duration_seconds), 0)
                FROM user_behavior_event
                WHERE user_id = ? AND event_type IN ('READING_SESSION_END', 'OPEN_READER', 'SAVE_PROGRESS')
                """, Number.class, userId);
        Map<String, Object> analysis = new LinkedHashMap<>();
        analysis.put("explicitInterests", splitTerms(string(profile, "interests")));
        analysis.put("inferredInterests", eventTypes);
        analysis.put("genreWeights", eventTypes);
        analysis.put("authorWeights", List.of());
        analysis.put("difficultyPreference", "");
        analysis.put("readingGoal", string(profile, "goal"));
        analysis.put("readingStage", questionTypes.isEmpty() ? "初始画像" : "持续伴读");
        analysis.put("readingLevel", questionTypes.size() >= 3 ? "进阶" : "入门");
        analysis.put("avgReadingMinutesPerDay", BigDecimal.valueOf((avgSeconds == null ? 0 : avgSeconds.doubleValue()) / 60.0));
        analysis.put("readingStreakDays", 0);
        analysis.put("completionRate", BigDecimal.ZERO);
        analysis.put("abandonmentRate", BigDecimal.ZERO);
        analysis.put("dominantQuestionTypes", questionTypes);
        analysis.put("knowledgeGaps", List.of());
        analysis.put("interestTopics", splitTerms(string(profile, "interests")));
        analysis.put("channelPreference", splitTerms(string(profile, "channels")));
        analysis.put("aiSummary", "基于当前阅读行为和提问记录生成的规则画像。");
        upsertProfileAnalysis(userId, analysis);
        return findProfileAnalysis(userId);
    }

    public void upsertProfileAnalysis(long userId, Map<String, Object> analysis) {
        jdbc.update("""
                INSERT INTO user_profile_analysis
                  (user_id, explicit_interests, inferred_interests, genre_weights, author_weights,
                   difficulty_preference, reading_goal, reading_stage, reading_level,
                   avg_reading_minutes_per_day, reading_streak_days, completion_rate, abandonment_rate,
                   dominant_question_types, knowledge_gaps, interest_topics, channel_preference, ai_summary)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                  explicit_interests = VALUES(explicit_interests),
                  inferred_interests = VALUES(inferred_interests),
                  genre_weights = VALUES(genre_weights),
                  author_weights = VALUES(author_weights),
                  difficulty_preference = VALUES(difficulty_preference),
                  reading_goal = VALUES(reading_goal),
                  reading_stage = VALUES(reading_stage),
                  reading_level = VALUES(reading_level),
                  avg_reading_minutes_per_day = VALUES(avg_reading_minutes_per_day),
                  reading_streak_days = VALUES(reading_streak_days),
                  completion_rate = VALUES(completion_rate),
                  abandonment_rate = VALUES(abandonment_rate),
                  dominant_question_types = VALUES(dominant_question_types),
                  knowledge_gaps = VALUES(knowledge_gaps),
                  interest_topics = VALUES(interest_topics),
                  channel_preference = VALUES(channel_preference),
                  ai_summary = VALUES(ai_summary),
                  updated_at = CURRENT_TIMESTAMP
                """,
                userId,
                json(analysis.get("explicitInterests")),
                json(analysis.get("inferredInterests")),
                json(analysis.get("genreWeights")),
                json(analysis.get("authorWeights")),
                string(analysis, "difficultyPreference"),
                string(analysis, "readingGoal"),
                string(analysis, "readingStage"),
                string(analysis, "readingLevel"),
                decimal(analysis, "avgReadingMinutesPerDay"),
                integer(analysis, "readingStreakDays"),
                decimal(analysis, "completionRate"),
                decimal(analysis, "abandonmentRate"),
                json(analysis.get("dominantQuestionTypes")),
                json(analysis.get("knowledgeGaps")),
                json(analysis.get("interestTopics")),
                json(analysis.get("channelPreference")),
                string(analysis, "aiSummary"));
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

    public long importBook(Map<String, Object> book, List<Map<String, Object>> chapters, List<Map<String, Object>> chunks) {
        String isbn = string(book, "isbn");
        String tags = string(book, "tags").isBlank() ? "本地导入,可读,AI伴读" : string(book, "tags");
        String category = string(book, "category").isBlank() ? categoryFromTags(tags) : string(book, "category");
        String difficulty = string(book, "difficulty").isBlank() ? "待评估" : string(book, "difficulty");
        String targetReader = string(book, "targetReader").isBlank()
                ? "希望把本地资料纳入搜索、阅读计划和 AI 伴读的学生"
                : string(book, "targetReader");
        String publisher = string(book, "publisher").isBlank() ? "本地导入" : string(book, "publisher");
        String publishDate = string(book, "publishDate").isBlank() ? "本地资料" : string(book, "publishDate");
        String editionNote = string(book, "editionNote").isBlank()
                ? category + " · " + difficulty + " · " + targetReader
                : string(book, "editionNote");
        String bookInfo = string(book, "bookInfo").isBlank()
                ? "分类：" + category + "；标签：" + tags + "；适合读者：" + targetReader
                : string(book, "bookInfo");
        jdbc.update("""
                INSERT INTO book (isbn, title, author, tags, category, summary, difficulty, target_reader,
                                  rating, rating_count, word_count, reader_count, publisher, publish_date,
                                  translator, edition_note, book_info, cover_color,
                                  source_type, readable, import_status, source_note)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0.0, 0, 0, 0, ?, ?, ?, ?, ?, ?, ?, 1, 'ready', ?)
                ON DUPLICATE KEY UPDATE
                  title = VALUES(title),
                  author = VALUES(author),
                  tags = VALUES(tags),
                  category = VALUES(category),
                  summary = VALUES(summary),
                  difficulty = VALUES(difficulty),
                  target_reader = VALUES(target_reader),
                  publisher = VALUES(publisher),
                  publish_date = VALUES(publish_date),
                  translator = VALUES(translator),
                  edition_note = VALUES(edition_note),
                  book_info = VALUES(book_info),
                  cover_color = VALUES(cover_color),
                  source_type = VALUES(source_type),
                  readable = 1,
                  import_status = 'ready',
                  source_note = VALUES(source_note)
                """,
                isbn,
                string(book, "title"),
                string(book, "author"),
                tags,
                category,
                string(book, "summary"),
                difficulty,
                targetReader,
                publisher,
                publishDate,
                string(book, "translator"),
                editionNote,
                bookInfo,
                string(book, "coverColor"),
                string(book, "sourceType"),
                string(book, "sourceNote"));

        Number key = jdbc.queryForObject("SELECT id FROM book WHERE isbn = ?", Number.class, isbn);
        long bookId = key == null ? 0L : key.longValue();
        if (bookId <= 0) {
            throw new SmartReadException(HttpStatus.INTERNAL_SERVER_ERROR, "无法定位导入后的书籍记录");
        }
        jdbc.update("DELETE FROM book_chapter WHERE book_id = ?", bookId);
        jdbc.update("DELETE FROM book_chunk WHERE book_id = ?", bookId);

        for (Map<String, Object> chapter : chapters) {
            jdbc.update("""
                    INSERT INTO book_chapter (book_id, chapter_id, title, chapter_order, summary, content, paragraphs_json, page_count)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    bookId,
                    string(chapter, "chapterId"),
                    string(chapter, "title"),
                    integer(chapter, "order"),
                    string(chapter, "summary"),
                    string(chapter, "content"),
                    json(chapter.getOrDefault("paragraphs", Collections.emptyList())),
                    integer(chapter, "pageCount"));
        }

        int index = 1;
        for (Map<String, Object> chunk : chunks) {
            jdbc.update("""
                    INSERT INTO book_chunk (book_id, source, chunk_text, chunk_index)
                    VALUES (?, ?, ?, ?)
                    """,
                    bookId,
                    string(chunk, "source"),
                    string(chunk, "text"),
                    index++);
        }

        jdbc.update("""
                INSERT INTO book_import_record (book_id, source_type, file_name, status, message)
                VALUES (?, ?, ?, 'ready', ?)
                """,
                bookId,
                string(book, "sourceType"),
                string(book, "fileName"),
                "本地导入已入库");
        return bookId;
    }

    public List<Map<String, Object>> importMetadataBooks(List<Map<String, Object>> books, String sourceNote) {
        List<Map<String, Object>> imported = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (Map<String, Object> book : books) {
            String title = string(book, "title").trim();
            if (title.isBlank() || !seen.add(title)) {
                continue;
            }
            String author = string(book, "author").isBlank() ? "待补充" : string(book, "author");
            String isbn = string(book, "isbn");
            if (isbn.isBlank()) {
                isbn = "external-" + Integer.toUnsignedString((title + "\n" + author).hashCode());
            }
            String summary = string(book, "summary").isBlank()
                    ? string(book, "reason")
                    : string(book, "summary");
            if (summary.isBlank()) {
                summary = "由真实推荐检索发现并写入数据库的图书元数据，后续可补充章节、来源片段和渠道信息。";
            }
            String tags = string(book, "tags").isBlank() ? "外部检索,真实入库,待补章节" : string(book, "tags");
            String category = string(book, "category").isBlank() ? categoryFromTags(tags) : string(book, "category");
            String difficulty = string(book, "difficulty").isBlank() ? "待评估" : string(book, "difficulty");
            String targetReader = string(book, "targetReader").isBlank() ? "需要先确认书籍信息和阅读目标的学生" : string(book, "targetReader");
            String bookInfo = "分类：" + category + "；标签：" + tags + "；适合读者：" + targetReader;
            jdbc.update("""
                    INSERT INTO book (isbn, title, author, tags, category, summary, difficulty, target_reader,
                                      rating, rating_count, word_count, reader_count, publisher, publish_date,
                                      translator, edition_note, book_info, cover_color,
                                      source_type, readable, import_status, source_note)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0.0, 0, 0, 0, ?, ?, ?, ?, ?, ?, 'external_metadata', 0, 'metadata_ready', ?)
                    ON DUPLICATE KEY UPDATE
                      title = VALUES(title),
                      author = VALUES(author),
                      tags = VALUES(tags),
                      category = VALUES(category),
                      summary = VALUES(summary),
                      difficulty = VALUES(difficulty),
                      target_reader = VALUES(target_reader),
                      publisher = VALUES(publisher),
                      publish_date = VALUES(publish_date),
                      translator = VALUES(translator),
                      edition_note = VALUES(edition_note),
                      book_info = VALUES(book_info),
                      cover_color = VALUES(cover_color),
                      source_type = VALUES(source_type),
                      import_status = VALUES(import_status),
                      source_note = VALUES(source_note)
                    """,
                    isbn,
                    title,
                    author,
                    tags,
                    category,
                    summary,
                    difficulty,
                    targetReader,
                    string(book, "publisher").isBlank() ? "外部元数据来源" : string(book, "publisher"),
                    string(book, "publishDate").isBlank() ? "待补充" : string(book, "publishDate"),
                    string(book, "translator"),
                    category + " · " + difficulty + " · " + targetReader,
                    bookInfo,
                    string(book, "coverColor").isBlank() ? "#F5F0E8" : string(book, "coverColor"),
                    sourceNote);
            Number key = jdbc.queryForObject("SELECT id FROM book WHERE isbn = ?", Number.class, isbn);
            long bookId = key == null ? 0L : key.longValue();
            if (bookId <= 0) {
                continue;
            }
            jdbc.update("DELETE FROM book_chunk WHERE book_id = ?", bookId);
            jdbc.update("""
                    INSERT INTO book_chunk (book_id, source, chunk_text, chunk_index)
                    VALUES (?, ?, ?, 1)
                    """,
                    bookId,
                    title + " · 元数据来源",
                    summary);
            jdbc.update("""
                    INSERT INTO book_import_record (book_id, source_type, file_name, status, message)
                    VALUES (?, 'external_metadata', ?, 'metadata_ready', ?)
                    """,
                    bookId,
                    isbn,
                    sourceNote);
            imported.addAll(searchBooks(title, "", 0, 1));
        }
        return imported;
    }

    private void addColumnIfMissing(String table, String column, String definition) {
        if (!columnExists(table, column)) {
            jdbc.execute("ALTER TABLE `" + table + "` ADD COLUMN " + definition);
        }
    }

    private void modifyColumnIfExists(String table, String column, String definition) {
        if (columnExists(table, column)) {
            jdbc.execute("ALTER TABLE `" + table + "` MODIFY " + definition);
        }
    }

    private void dropColumnIfExists(String table, String column) {
        if (columnExists(table, column)) {
            jdbc.execute("ALTER TABLE `" + table + "` DROP COLUMN `" + column + "`");
        }
    }

    private boolean columnExists(String table, String column) {
        Integer count = jdbc.queryForObject("""
                SELECT COUNT(*)
                FROM information_schema.columns
                WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?
                """, Integer.class, table, column);
        return count != null && count > 0;
    }

    private boolean columnIsAutoIncrement(String table, String column) {
        String extra = jdbc.queryForObject("""
                SELECT EXTRA
                FROM information_schema.columns
                WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?
                """, String.class, table, column);
        return extra != null && extra.toLowerCase().contains("auto_increment");
    }

    private void addIndexIfMissing(String table, String index, String ddl) {
        Integer count = jdbc.queryForObject("""
                SELECT COUNT(*)
                FROM information_schema.statistics
                WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?
                """, Integer.class, table, index);
        if (count == null || count <= 0) {
            jdbc.execute(ddl);
        }
    }

    private void ensureReadingPlanUniqueIndex() {
        addIndexIfMissing("reading_plan", "idx_reading_plan_user_book_cleanup",
                "ALTER TABLE reading_plan ADD KEY idx_reading_plan_user_book_cleanup (user_id, book_id, updated_at)");
        jdbc.update("""
                DELETE rp FROM reading_plan rp
                JOIN reading_plan newer
                  ON newer.user_id = rp.user_id
                 AND newer.book_id = rp.book_id
                 AND (newer.updated_at > rp.updated_at OR (newer.updated_at = rp.updated_at AND newer.id > rp.id))
                """);
        addIndexIfMissing("reading_plan", "uk_reading_plan_user_book",
                "ALTER TABLE reading_plan ADD UNIQUE KEY uk_reading_plan_user_book (user_id, book_id)");
    }

    private void ensureReadingPlanSettingsSchema() {
        addColumnIfMissing("reading_plan", "daily_minutes_target",
                "daily_minutes_target INT NOT NULL DEFAULT 30 AFTER target_days");
        addColumnIfMissing("reading_plan", "weekly_minutes_target",
                "weekly_minutes_target INT NOT NULL DEFAULT 210 AFTER daily_minutes_target");
    }

    private static Long nullableLong(Map<String, Object> map, String key) {
        Object value = map.get(key);
        if (value instanceof Number number) {
            long parsed = number.longValue();
            return parsed > 0 ? parsed : null;
        }
        if (value == null || value.toString().isBlank()) {
            return null;
        }
        long parsed = Long.parseLong(value.toString());
        return parsed > 0 ? parsed : null;
    }

    private static long longValue(Map<String, Object> map, String key, long fallback) {
        Object value = map.get(key);
        if (value instanceof Number number) {
            return number.longValue();
        }
        if (value == null || value.toString().isBlank()) {
            return fallback;
        }
        return Long.parseLong(value.toString());
    }

    private static List<String> splitTerms(String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        List<String> terms = new ArrayList<>();
        for (String part : raw.split("[,，、;；\\s]+")) {
            String term = part == null ? "" : part.trim();
            if (!term.isBlank() && !terms.contains(term)) {
                terms.add(term);
            }
        }
        return terms;
    }

    private static String categoryFromTags(String tags) {
        String text = tags == null ? "" : tags;
        if (text.contains("人工智能") || text.contains("机器学习") || text.contains("深度学习")
                || text.contains("算法") || text.contains("计算机") || text.contains("数据库")
                || text.contains("Linux") || text.contains("Java") || text.contains("Python") || text.contains("Go")) {
            return "计算机科学";
        }
        if (text.contains("高等数学") || text.contains("线性代数") || text.contains("概率论")
                || text.contains("统计") || text.contains("离散数学") || text.contains("微积分")) {
            return "数学与统计";
        }
        if (text.contains("英语") || text.contains("考研") || text.contains("六级")) {
            return "英语与考试";
        }
        if (text.contains("文学") || text.contains("小说") || text.contains("人文")
                || text.contains("历史") || text.contains("哲学")) {
            return "文学与人文";
        }
        if (text.contains("经济") || text.contains("管理") || text.contains("创业")) {
            return "经济管理";
        }
        if (text.contains("设计")) {
            return "设计艺术";
        }
        return "通识阅读";
    }

    private static List<String> extractKeywords(String question) {
        if (question == null || question.isBlank()) {
            return List.of();
        }
        List<String> terms = splitTerms(question.replaceAll("[？?，。！!：:]", " "));
        return terms.size() <= 8 ? terms : terms.subList(0, 8);
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

    private String bookSelect() {
        return """
                SELECT id, isbn, title, author, tags, summary, difficulty,
                       category, target_reader AS targetReader, cover_color AS coverColor,
                       source_type AS sourceType, readable, import_status AS importStatus,
                       source_note AS sourceNote, publisher, publish_date AS publishDate,
                       translator, edition_note AS editionNote, book_info AS bookInfo,
                       (SELECT COUNT(*) FROM book_chapter bc WHERE bc.book_id = book.id) AS chapterCount,
                       rating,
                       rating_count AS ratingCount,
                       word_count AS wordCount,
                       reader_count + (SELECT COUNT(*) FROM favorite f WHERE f.book_id = book.id) AS readerCount
                FROM book
                """;
    }

    private List<String> profileTerms(long userId) {
        if (userId <= 0) {
            return List.of();
        }
        try {
            Map<String, Object> profile = findProfile(userId);
            String raw = string(profile, "interests") + "," + string(profile, "goal");
            String[] parts = raw.split("[,，、;；\\s]+");
            List<String> terms = new ArrayList<>();
            for (String part : parts) {
                String term = part == null ? "" : part.trim();
                if (!term.isBlank() && !terms.contains(term)) {
                    terms.add(term);
                }
                if (terms.size() >= 4) {
                    break;
                }
            }
            return terms;
        } catch (Exception exc) {
            return List.of();
        }
    }

    private static List<String> paragraphs(Object paragraphsJson, String content) {
        if (paragraphsJson instanceof List<?> list && !list.isEmpty()) {
            List<String> paragraphs = new ArrayList<>();
            for (Object item : list) {
                if (item != null && !item.toString().isBlank()) {
                    paragraphs.add(item.toString().trim());
                }
            }
            if (!paragraphs.isEmpty()) {
                return paragraphs;
            }
        }
        if (content == null || content.isBlank()) {
            return List.of();
        }
        return List.of(content.split("\\n\\s*\\n"))
                .stream()
                .map(String::trim)
                .filter(text -> !text.isBlank())
                .toList();
    }

    private static List<Map<String, Object>> cleanChapterRows(List<Map<String, Object>> rows) {
        List<Map<String, Object>> chapters = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            chapters.add(cleanChapterRow(row));
        }
        return chapters;
    }

    private static Map<String, Object> cleanChapterRow(Map<String, Object> row) {
        Map<String, Object> chapter = new LinkedHashMap<>(row);
        chapter.remove("frontMatterProbe");
        return chapter;
    }

    private static boolean validChapterId(List<Map<String, Object>> chapters, String chapterId) {
        if (chapterId == null || chapterId.isBlank()) {
            return false;
        }
        for (Map<String, Object> chapter : chapters) {
            if (chapterId.equals(String.valueOf(chapter.get("chapterId")))) {
                return true;
            }
        }
        return false;
    }

    private static boolean isFrontMatterChapter(Map<String, Object> chapter) {
        String title = string(chapter, "title");
        String probe = string(chapter, "frontMatterProbe");
        String cleanTitle = compact(title).toLowerCase();
        String sample = compact(title + "\n" + probe).toLowerCase();
        if (cleanTitle.matches("(cover|titlepage|contents|tableofcontents|copyright|toc|nav)")
                || cleanTitle.matches("(\u5c01\u9762|\u4e66\u540d\u9875|\u6249\u9875|\u76ee\u5f55|\u76ee\u9304|\u76ee\u6b21|\u7248\u6743|\u7248\u6743\u9875|\u7248\u6743\u4fe1\u606f|\u5236\u4f5c\u4fe1\u606f)")) {
            return true;
        }
        if (sample.startsWith("copyright") || sample.startsWith("\u7248\u6743") || sample.startsWith("\u51fa\u7248\u8bf4\u660e")) {
            return true;
        }
        if (sample.startsWith("contents") || sample.startsWith("tableofcontents")
                || sample.startsWith("\u76ee\u5f55") || sample.startsWith("\u76ee\u9304") || sample.startsWith("\u76ee\u6b21")) {
            return true;
        }
        return looksLikeCatalog(probe);
    }

    private static boolean looksLikeCatalog(String content) {
        if (content == null || content.isBlank()) {
            return false;
        }
        String[] lines = content.replace("\r\n", "\n").replace('\r', '\n').split("\\n");
        int catalogLines = 0;
        int readableLines = 0;
        Pattern chapterRef = Pattern.compile("^(?:\u7b2c[\u4e00-\u9fa5\\d]+[\u7ae0\u8282\u56de\u90e8\u5377\u7bc7]|chapter\\s*\\d+|\\d+[.、]\\s*).*$",
                Pattern.CASE_INSENSITIVE);
        for (String rawLine : lines) {
            String line = rawLine.trim();
            if (line.isBlank()) {
                continue;
            }
            readableLines++;
            if (line.length() <= 120 && (chapterRef.matcher(line).matches()
                    || line.matches(".*[.。·\\s]{2,}\\d{1,4}$"))) {
                catalogLines++;
            }
            if (readableLines >= 24) {
                break;
            }
        }
        return catalogLines >= 3 && catalogLines * 2 >= Math.max(1, readableLines);
    }

    private static String compact(String value) {
        return value == null ? "" : value.replaceAll("[\\s\\p{Punct}\u3000-\u303f]+", "").trim();
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
