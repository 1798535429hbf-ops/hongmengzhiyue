---
name: local-library-reader-expansion
description: 鸿蒙智阅本地书库扩充与阅读闭环设计。
metadata:
  type: project
---

# 本地书库与阅读功能扩充设计

## 目标
把当前的图书搜索与推荐，扩展成一条真正可用的本地阅读闭环。第一阶段必须支持：搜索图书、进入详情页、打开阅读器、查看章节与正文、保存阅读进度、保存摘录笔记，以及继续进入 AI 伴读。

本次实现不允许从 z-lib 或其他未授权来源下载图书。图书数据必须来自公版/开放授权内容、用户自己拥有的本地文件，或手工编写的种子/演示内容。

## 范围

### 第一阶段
- 保留现有 HarmonyOS + Spring Boot + MySQL 架构。
- 扩展后端数据库，让图书具备可读的章节内容。
- 至少种入 20 本图书，包含元数据、章节摘要和少量合法/自写阅读摘录。
- 让现有阅读接口返回真实数据库数据。
- 让 HarmonyOS 阅读流程继续沿用当前接口契约。
- 为后续 TXT 和 EPUB 导入预留数据库与服务边界。

### 后续阶段
- 增加 TXT 导入与章节切分。
- 增加 EPUB 解析与章节入库。
- 如有需要，再补前端上传/导入管理。

### 第一阶段不做
- 下载 z-lib 或类似站点上的受版权保护图书。
- DRM 处理。
- 完整 EPUB 渲染、图片、CSS 还原或分页排版 fidelity。
- 在线书城功能。
- 复杂云同步。

## 现有项目上下文

HarmonyOS 应用位于 `harmony-app`，当前已经定义了阅读相关的数据模型和 API 调用：

- `entry/src/main/ets/common/Models.ets`
- `entry/src/main/ets/common/ApiClient.ets`
- `entry/src/main/ets/pages/ReaderPage.ets`

后端位于同级的 `backend` 目录，是一个带 MySQL 持久化的 Spring Boot 服务，已有控制器、仓储和服务：

- `src/main/resources/schema.sql`
- `src/main/resources/data.sql`
- `src/main/java/com/hakimi/smartread/controller/BookController.java`
- `src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java`
- `src/main/java/com/hakimi/smartread/service/SmartReadService.java`

前端当前已经在使用这些路径：

- `GET /books/search?keyword={keyword}&tag={tag}&page=0&size=30`
- `GET /books/{id}`
- `GET /books/{id}/reader?userId={userId}&chapterId={chapterId}`
- `GET /books/{id}/chapters`
- `GET /books/{id}/content?chapterId={chapterId}`
- `PATCH /plans/{id}`
- `POST /notes`
- `POST /ai/chat`

## 推荐方案
采用分阶段混合方案。

第一阶段先做稳定的数据库阅读闭环，使用规范化章节内容；暂不实现完整 TXT/EPUB 导入，但要把 schema 和服务边界预留好，方便后续导入器直接写入同一套章节表。

这样前端就能始终消费统一的 `chapters`、`content`、`paragraphs`、`sourceRefs`，无论图书来自手工种子、TXT 导入还是 EPUB 解析。

## 数据模型设计

### 扩展 `book`
增加描述图书是否可本地阅读及其来源的字段：

- `source_type`：`manual_seed`、`public_domain`、`local_txt`、`local_epub`
- `readable`：是否有可读正文
- `import_status`：`ready`、`pending`、`failed`
- `source_note`：人类可读的来源/许可证/导入说明

这些字段需要在图书详情中返回，详情页也可以展示。

### 新增 `book_chapter`
新增章节表，作为阅读正文的唯一规范来源：

- `id`
- `book_id`
- `chapter_id`
- `title`
- `chapter_order`
- `summary`
- `content`
- `paragraphs_json`
- `page_count`
- `created_at`
- `updated_at`

`chapter_id` 应在每本书内稳定，例如 `ch-1`、`ch-2`。前端已经支持字符串章节 ID。

### 新增 `book_import_record`
为后续导入流程预留记录表：

- `id`
- `book_id`
- `source_type`
- `file_name`
- `status`
- `message`
- `created_at`
- `updated_at`

第一阶段可以先为手工种子的图书插入 `manual_seed` 记录。后续 TXT 和 EPUB 导入器可以复用这张表。

### 保留 `book_chunk`
继续使用 `book_chunk` 存放 RAG/来源片段。正文内容可以通过图书和章节来源文本关联到这些片段。第一阶段不需要额外的关联表，除非来源面板需要比当前更精确的 chunk 绑定。

## 接口设计

对外接口路径保持不变。

### `GET /books/search`
从 `book` 表返回可检索图书，并在需要时带上可读性字段：

- `sourceType`
- `readable`
- `importStatus`
- `chapterCount`

继续支持关键词和标签过滤。

### `GET /books/{id}`
返回图书元数据、chunks 以及阅读可用性字段：

- `chapterCount`
- `sourceType`
- `readable`
- `importStatus`
- `sourceNote`

### `GET /books/{id}/chapters`
从 `book_chapter` 读取并返回 `ReadingChapter[]`：

- `id`
- `chapterId`
- `bookId`
- `title`
- `order`
- `summary`
- `pageCount`
- `isCurrent`

如果某本图书标记为可读但没有章节，需要返回清晰的后端错误，不要静默伪造数据。

### `GET /books/{id}/content?chapterId=...`
读取单个 `book_chapter` 并返回 `ReadingContent`：

- `bookId`
- `chapterId`
- `chapterTitle`
- `content`
- `paragraphs`
- `sources`
- `sourceRefs`

`paragraphs` 优先使用 `paragraphs_json`，没有时再按换行或段落分隔符拆分 `content`。

### `GET /books/{id}/reader?userId=...&chapterId=...`
聚合现有阅读器 bundle：

- 图书详情
- 当前计划（如存在）
- 章节列表
- 当前正文
- 阅读进度（如存在）
- 书签/笔记（如可用）

如果没有传 `chapterId`，优先选最近正在阅读的章节；否则选第一章。

### `PATCH /plans/{id}`
继续保存进度，沿用现有前端 payload：

- `user_id`
- `book_id`
- `chapter_id`
- `progress`
- `scroll_offset`
- `status`

如果当前 schema 只保存聚合进度，第一阶段可以通过扩展 `reading_plan` 或新增轻量阅读进度表来存章节 ID 和滚动偏移。优先选择与 `ReadingProgress` 最贴近、改动最小的方案。

### `POST /notes`
继续保存摘录笔记，`type` 使用 `reading_excerpt`。

### `POST /ai/chat`
继续使用同一本书的 chunk 和章节片段作为来源材料。如果问题明显与某章节相关，应优先从同书、相关章节或来源片段中取材。

## 种子数据设计

至少种入 20 本图书。可以沿用现有 50 本元数据，但第一阶段必须为其中至少 20 本补齐可读章节内容。

每本可读种子书至少包含：

- 2 到 5 个章节
- 章节标题
- 章节摘要
- 少量自写摘录或公版/开放授权文本
- 1 到 2 条 `book_chunk` 来源片段
- 标明 `manual_seed` 或合法来源类型的 source note

种子正文应足够短，便于演示使用，并且不能复制受版权保护的原文，除非原文本身是公版/开放授权或由用户提供。

## 前端设计

### 阅读器页
`ReaderPage.ets` 仍然是主阅读页面。它已经支持：

- 顶部栏
- 目录抽屉
- 章节切换
- `paragraphs` 或 `content` 渲染
- 来源面板
- 计划创建
- 进度保存
- 摘录笔记保存
- 伴读入口

前端改动应重点放在让页面能稳定接住真实后端响应，而不是重做页面样式。

### 图书详情页
展示阅读元数据：

- 是否可读
- 章节数
- 来源类型 / source note
- 未就绪时的导入状态

如果没有可读内容，阅读按钮应禁用，或给出清晰提示。

### 搜索页
搜索结果需要体现哪些书可直接阅读。如果调整排序，可以适当偏向可读书，但搜索结果仍必须体现关键词/标签匹配。

### API 模型
只给前端实际需要展示的字段扩展 `Book`。保持现有字段名稳定，避免破坏现有页面。

## 验收标准

最终应能完整跑通以下流程：

1. 搜索一本已种入的图书。
2. 打开图书详情。
3. 看到可读状态、章节数和来源信息。
4. 进入阅读器。
5. 看到章节目录。
6. 阅读章节正文。
7. 切换章节。
8. 保存阅读进度。
9. 保存摘录笔记。
10. 从阅读器打开伴读。
11. 提问并获得带来源引用的回答。

后端数据库中应能查到以下记录：

- 图书
- 章节
- 来源片段
- 导入/来源跟踪
- 阅读进度或计划进度
- 笔记
- 伴读记录

## 测试计划

### 后端
- 运行 Spring Boot 测试。
- 调用 `GET /api/books/search`，确认种子书能返回。
- 调用 `GET /api/books/{id}/chapters`，确认可读图书有章节。
- 调用 `GET /api/books/{id}/content?chapterId=...`，确认有 `paragraphs` 和 `sourceRefs`。
- 创建/更新计划，确认进度被持久化。
- 创建一条阅读摘录笔记，确认能在 profile/notes 中看到。

### 前端/手动
- 在 DevEco Studio 或可预览运行时启动 HarmonyOS 应用。
- 搜索一本文字种子图书。
- 打开详情页，再进入阅读器。
- 使用目录、上一章/下一章、保存进度、保存摘录、伴读入口。
- 确认后端不可用或图书无章节时，空态/错误态文案可读。

## 实现顺序

1. 扩展后端 schema，加入可读图书、章节、导入跟踪和进度元数据。
2. 为至少 20 本图书补充章节和合法/手工演示正文。
3. 实现仓储层章节、正文、阅读器 bundle 和计数相关方法。
4. 为 `BookController` 增加或扩展章节、正文和阅读器 bundle 接口。
5. 如进度、笔记或 AI 伴读需要章节感知来源，调整 `SmartReadService`。
6. 扩展前端模型，增加可读元数据。
7. 更新详情页和搜索页，展示可读状态。
8. 用真实后端数据验证 `ReaderPage.ets`，并做最小兼容修复。
9. 运行后端测试，并手动验证前端阅读流程。
