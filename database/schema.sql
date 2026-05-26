CREATE DATABASE IF NOT EXISTS hongmeng_zhiyue DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hongmeng_zhiyue;

SOURCE backend/src/main/resources/schema.sql;
SOURCE backend/src/main/resources/data.sql;
