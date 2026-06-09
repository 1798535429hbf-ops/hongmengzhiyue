---
name: harmony-smartread-skeleton-first-ai-qa-rag
description: 基于现有前端、Spring Boot 后端、FastAPI AI 服务骨架的 AI 问答、RAG、MCP、Skills 与数据闭环升级方案
metadata:
  type: project
---

# 鸿蒙智阅现有项目骨架优先版 AI/RAG 升级方案

> 这一版不照 PRD 模板平铺，而是从当前完整项目根目录出发：`harmony-app` 已有 HarmonyOS 端侧骨架，`backend` 已有 Spring Boot 业务后端，`ai-service` 已有 FastAPI AI/RAG 服务，`database` 与后端资源目录已有 schema。下一步不是推倒重来，而是在现有链路上把 RAG、历史记忆、MCP/Skills 和评测做深。

## 1. 当前项目真实结构

完整项目根目录：

```text
C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd
```

关键子工程：

| 子工程 | 作用 | 关键文件 |
|---|---|---|
| `harmony-app` | HarmonyOS Stage + ArkTS + ArkUI 端侧 | `entry/src/main/ets/common/ApiClient.ets`、`Models.ets`、`pages/*` |
| `backend` | Spring Boot 业务后端，提供 `/api/**` | `SmartReadService.java`、`AiGateway.java`、`SmartReadRepository.java`、各 Controller |
| `ai-service` | Python/FastAPI AI/RAG 服务，供后端内部调用 | `app/main.py`、`skills.py`、`rag.py`、`output_parser.py`、`mcp_tools.py` |
| `database` | 数据库脚本 | `database/schema.sql` |
| `backend/src/main/resources` | 后端启动 schema/data | `schema.sql`、`data.sql`、`application.properties` |

所以这份方案的基本判断要修正为：

- 不是“只有前端，后端待补”。
- 不是“AI 服务尚未开始”。
- 当前已经有端、云、智三侧骨架。
- 真正要做的是把已有骨架从“能跑通”升级到“能稳定超越普通 AI 问答”。

## 2. 已有端侧骨架定义了产品形态

HarmonyOS 端已经形成完整阅读链路：

```text
书城 / 搜索
  -> 图书详情
  -> 阅读器 / AI 伴读 / 购书馆藏
  -> 收藏 / 阅读计划 / 笔记 / 问答
  -> 我的页面汇总画像、收藏、计划、笔记、问答历史
```

关键端侧文件：

- `entry/src/main/ets/common/ApiClient.ets`
- `entry/src/main/ets/common/Models.ets`
- `entry/src/main/ets/common/AiResponseView.ets`
- `entry/src/main/ets/pages/StoreContent.ets`
- `entry/src/main/ets/pages/SearchPage.ets`
- `entry/src/main/ets/pages/BookDetailPage.ets`
- `entry/src/main/ets/pages/ReaderPage.ets`
- `entry/src/main/ets/pages/ChatPage.ets`
- `entry/src/main/ets/pages/PlanContent.ets`
- `entry/src/main/ets/pages/ProfileContent.ets`
- `entry/src/main/ets/pages/CommercePage.ets`

当前端侧真正需要服务端保证的是：

| 页面/模块 | 已有能力槽位 | 服务端要稳定支撑 |
|---|---|---|
| `StoreContent` | 书城分区、流式 AI 推荐、推荐书单、来源、工具轨迹 | `/books/store`、`/ai/recommend/stream` |
| `SearchPage` | 关键词/标签搜索、搜索行为上报 | `/books/search`、`/analytics/events` |
| `BookDetailPage` | 详情、收藏状态、计划状态、收藏/取消、创建/删除计划 | `/books/{id}`、`/users/profile`、`/favorites`、`/plans` |
| `ReaderPage` | 章节、正文、连续阅读、进度、划线、评论、阅读器内 AI | `/books/{id}/chapters`、`/books/{id}/content`、`/reader/*`、`/ai/chat/stream` |
| `ChatPage` | 指定图书伴读、来源片段、保存笔记 | `/ai/chat/stream`、`/notes` |
| `PlanContent` | 计划列表、计划候选、目标调整、阅读统计 | `/plans`、`/analytics/reading-stats` |
| `ProfileContent` | 画像、收藏、笔记、计划、问答聚合 | `/users/profile` |
| `CommercePage` | 馆藏/电商/二手渠道、用户确认 | `/commerce/search`、`/purchase/confirm` |
| `ShelfStore` | 本地书导入 | `/import/books` |

这说明产品不是“独立 AI 聊天框”，而是“阅读 App 里的 AI 伴读与推荐中枢”。

## 3. 已有后端骨架

后端已经是 Spring Boot，路径集中在：

```text
C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\backend
```

### 3.1 Controller 已覆盖端侧接口

| Controller | 路径 | 已覆盖能力 |
|---|---|---|
| `BookController.java` | `/api/books` | 搜索、书城分区、详情、章节、正文、阅读器聚合 |
| `AiController.java` | `/api/ai` | 推荐、推荐流、伴读、伴读流 |
| `UserController.java` | `/api/users` | 画像、头像、登录、注册、第三方登录 |
| `PlanController.java` | `/api/plans` | 计划查询、创建、更新、删除、按书删除 |
| `FavoriteController.java` | `/api/favorites` | 收藏、取消收藏 |
| `NoteController.java` | `/api/notes` | 笔记查询、保存 |
| `ReaderInteractionController.java` | `/api/reader` | 划线、段落评论 |
| `CommerceController.java` | `/api/commerce/search`、`/api/purchase/confirm` | 渠道聚合、用户确认 |
| `AnalyticsController.java` | `/api/analytics` | 行为事件、批量事件、画像分析、阅读统计 |
| `ImportController.java` | `/api/import/books` | 本地书导入 |

统一返回包已经有：

- `api/ApiResponse.java`
- `api/GlobalExceptionHandler.java`

### 3.2 `SmartReadService` 已经在做上下文增强

`backend/src/main/java/com/hakimi/smartread/service/SmartReadService.java` 已经不是简单转发 AI。它在推荐链路中会补：

- `user_profile`
- `profile_analysis`
- `candidate_books`
- `fallback_strategy`
- `fallback_reason`
- `reading_history`
- `plans`
- `favorites`
- `chat_records`
- `retrieved_chunks`

推荐链路大致是：

```text
/api/ai/recommend
  -> SmartReadService.buildRecommendContext
  -> 读取画像 / 计划 / 收藏 / 问答历史
  -> 搜索候选书或高评分兜底
  -> findChunks 做 RAG 上下文
  -> AiGateway 调用 ai-service
  -> saveRecommendation 写 recommend_record
```

伴读链路中会补：

- `user_profile`
- `profile_analysis`
- `book`
- `chapter`
- `paragraph`
- `sources`

并在最终结果后写入：

- `chat_record`
- `user_question_analysis`

这已经具备“比普通 AI 问答更懂用户历史和当前图书”的基础。

### 3.3 `AiGateway` 已经接上 FastAPI AI 服务

`backend/src/main/java/com/hakimi/smartread/service/AiGateway.java` 映射关系：

| 后端公开接口 | AI 内部接口 |
|---|---|
| `/api/ai/recommend` | `/internal/rag/recommend` |
| `/api/ai/recommend/stream` | `/internal/rag/recommend/stream` |
| `/api/ai/chat` | `/internal/rag/chat` |
| `/api/ai/chat/stream` | `/internal/rag/chat/stream` |
| `/api/commerce/search` | `/internal/tools/commerce-search` |

流式协议是 `application/x-ndjson`，`AiGateway` 会把 AI 服务返回的每行 JSON 原样写回前端，并在 `type = final` 时触发保存最终结果。

这个设计已经和 `ApiClient.streamRequest` 的事件模型吻合。

## 4. 已有 AI 服务骨架

AI 服务路径：

```text
C:\Users\kong\Documents\Codex\2026-05-11\files-mentioned-by-the-user-prd\ai-service
```

### 4.1 FastAPI 入口

`ai-service/app/main.py` 已有接口：

- `GET /health`
- `GET /health/db`
- `POST /internal/rag/recommend`
- `POST /internal/rag/recommend/stream`
- `POST /internal/rag/chat`
- `POST /internal/rag/chat/stream`
- `POST /internal/tools/commerce-search`
- `GET /internal/mcp/tools`
- `POST /internal/mcp/call`
- `POST /internal/eval/run`

### 4.2 当前 AI 编排模块

| 文件 | 当前职责 |
|---|---|
| `skills.py` | 推荐、流式推荐、伴读、流式伴读、渠道查询的主编排 |
| `rag.py` | 从 `book_chunk` 检索片段，从 `book` 搜索候选书 |
| `intent_router.py` | 识别推荐、聊天、兴趣分析、澄清等意图 |
| `output_parser.py` | Pydantic 校验并归一化推荐/伴读输出 |
| `deepseek_client.py` | 调 DeepSeek，支持 JSON 生成和指定字段流式输出 |
| `tools.py` | search books、external book search、commerce search、order draft 等工具 |
| `mcp_tools.py` | 工具列表和工具调用 facade |
| `harness.py` | 评测入口 |
| `db.py` | MySQL 连接和查询封装 |

### 4.3 重要现实判断

当前 `ai-service/requirements.txt` 里没有 `langchain` 依赖。

所以准确说：

- 当前项目已经有“自研链式 AI 编排雏形”。
- 当前项目已经有 Skills 概念，落点是 `skills.py`。
- 当前项目已经有 MCP 工具 facade，落点是 `mcp_tools.py`。
- 当前项目还没有真正引入 LangChain 包。

因此，“使用 LangChain”不应写成已经完成，而应写成下一步把现有模块链式化、可观测化、可测试化。

## 5. 已有数据库闭环

后端资源 schema：

```text
backend/src/main/resources/schema.sql
```

已经包含核心表：

- `user`
- `user_auth`
- `book`
- `book_chunk`
- `book_chapter`
- `book_import_record`
- `favorite`
- `recommend_record`
- `chat_record`
- `reading_plan`
- `note`
- `commerce_result`
- `purchase_record`
- `user_behavior_event`
- `user_question_analysis`
- `user_profile_analysis`

另外，`SmartReadRepository.ensureReaderInteractionSchema()` 会创建：

- `reader_highlight`
- `reader_comment`

这意味着“收藏、计划、问答、笔记写入数据库”已经不是空想，已有落点。下一步重点不是新增一堆表，而是补强字段、检索和查询体验。

## 6. 当前项目怎么超越普通 AI 问答

不要把目标写成“比豆包更会聊天”。更合适的目标是：

> 普通 AI 回答一个问题；鸿蒙智阅回答一个和当前图书、章节、段落、阅读进度、用户画像、收藏计划、历史问答有关的问题，并且能把结果保存、追溯、继续驱动下一步阅读。

当前已经有基础：

| 差异点 | 已有骨架依据 | 下一步增强 |
|---|---|---|
| 围绕指定图书回答 | `ChatPage`、`ReaderPage` 传 `book_id`；后端补 `book` 和 `sources` | RAG 更强地限定 book scope |
| 围绕章节/段落回答 | `chatPayload` 支持 `chapter_id`、`paragraph`；后端可补 `chapter` | `rag.py` 检索要优先当前章节和段落 |
| 展示来源 | `AiResponseView` 展示 `SourceRef[]` | source 需要更准确到章节/片段 |
| 展示工具轨迹 | 前端已有 `toolTrace`；AI `tools.py` 已生成 trace | trace 写入 DB，便于回放 |
| 历史影响推荐 | 后端已传 `plans/favorites/chat_records` 到 AI | 加入 note、behavior_event、profile_analysis 权重 |
| 保存问答 | 后端已写 `chat_record`、`user_question_analysis` | 补 `chapter_id/model_name/prompt_version/tool_trace` |
| 渠道确认 | `CommercePage` 用户点击后 `/purchase/confirm` | 严格保持 AI 只建议，用户确认才写购买/预约 |

真正护城河是“书籍场景闭环”，不是泛聊。

## 7. RAG 现状与升级

### 7.1 当前 RAG

`ai-service/app/rag.py` 的 `retrieve_chunks` 当前是基于 MySQL `LIKE` 的关键词检索：

```text
query
  -> split words
  -> book_chunk join book
  -> title/tags/chunk_text LIKE
  -> optional book_id scope
  -> limit top_k
```

优点：

- 简单稳定。
- 能直接基于 `book_chunk` 返回 `SourceRef`。
- 已经能限定 `book_id`。

不足：

- 没有向量检索。
- 没有 BM25/全文索引。
- 没有 rerank。
- 没有章节优先级。
- 没有用户笔记/问答历史检索。
- 没有 source compression。

### 7.2 推荐 RAG 应怎么升级

当前推荐上下文已经由 `SmartReadService.buildRecommendContext` 注入：

```text
user_id + query + offset
  -> profile / profile_analysis
  -> plans / favorites / chat_records
  -> candidate_books
  -> retrieved_chunks
  -> ai-service recommend_skill
  -> recommend_record
```

升级重点：

1. `candidate_books` 保持由后端生成，保证推荐书可点击。
2. `retrieved_chunks` 不只按 query 搜，空 query 时按画像和历史行为构造查询。
3. 增加 `note`、`user_behavior_event` 到推荐上下文。
4. 用 `profile_analysis` 里的 inferred interests、difficulty preference、reading stage 影响排序。
5. `recommend_record.result_json` 里保留 `tool_trace`、`llm_status`、`prompt_version`、`model_name`。

### 7.3 伴读 RAG 应怎么升级

当前伴读上下文已经由 `SmartReadService.buildChatContext` 注入：

```text
book_id + question + chapter_id + paragraph
  -> user_profile / profile_analysis
  -> book
  -> chapter
  -> sources = repository.findChunks(retrievalQuery, bookId, 6)
  -> ai-service chat_skill
  -> chat_record + user_question_analysis
```

升级重点：

1. 如果有 `chapter_id`，优先在 `book_chapter.content` 和对应 `book_chunk` 中检索。
2. 如果有 `paragraph`，优先解释 paragraph，再用 book_chunk 补证据。
3. 如果 `sources` 为空，允许 `general_guidance`，但不把通用推理塞进 `sources`。
4. `chat_record` 增加 `chapter_id`、`llm_status`、`tool_trace_json`、`model_name`、`prompt_version`。
5. `user_question_analysis` 已有 `question_type/depth_level/knowledge_gaps/source_count`，应继续完善分类逻辑。

## 8. LangChain / MCP / Skills 怎么落到现有代码

### 8.1 LangChain

当前没有 `langchain` 依赖，不要虚写“已经使用 LangChain”。

建议把现有自研流程逐步迁移为 LangChain 结构：

| 现有模块 | LangChain 对应改造 |
|---|---|
| `intent_router.route_intent` | RunnableLambda / Router |
| `rag.retrieve_chunks` | Retriever |
| `skills.recommend_skill` | recommend chain |
| `skills.chat_skill` | chat chain |
| `output_parser.normalize_*` | PydanticOutputParser / structured output |
| `tools.py` | Tool |
| `mcp_tools.py` | MCP tool adapter |
| `harness.py` | eval runner |

推荐链目标：

```text
input
  -> intent router
  -> backend candidate books
  -> retriever
  -> reranker
  -> prompt
  -> model
  -> parser
  -> guardrails
  -> trace + persistence
```

伴读链目标：

```text
book/question/chapter/paragraph
  -> book scoped retriever
  -> paragraph/chapter priority merge
  -> prompt
  -> model
  -> parser
  -> source validator
  -> chat_record + question_analysis
```

### 8.2 MCP

当前已有：

- `GET /internal/mcp/tools`
- `POST /internal/mcp/call`
- `ai-service/app/mcp_tools.py`

这更像 MCP 工具 facade。下一步可以做两件事：

1. 标准化工具 schema，让外部 MCP Client 能理解。
2. 明确写操作边界：AI 可以生成草稿，业务写库仍由 Spring Boot 后端和用户确认控制。

建议保留的工具：

- `search_books`
- `commerce_search`
- `library_search`
- `create_order_draft`
- `save_note_draft`
- `create_plan_draft`
- `track_event`

禁止 AI 直接做：

- 自动购买
- 自动借阅
- 自动预约
- 自动把草稿写成已确认状态

### 8.3 Skills

当前项目的 Skills 落点是 `ai-service/app/skills.py`，不是独立文件包。

建议下一步拆成可版本化文件：

```text
ai-service/app/skills/
  store_recommend_v1.md
  book_chat_v1.md
  reader_paragraph_chat_v1.md
  source_citation_v1.md
  commerce_decision_v1.md
  fallback_policy_v1.md
```

然后 `skills.py` 只负责加载 skill、组装 payload、调用模型、解析输出。

这样做的好处：

- Prompt 可版本化。
- 答辩可展示 AI 能力包。
- 可以在 `recommend_record/chat_record` 里记录 `prompt_version`。
- Harness 可以对比不同 Skill 版本。

## 9. 数据库建议：不是新增全部，而是补强已有表

已有 schema 已经覆盖大部分闭环。建议优先补字段，不要另造平行表。

### 9.1 `recommend_record`

当前字段：

- `user_id`
- `query`
- `result_json`
- `sources_json`
- `created_at`

建议补：

- `llm_status`
- `tool_trace_json`
- `model_name`
- `prompt_version`
- `candidate_book_ids`
- `retrieval_query`

### 9.2 `chat_record`

当前字段：

- `user_id`
- `book_id`
- `question`
- `answer`
- `sources_json`
- `created_at`

建议补：

- `chapter_id`
- `paragraph_hash`
- `llm_status`
- `tool_trace_json`
- `model_name`
- `prompt_version`
- `retrieval_query`

### 9.3 `note`

当前字段：

- `user_id`
- `book_id`
- `content`
- `type`
- `created_at`

建议补：

- `chapter_id`
- `source_chat_record_id`
- `source_chunk_id`
- `paragraph_index`

### 9.4 `book_chunk`

当前字段：

- `book_id`
- `source`
- `chunk_text`
- `chunk_index`

建议补：

- `chapter_id`
- `embedding_id` 或 `embedding_vector`
- `token_count`
- `chunk_hash`
- `metadata_json`

如果暂时不接向量库，也可以先加 MySQL FULLTEXT 或额外关键词索引。

## 10. 分阶段更新路线

### Phase 1：修正文档和接口认知

目标：全队确认真实项目结构。

- 文档中明确根目录下有 `harmony-app/backend/ai-service/database`。
- API 文档以 `ApiClient.ets` + Controller 为准。
- AI 文档以 `SmartReadService` + `AiGateway` + `ai-service/app/main.py` 为准。

验收：

- 前端同学知道接口来自 Spring Boot。
- 后端同学知道前端流式需要 NDJSON。
- AI 同学知道后端已经注入画像、候选书、历史和 chunks。

### Phase 2：提升现有 RAG 质量

目标：让回答更贴书，而不是只靠 LIKE 命中。

- `retrieve_chunks` 增加章节优先。
- `book_chunk` 加 `chapter_id`。
- 检索加入 `note` 和 `chat_record` 历史。
- 推荐加入 `user_behavior_event` 和 `profile_analysis` 权重。
- 输出 source 时保留章节标题、chunk id、source。

验收：

- 章节内提问优先引用当前章节。
- 回答不再动不动走 `general_guidance`。
- 推荐理由能明显引用用户历史动作。

### Phase 3：工程化 LangChain/MCP/Skills

目标：从自研函数编排升级为可观测、可版本化、可评测。

- 引入 LangChain 或 LangGraph。
- 把 `skills.py` 拆成可版本化 skill 文件。
- MCP tools 标准化 schema。
- `tool_trace` 入库。
- `harness.py` 扩展评测集。

验收：

- 可以回放一次推荐/问答的链路。
- 可以比较不同 prompt_version 的结果。
- 可以统计 JSON 合规率、来源覆盖率、工具成功率。

### Phase 4：产品体验补强

目标：让“越用越懂你”在 App 里可见。

- `ProfileContent` 不只显示数量，还能进入历史列表。
- `ChatPage` 保存笔记时能带来源和章节。
- `ReaderPage` 选段问答自动带 paragraph。
- `CommercePage` 展示 tool_trace 和来源可信度。
- 计划页展示 AI 根据历史生成的下一步建议。

验收：

- 用户能查到问答、笔记、计划、收藏、渠道确认历史。
- 用户能从历史跳回图书、章节或阅读器。
- 推荐确实会因收藏/计划/笔记/问答变化而变化。

## 11. 重点文件改进清单

### HarmonyOS 端

- `entry/src/main/ets/common/ApiClient.ets`
  - 保持接口契约稳定。
  - 可补历史查询方法。
  - 流式事件字段继续对齐后端 NDJSON。

- `entry/src/main/ets/common/AiResponseView.ets`
  - 已支持 sources/toolTrace。
  - 后续可增加来源跳转到章节。

- `entry/src/main/ets/pages/ProfileContent.ets`
  - 从数量提示升级为历史列表入口。

- `entry/src/main/ets/pages/ReaderPage.ets`
  - 让段落 AI 提问明确传 `paragraph` 和 `chapterId`。

### Spring Boot 后端

- `SmartReadService.java`
  - 已完成上下文增强，是闭环核心。
  - 建议继续加入 note、behavior_event、profile_analysis 深度特征。

- `AiGateway.java`
  - 已完成非流式和 NDJSON 流式转发。
  - 建议记录 AI 服务耗时、错误类型、模型状态。

- `SmartReadRepository.java`
  - 已包含 schema 自修复、查询、保存逻辑。
  - 建议补 chat/recommend 的 model/prompt/tool_trace 字段。

- `AnalyticsController.java`
  - 已有 profile rebuild。
  - 建议把分析结果更直接喂回推荐链。

### FastAPI AI 服务

- `skills.py`
  - 当前主编排都在这里。
  - 建议拆分并版本化。

- `rag.py`
  - 当前是关键词 LIKE。
  - 建议升级混合检索、章节优先、历史检索。

- `output_parser.py`
  - 已有 Pydantic 归一化。
  - 建议增加 source validator 和 hallucination guard。

- `mcp_tools.py`
  - 已有工具 facade。
  - 建议标准化为真正 MCP 协议或清晰声明为内部 tool facade。

- `harness.py`
  - 已有评测入口。
  - 建议扩展成答辩可展示的质量评测表。

## 12. 最终验收标准

### 主流程

- 搜索 -> 详情 -> 收藏/计划 -> 阅读器 -> AI 伴读 -> 保存笔记 -> 我的页面历史 可跑通。
- 书城 AI 推荐能流式输出，并返回可点击图书。
- 阅读器 AI 能围绕当前图书/章节/段落回答。
- 渠道页必须用户确认后才写 `purchase_record`。

### 数据闭环

- `recommend_record` 可查推荐结果。
- `chat_record` 可查问答。
- `user_question_analysis` 可查问题类型、深度、来源数量。
- `note` 可查保存的 AI 回答和阅读摘录。
- `reading_plan` 可查计划和进度。
- `user_behavior_event` 可查浏览、搜索、阅读时长等行为。
- `commerce_result` 与 `purchase_record` 可查渠道和确认动作。

### AI 质量

- 有书内证据时返回 `sources`。
- 无证据时返回 `general_guidance` 或 `insufficient_context`，不伪造来源。
- 推荐优先使用数据库真实图书。
- `tool_trace` 能说明候选书、RAG、外部搜索、渠道工具的调用状态。
- 流式 final 必须是完整 JSON。

## 13. 结论

基于真实项目骨架，鸿蒙智阅已经具备端、云、智三侧雏形：

- 前端已经有完整阅读体验和 AI 展示位。
- 后端已经有 Spring Boot API、统一响应、上下文增强、历史写库。
- AI 服务已经有 FastAPI、DeepSeek、RAG、Skills、MCP facade、Parser、Harness。
- 数据库已经有推荐、问答、笔记、计划、收藏、行为、画像分析和渠道确认的核心表。

下一步不是“从零设计 AI 问答”，而是把现有链路做深：

- RAG 从关键词 LIKE 升级到章节优先和混合检索。
- 历史从“能写入”升级到“能影响下一轮推荐和伴读”。
- Skills 从 Python 函数升级到可版本化能力包。
- MCP 从内部 facade 升级到标准化工具协议。
- Harness 从占位评测升级到可展示的质量报告。

这样才是这个项目真正超越普通 AI 问答的路径。
