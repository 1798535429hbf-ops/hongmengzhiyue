# 鸿蒙智阅 Agents 指南

## 1. 项目定位与目标用户
鸿蒙智阅是一款面向大学生的 HarmonyOS 智能图书推荐与伴读平台，核心目标是把“找书、读书、提问、做计划、记笔记、看画像、选渠道”串成真实闭环。

项目采用“端-云-智”协作架构：

- 端侧：HarmonyOS Stage + ArkTS + ArkUI，负责页面交互、状态展示、路由跳转和 REST/JSON 调用。
- 云侧：业务后端 + MySQL，负责接口契约、业务编排、数据落库、错误返回和用户行为沉淀。
- 智侧：Python/FastAPI + LangChain，作为独立 AI 编排层，负责意图识别、RAG 检索、Prompt 约束、工具调用、结构化输出和来源追溯。

目标用户是大一至大三学生，尤其是有课程延伸阅读、专业入门学习、竞赛资料查找、考研考证准备需求的人群。产品不做泛化聊天助手，也不做完整图书馆管理系统；所有功能必须围绕“大学生如何找到合适的书，并持续读下去”展开。

## 2. 功能设计总览
核心业务闭环必须保持为：

`搜索图书 -> 图书详情 -> AI 推荐/伴读 -> 阅读器正文 -> 计划/笔记/收藏 -> 渠道检索/确认 -> 画像与历史回写`

主要功能模块：

- 首页：展示推荐入口、最近阅读、状态提示、精选图书和来源依据。
- 搜索页：支持关键词和标签检索图书，结果来自后端真实接口。
- 图书详情页：展示书籍信息、推荐理由、伴读入口、阅读入口、收藏、计划和渠道入口。
- AI 伴读页：围绕当前图书回答问题，展示来源片段，并支持保存为笔记。
- 阅读器页：拉取章节目录、正文内容、来源片段，支持进度回写和摘录笔记。
- 阅读计划页：查看计划、创建计划、更新进度、沉淀阅读状态。
- 我的画像页：编辑用户信息、兴趣、目标、预算、渠道偏好，并展示收藏、笔记、计划和问答历史。
- 购书/渠道页：展示图书馆、电商、二手等渠道结果；预约、购买或加入愿望单必须由用户确认后再回写。

核心业务不得依赖纯前端假数据。空状态、错误提示、骨架屏可以使用提示性占位文案，但搜索结果、推荐结果、伴读回答、正文、计划、笔记、收藏、画像和渠道结果都必须来自真实接口。

## 3. 端-云-智分工
### HarmonyOS 端侧
- 入口在 `entry/src/main/ets/pages/Index.ets`。
- API 调用集中在 `entry/src/main/ets/common/ApiClient.ets`，数据模型集中在 `entry/src/main/ets/common/Models.ets`。
- 默认调试 API 基址优先使用 `http://127.0.0.1:8081/api`，模拟器可使用 `10.0.2.2`，真机调试切换为电脑局域网 IP。
- 前端只做展示、输入、加载态、错误态和用户确认；不得在 ArkTS 中写死核心业务结果。

### 业务后端云侧
- 对 HarmonyOS 前端提供稳定 REST/JSON 接口。
- 负责读取和写入 MySQL 中的用户、图书、知识片段、计划、笔记、收藏、聊天记录、渠道确认等数据。
- 负责参数校验、统一响应包、错误消息可读化、幂等处理和用户行为落库。
- 调用 LangChain 智侧服务时，应保留请求上下文、用户 ID、图书 ID、检索来源和模型状态，便于验收和排错。

### LangChain 智侧
- LangChain 是 AI 编排层，不替代 HarmonyOS 前端，也不替代业务后端。
- 默认采用 Python/FastAPI + LangChain 对外提供智侧接口，业务后端通过 REST/JSON 调用。
- 智侧只基于用户画像、候选图书、数据库知识片段和允许的工具结果生成内容。
- 智侧输出必须经过 JSON 解析和字段校验后再返回后端，不允许把未解析的大模型自然语言直接透传给前端核心页面。

## 4. LangChain 智侧设计
LangChain 模块建议按以下职责拆分：

- `intent_router`：识别用户输入属于找书推荐、图书伴读、章节摘要、计划建议、渠道辅助或资料不足。
- `retriever`：从 `book_chunk`、图书简介、标签、适合人群、章节摘要等知识源中检索 TopK 片段。
- `recommend_chain`：根据用户画像、阅读需求、候选图书和检索片段生成结构化推荐。
- `chat_chain`：围绕指定 `book_id` 和检索片段回答问题，必须返回来源依据。
- `summary_chain`：生成章节摘要、学习重点或复习提示，不能编造原文没有的信息。
- `tool_agent`：按意图调用受控工具，例如 `search_books`、`get_book_detail`、`create_plan`、`save_note`。写操作必须由后端校验用户确认。
- `output_parser`：校验模型 JSON 字段、类型和必填项，失败时返回可读错误或降级结果。
- `guardrails`：限制幻觉、越权、泛聊、无来源回答和自动购买/借阅等高风险行为。

推荐链路：

`query + user_profile -> intent_router -> search candidates -> retriever -> recommend_chain -> output_parser -> backend persistence -> frontend render`

伴读链路：

`book_id + question + user_profile -> retriever(book scope) -> chat_chain -> output_parser -> save chat_record -> frontend render sources`

资料不足时，LangChain 必须明确返回资料不足状态，并给出补充关键词建议；不得用常识或模型记忆补齐书名、作者、章节摘要、适读人群或来源片段。

## 5. 数据对象与接口契约
### 核心数据对象
- `Book`：`id/isbn/title/author/tags/summary/difficulty/targetReader/coverColor`
- `RecommendationBook`：`id/title/author/difficulty/reason`
- `SourceRef`：`chunk_id/book_id/title/source/text`
- `ReadingChapter`：`id/chapterId/bookId/title/order/summary/pageCount/isCurrent`
- `ReadingContent`：`bookId/chapterId/chapterTitle/content/paragraphs/sources/sourceRefs`
- `ReadingProgress`：`planId/bookId/chapterId/progress/scrollOffset/status/updatedAt`
- `PlanItem`：`id/bookId/title/author/targetDays/progress/status/coverColor`
- `NoteItem`：`id/bookId/title/content/type/createdAt`
- `UserProfile`：`id/name/major/grade/interests/goal/budget/channels`
- `CommerceResult`：`platform/price/stock/url/status/delivery/title/isbn`
- `ChatRecord`：`id/bookId/question/answer/createdAt/sourceCount`

### API 约束
业务路径按 `ApiClient.ets` 中的路径书写；实际 HTTP 基址已包含 `/api`。

- 搜索：`GET /books/search?keyword={keyword}&tag={tag}&page=0&size=30`
- 详情：`GET /books/{id}`
- 阅读器聚合：`GET /books/{id}/reader?userId={userId}&chapterId={chapterId}`
- 章节目录：`GET /books/{id}/chapters`
- 章节正文：`GET /books/{id}/content?chapterId={chapterId}`
- 推荐：`POST /ai/recommend`
- 伴读：`POST /ai/chat`
- 创建计划：`POST /plans`
- 查询计划：`GET /plans?userId={userId}`
- 更新进度：`PATCH /plans/{id}`
- 保存笔记：`POST /notes`
- 收藏：`POST /favorites`
- 画像：`GET /users/profile?userId={userId}`、`POST /users/profile`
- 渠道检索：`POST /commerce/search`
- 购书/借阅确认：`POST /purchase/confirm`

所有接口默认使用 JSON，并采用统一响应包：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

错误返回必须可读，前端应能直接展示给用户或测试人员定位问题。

## 6. AI 输出规则
推荐接口 `POST /ai/recommend` 的 `data` 至少包含：

```json
{
  "intent": "recommend",
  "book_list": [
    {
      "id": 1,
      "title": "书名",
      "author": "作者",
      "difficulty": "入门",
      "reason": "推荐理由"
    }
  ],
  "reason": "整体推荐解释",
  "difficulty": "整体难度判断",
  "follow_up_suggestion": "下一步建议",
  "sources": [],
  "llm_status": "ok"
}
```

伴读接口 `POST /ai/chat` 的 `data` 至少包含：

```json
{
  "answer": "围绕当前图书和来源片段生成的回答",
  "sources": [],
  "follow_up_suggestion": "下一步阅读或提问建议",
  "llm_status": "ok"
}
```

AI 行为规则：

- 只能基于用户画像、候选图书、指定图书和检索到的知识片段回答。
- 不得编造书名、作者、章节内容、来源片段、渠道库存或适读人群。
- 推荐和伴读都必须尽量返回 `SourceRef`，前端必须能展示“参考依据”。
- 检索片段不足时，必须明确提示资料不足，并建议补充关键词或更换问题范围。
- AI 不得自动确认购买、借阅、预约或写入计划；所有写操作必须经过业务后端校验和用户动作确认。
- AI 的职责是参与业务闭环，不是泛化闲聊；与图书、阅读、计划、笔记、画像无关的问题应礼貌收束到项目场景。

## 7. 开发协作规则
- 修改功能前先对照 `Models.ets`、`ApiClient.ets` 和本指南，避免字段名、接口名、页面名漂移。
- 新增页面或接口时，必须同步补齐数据对象、错误态、加载态和验收口径。
- 前端不得绕过 `ApiClient.ets` 分散请求逻辑，除非有明确架构原因。
- 后端不得返回前端难以解析的非结构化大段文本作为核心业务结果。
- LangChain Prompt、工具、Parser 和 Guardrails 要版本化管理，方便复现推荐与伴读行为。
- 涉及 MySQL 表、接口字段、AI 输出结构的改动，需要同时考虑前端展示、后端落库、LangChain 输入输出和测试用例。
- 真机和模拟器联调时，优先确认 API 基址、网络权限、后端端口和统一响应包，再排查页面逻辑。

## 8. 验收标准
主流程验收：

- 搜索 -> 详情 -> AI 推荐/伴读 -> 阅读正文 -> 保存计划/笔记/收藏 -> 画像回写 可完整跑通。
- 推荐结果和伴读回答都来自真实后端与 LangChain/RAG 链路，不依赖前端静态假数据。
- 推荐结果和伴读回答能展示来源片段；资料不足时能给出明确提示。
- 阅读器能拉取章节、正文和来源，并能回写进度或保存摘录笔记。
- 计划、笔记、收藏、聊天记录、画像修改和渠道确认都能在后端数据库中查询到。
- 关键字段与前后端模型一致，不出现接口名、字段名、页面名漂移。
- 模拟器、本机和真机调试路径都能连接到正确后端地址。

AI/LangChain 验收：

- `intent_router` 能区分推荐、伴读、摘要、计划建议、渠道辅助和资料不足。
- `retriever` 返回的片段能追溯到 `book_chunk` 或等价知识源。
- `output_parser` 能拦截非 JSON、缺字段或类型错误的模型输出。
- `guardrails` 能阻止无来源编造、泛聊扩散和未经确认的写操作。
- `llm_status` 能反映成功、资料不足、解析失败、模型失败等状态。

本指南是项目协作和代码变更的优先约束。若 PRD、接口实现或前端模型发生变化，应及时更新本文件，确保端、云、智三侧继续对齐。
