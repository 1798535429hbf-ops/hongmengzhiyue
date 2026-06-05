CREATE TABLE IF NOT EXISTS `user` (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account VARCHAR(80) NOT NULL COMMENT '登录账号，当前阶段默认等于手机号',
  phone VARCHAR(32) NOT NULL COMMENT '手机号',
  password_hash VARCHAR(128) NOT NULL DEFAULT '' COMMENT '密码哈希',
  name VARCHAR(64) NOT NULL,
  nickname VARCHAR(64) NOT NULL DEFAULT '',
  major VARCHAR(80) NOT NULL,
  grade VARCHAR(32) NOT NULL,
  interests TEXT NOT NULL,
  goal VARCHAR(160) NOT NULL,
  intro VARCHAR(255) NOT NULL DEFAULT '',
  avatar_url VARCHAR(500) NOT NULL DEFAULT '',
  channels VARCHAR(160) DEFAULT 'library,jd,dangdang,second_hand',
  status VARCHAR(32) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_account (account),
  UNIQUE KEY uk_user_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS book (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  isbn VARCHAR(32) NOT NULL UNIQUE,
  title VARCHAR(160) NOT NULL,
  author VARCHAR(160) NOT NULL,
  tags VARCHAR(255) NOT NULL,
  category VARCHAR(80) NOT NULL DEFAULT '通识阅读',
  summary TEXT NOT NULL,
  difficulty VARCHAR(32) NOT NULL,
  target_reader VARCHAR(160) NOT NULL,
  rating DECIMAL(3, 1) NOT NULL DEFAULT 0.0,
  rating_count INT NOT NULL DEFAULT 0,
  word_count INT NOT NULL DEFAULT 0,
  reader_count INT NOT NULL DEFAULT 0,
  publisher VARCHAR(120) NOT NULL DEFAULT '待补充',
  publish_date VARCHAR(32) NOT NULL DEFAULT '待补充',
  translator VARCHAR(160) NOT NULL DEFAULT '',
  edition_note VARCHAR(160) NOT NULL DEFAULT '',
  book_info TEXT,
  cover_color VARCHAR(32) DEFAULT '#1A2A3A',
  source_type VARCHAR(32) NOT NULL DEFAULT 'manual_seed',
  readable TINYINT(1) NOT NULL DEFAULT 0,
  import_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  source_note VARCHAR(255) DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS book_chunk (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  book_id BIGINT NOT NULL,
  source VARCHAR(160) NOT NULL,
  chunk_text TEXT NOT NULL,
  chunk_index INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_book_chunk (book_id, chunk_index),
  CONSTRAINT fk_chunk_book FOREIGN KEY (book_id) REFERENCES book(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE IF NOT EXISTS favorite (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id BIGINT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_favorite_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS recommend_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  query TEXT NOT NULL,
  result_json JSON NOT NULL,
  sources_json JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS chat_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id BIGINT,
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  sources_json JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS reading_plan (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id BIGINT NOT NULL,
  target_days INT NOT NULL,
  daily_minutes_target INT NOT NULL DEFAULT 30,
  weekly_minutes_target INT NOT NULL DEFAULT 210,
  progress INT NOT NULL DEFAULT 0,
  status VARCHAR(32) NOT NULL DEFAULT 'active',
  chapter_id VARCHAR(64) DEFAULT '',
  scroll_offset INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_reading_plan_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS note (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id BIGINT,
  content TEXT NOT NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'ai_answer',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS commerce_result (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  isbn VARCHAR(32) NOT NULL,
  book_id BIGINT,
  platform VARCHAR(64) NOT NULL,
  price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  stock INT NOT NULL DEFAULT 0,
  url VARCHAR(500),
  delivery VARCHAR(120),
  library_status VARCHAR(80),
  raw_json JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS purchase_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id BIGINT NOT NULL,
  platform VARCHAR(64) NOT NULL,
  action VARCHAR(32) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  pay_status VARCHAR(32) NOT NULL,
  confirm_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
