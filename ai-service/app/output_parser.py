from __future__ import annotations

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, ValidationError


class RecommendationBookModel(BaseModel):
    id: int
    title: str
    author: str = ""
    difficulty: str = ""
    reason: str = ""


class SourceRefModel(BaseModel):
    chunk_id: Optional[int] = None
    book_id: Optional[int] = None
    title: str = ""
    source: str = ""
    text: str = ""


class RecommendOutput(BaseModel):
    intent: str = "recommend"
    book_list: List[RecommendationBookModel] = Field(default_factory=list)
    reason: str = ""
    difficulty: str = ""
    follow_up_suggestion: str = ""
    sources: List[SourceRefModel] = Field(default_factory=list)
    tool_trace: List[Dict[str, Any]] = Field(default_factory=list)
    llm_status: str = "deepseek"


class ChatOutput(BaseModel):
    answer: str = ""
    sources: List[SourceRefModel] = Field(default_factory=list)
    follow_up_suggestion: str = ""
    tool_trace: List[Dict[str, Any]] = Field(default_factory=list)
    llm_status: str = "deepseek"


def normalize_recommend(
    raw: Dict[str, Any],
    *,
    candidate_books: List[Dict[str, Any]],
    sources: List[Dict[str, Any]],
    tool_trace: List[Dict[str, Any]],
) -> Dict[str, Any]:
    try:
        output = RecommendOutput.model_validate(raw)
    except ValidationError:
        output = _recommend_from_candidates(candidate_books, sources)
    allowed_ids = {int(book.get("id")) for book in candidate_books if book.get("id") is not None}
    if allowed_ids:
        output.book_list = [book for book in output.book_list if book.id in allowed_ids]
    if not output.sources:
        output.sources = [SourceRefModel.model_validate(source) for source in _source_refs(sources)]
    output.tool_trace = output.tool_trace or tool_trace
    if not output.book_list and candidate_books:
        output = _recommend_from_candidates(candidate_books, sources)
    return output.model_dump()


def normalize_chat(raw: Dict[str, Any], *, sources: List[Dict[str, Any]], tool_trace: List[Dict[str, Any]]) -> Dict[str, Any]:
    try:
        output = ChatOutput.model_validate(raw)
    except ValidationError:
        output = _chat_from_sources(sources)
    if not output.sources:
        output.sources = [SourceRefModel.model_validate(source) for source in _source_refs(sources)]
    output.tool_trace = output.tool_trace or tool_trace
    if not output.answer or "已拦截" in output.answer or "结构不完整" in output.answer:
        output = _chat_from_sources(sources)
        output.tool_trace = tool_trace
    return output.model_dump()


def _source_refs(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    refs: List[Dict[str, Any]] = []
    for chunk in chunks:
        refs.append({
            "chunk_id": chunk.get("chunk_id"),
            "book_id": chunk.get("book_id"),
            "title": chunk.get("title", ""),
            "source": chunk.get("source", ""),
            "text": chunk.get("chunk_text") or chunk.get("text", ""),
        })
    return refs


def _recommend_from_candidates(candidate_books: List[Dict[str, Any]], sources: List[Dict[str, Any]]) -> RecommendOutput:
    books: List[RecommendationBookModel] = []
    for book in candidate_books[:6]:
        title = str(book.get("title") or "")
        if not title:
            continue
        summary = str(book.get("summary") or book.get("reason") or "")
        reason = summary[:76] + ("..." if len(summary) > 76 else "")
        if not reason:
            reason = "这本书来自真实候选书库，主题和当前阅读需求接近，可以继续进入详情、阅读或伴读。"
        books.append(RecommendationBookModel(
            id=int(book.get("id") or 0),
            title=title,
            author=str(book.get("author") or ""),
            difficulty=str(book.get("difficulty") or ""),
            reason=reason,
        ))
    lead = _recommend_lead(books)
    return RecommendOutput(
        intent="recommend",
        book_list=books,
        reason=lead,
        difficulty=books[0].difficulty if books else "资料不足",
        follow_up_suggestion="可以继续补充专业、考试目标、想读难度或阅读时间，我会把书单收窄到更贴合的几本。",
        sources=[SourceRefModel.model_validate(source) for source in _source_refs(sources)],
        llm_status="recovered" if books else "insufficient_context",
    )


def _chat_from_sources(sources: List[Dict[str, Any]]) -> ChatOutput:
    refs = [SourceRefModel.model_validate(source) for source in _source_refs(sources)]
    if not refs:
        return ChatOutput(
            answer="这本书目前没有足够的来源片段，我不会用常识替它补内容。",
            follow_up_suggestion="请先导入章节或把问题限定到已有章节摘要。",
            llm_status="insufficient_context",
        )
    evidence = " ".join(ref.text for ref in refs[:2] if ref.text)
    if len(evidence) > 260:
        evidence = evidence[:260] + "..."
    return ChatOutput(
        answer=f"我先看这本书里已经能追溯到的片段：{evidence} 所以这次建议你先抓住片段中反复出现的概念、人物或问题，再回到对应章节核对细节。",
        sources=refs,
        follow_up_suggestion="如果你把问题缩小到某一章、某个概念或一段摘录，我可以给出更精确的伴读解释。",
        llm_status="recovered",
    )


def _recommend_lead(books: List[RecommendationBookModel]) -> str:
    if not books:
        return "这次书库里没有匹配到足够合适的书，我先不硬凑书单。"
    first = books[0]
    if len(books) == 1:
        return f"我推荐先读《{first.title}》。{first.reason or '它和你现在的阅读方向比较贴近，适合先点进详情看一眼。'}"
    second = books[1]
    return (
        f"我推荐先读《{first.title}》，理由是{first.reason or '它最贴近你现在的阅读方向'}；"
        f"再把《{second.title}》作为对照，理由是{second.reason or '它能补上另一个角度'}。"
    )
