---
name: harmony-smartread-loyal-reader-roadmap
description: 从忠实读者视角重构鸿蒙智阅的找书、推荐、伴读、RAG、历史记忆与数据库闭环方案
metadata:
  type: project
---

# 鸿蒙智阅：让读过的人不想回到起点的升级方案

## 1. 先说结论

鸿蒙智阅不该再被做成一个“会回答问题的图书 App”，而要被做成一个“知道你在读什么、为什么读、读到哪、下一步该做什么”的书籍场景智能体。

真正能让用户回不去起点的，不是更会聊天，而是更懂书、更懂人、更懂过程：
- 更懂书：回答必须围绕当前图书、章节、段落和知识片段。
- 更懂人：知道用户专业、年级、目标、预算、收藏、计划、问过什么。
- 更懂过程：把一次问答变成一条可追踪的阅读行为链路。

## 2. 现有代码已经有的底座

从现有代码看，项目不是从零开始：
- `entry/src/main/ets/common/ApiClient.ets` 已经打通搜索、详情、推荐、伴读、计划、收藏、笔记、画像、渠道、行为上报。
- `entry/src/main/ets/common/Models.ets` 已经有 `Book`、`PlanItem`、`NoteItem`、`ChatRecord`、`ProfileBundle`、`ReaderBundle` 这些核心对象。
- `SearchPage.ets`、`BookDetailPage.ets`、`ReaderPage.ets`、`ChatPage.ets`、`PlanContent.ets`、`ProfileContent.ets` 已经形成主链路。
- `ProfileContent.ets` 已经能拿到 `favorites / notes / plans / chat_records`，说明历史闭环的骨架是有的。

但现在还差一层最关键的东西：把这些能力变成“可检索、可回放、可继续生长”的长期记忆。

## 3. 怎么在同类 AI 问答里胜出

别把目标写成“比豆包更会说”，那样会跑偏。目标应该是：

| 维度 | 通用 AI | 鸿蒙智阅应该做到 |
|---|---|---|
| 场景 | 什么都答 | 只围绕找书、读书、提问、计划、笔记、渠道 |
| 证据 | 常识优先 | 项目知识库优先，回答尽量带来源 |
| 记忆 | 单轮为主 | 用户历史、书籍历史、章节历史、行为历史 |
| 行动 | 说完就结束 | 促成收藏、计划、笔记、继续阅读、渠道确认 |
| 稳定性 | 允许泛化 | 不能编书名、作者、章节、来源、库存、适读人群 |

所以真正的竞争力不是“更像聊天”，而是“更像一个懂阅读的长期助理”。

## 4. 需要补的代码能力

### 4.1 前端

需要把“结果展示”升级成“历史与来源展示”：
- `Models.ets` 增加历史查询对象和更细的来源引用字段。
- `ApiClient.ets` 增加历史查询接口，统一 `llm_status` 枚举。
- `ChatPage.ets` 不能只存 `answer`，还要存 `question / sources / chapterId / sourceCount / retrievalQuery / promptVersion`。
- `ReaderPage.ets` 不能只写进度，要把 `chapterId / scrollOffset / highlightedText / comment / sourceRefs` 一起写入。
- `ProfileContent.ets` 不能只展示数量，要展示时间线、搜索、筛选、书籍维度历史。
- `SearchPage.ets` 的本地搜索历史只是起点，应该有服务端历史与推荐词联动。

### 4.2 后端

后端要负责三件事：
- 统一响应和参数校验。
- 把收藏、计划、问答、笔记、行为事件写进数据库。
- 给 AI 服务喂完整上下文，而不是只传一个 `query`。

建议补齐这些历史查询接口：
- `GET /history?userId=&type=&bookId=&q=&page=`
- `GET /history/books/{bookId}`
- `GET /history/questions?userId=&bookId=`
- `GET /history/notes?userId=&bookId=`
- `GET /history/plans?userId=`
- `GET /history/favorites?userId=`

### 4.3 AI 服务

AI 服务不要再是一个“大 Prompt 黑箱”，要拆成可版本化模块：
- `intent_router`
- `retriever`
- `reranker`
- `recommend_chain`
- `chat_chain`
- `summary_chain`
- `tool_agent`
- `output_parser`
- `guardrails`

如果用 LangChain，建议把它当编排层，不当业务层。业务层还是后端，AI 只负责组织上下文、检索、生成和校验。

### 4.4 数据库

收藏、计划、问答、笔记、行为不能只落一张表，而要形成统一历史面：
- 业务表负责事实。
- 历史视图负责查询。
- AI 记录负责追溯。

建议每条 AI 记录都补这些字段：
- `session_id`
- `book_id`
- `chapter_id`
- `retrieval_query`
- `source_chunk_ids`
- `model_name`
- `prompt_version`
- `tool_trace`
- `llm_status`
- `created_at`

## 5. LangChain / Skills 怎么落

项目里应该把“Skills”理解成可版本化的提示词与策略包，而不是一个大而化之的 prompt。

推荐目录：
- `ai-service/skills/recommend_book_v1.md`
- `ai-service/skills/chat_book_v1.md`
- `ai-service/skills/source_citation_v1.md`
- `ai-service/skills/fallback_policy_v1.md`
- `ai-service/skills/history_write_v1.md`

每个 skill 都要写清楚：
- 适用场景
- 输入 schema
- 输出 schema
- 引用规则
- 禁止行为
- 失败降级
- 测试样例

LangChain 侧的推荐链路：

```text
query + user_profile + history
  -> intent_router
  -> hybrid retriever
  -> reranker
  -> skill prompt pack
  -> output_parser
  -> backend persist
  -> frontend render
```

建议用 LangGraph 管状态，尤其是“先检索、再回答、再写库、再确认”的多步流程。

## 6. RAG 应该怎么做

RAG 不要只搜 `book_chunk`，要搜整个项目知识库：
- `book`
- `book_chunk`
- `book_chapter`
- `chat_record`
- `note`
- `reading_plan`
- `favorite`
- `user_question_analysis`
- `user_profile_analysis`
- `user_behavior_event`

检索顺序建议是：
1. 先判断意图。
2. 再按当前书、当前章、当前段落做范围收缩。
3. 再混合关键词检索和语义检索。
4. 再 rerank。
5. 最后做 source compression，输出少而准的证据。

回答必须满足：
- 有证据就引用证据。
- 没证据就明确说资料不足。
- 不补书名，不补章节，不补来源，不补库存，不补适读人群。
- 优先给下一步建议，而不是只给一段答案。

## 7. 历史沉淀怎么做成“可查询记忆”

现在的目标不是“存起来”，而是“以后还能被找出来、拼起来、继续用”。

建议形成一个统一的历史查询层：
- 收藏历史
- 计划历史
- 问答历史
- 笔记历史
- 阅读行为历史
- 渠道确认历史

前端应该提供一个“我的历史”页，至少支持：
- 按书筛选
- 按类型筛选
- 按关键字搜索
- 按时间倒序回放
- 直接跳回对应书、章节、问答、笔记、计划

这样用户才会感觉，系统记得住我，而不是每次都像第一次见面。

## 8. 推荐的阶段节奏

### Phase 1
- 统一历史写库字段。
- 统一 AI 输出 JSON 和 `llm_status`。
- 让收藏、计划、问答、笔记都能查。

### Phase 2
- 上 LangChain/LangGraph 编排。
- 上混合检索、rerank、source compression。
- 上版本化 Skills / Prompt Pack。

### Phase 3
- 做历史驱动推荐。
- 做章节级问答和段落级问答。
- 做行为回写和画像回写。

### Phase 4
- 做“我的历史”页。
- 做书籍知识问答回放。
- 做阅读闭环仪表盘。

## 9. 验收标准

一个真正合格的版本，至少要满足这些条件：
- 搜索 -> 详情 -> 推荐/伴读 -> 阅读 -> 计划/笔记/收藏 -> 历史回放 能跑通。
- 推荐和问答都能说清来源。
- 资料不足时不会胡编。
- 任何写操作都要经用户确认。
- 历史能按书、按问题、按笔记、按计划查回去。
- 下一次推荐和下一次问答，确实会因为历史而更准。

## 10. 这套产品的核心气质

鸿蒙智阅最应该守住的一句话是：

> 我不是在陪你随便聊，我是在陪你把一本书真正读完。

这才是它和通用 AI 最大的分野。
