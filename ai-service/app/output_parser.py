from __future__ import annotations

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, ValidationError


class RecommendationBookModel(BaseModel):
    id: int = 0
    title: str
    author: str = ""
    difficulty: str = ""
    reason: str = ""
    highlight: str = ""
    coverColor: str = ""
    subtitle: str = ""
    titleOnly: bool = False


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
    reasoning: str = ""
    reasoning_content: str = ""
    hidden_reasoning: str = ""
    stream_id: str = ""
    response_mode: str = "final_with_collapsed_reasoning"
    llm_status: str = "deepseek"


class ChatOutput(BaseModel):
    answer: str = ""
    sources: List[SourceRefModel] = Field(default_factory=list)
    follow_up_suggestion: str = ""
    tool_trace: List[Dict[str, Any]] = Field(default_factory=list)
    reasoning: str = ""
    reasoning_content: str = ""
    hidden_reasoning: str = ""
    stream_id: str = ""
    response_mode: str = "final_with_collapsed_reasoning"
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
        output.book_list = [book for book in output.book_list if book.id in allowed_ids or book.titleOnly]
    if not output.sources:
        output.sources = [SourceRefModel.model_validate(source) for source in _source_refs(sources)]
    output.tool_trace = output.tool_trace or tool_trace
    _copy_reasoning(raw, output)
    if (not output.book_list or _weak_text(output.reason) or _terse_text(output.reason)) and candidate_books:
        output = _recommend_from_candidates(candidate_books, sources)
        output.tool_trace = tool_trace
        _copy_reasoning(raw, output)
    return output.model_dump()


def normalize_chat(raw: Dict[str, Any], *, sources: List[Dict[str, Any]], tool_trace: List[Dict[str, Any]]) -> Dict[str, Any]:
    parsed_from_model = True
    try:
        output = ChatOutput.model_validate(raw)
    except ValidationError:
        parsed_from_model = False
        output = _chat_from_sources(sources)
    if not output.sources:
        output.sources = [SourceRefModel.model_validate(source) for source in _source_refs(sources)]
    output.tool_trace = output.tool_trace or tool_trace
    _copy_reasoning(raw, output)

    # Do not replace every source-less DeepSeek answer with the same fixed
    # "no retrievable text" fallback. Keep valid general guidance, and only
    # recover when the model failed to produce useful answer text.
    has_grounded_sources = bool(sources)
    answer = (output.answer or "").strip()
    reasoning_text = (output.hidden_reasoning or output.reasoning_content or output.reasoning or "").strip()
    needs_recovery = not parsed_from_model or not answer
    if has_grounded_sources and (_weak_text(answer) or _too_short_answer(answer) or _terse_text(answer)) and not reasoning_text:
        needs_recovery = True
    if needs_recovery:
        output = _chat_from_sources(sources)
        output.tool_trace = tool_trace
        _copy_reasoning(raw, output)
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
        reason = _book_reason(book, summary)
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
        follow_up_suggestion="先点开第一本看目录和简介；如果难度不对，再换下一本。",
        sources=[SourceRefModel.model_validate(source) for source in _source_refs(sources)],
        llm_status="recovered" if books else "insufficient_context",
    )


def _chat_from_sources(sources: List[Dict[str, Any]]) -> ChatOutput:
    refs = [SourceRefModel.model_validate(source) for source in _source_refs(sources)]
    if not refs:
        return ChatOutput(
            answer="当前没有可追溯的正文片段，我不把它硬编成书内结论。你可以先看目录、章节标题和摘要，再把问题缩到某一章或某个概念。",
            follow_up_suggestion="先补一段章节片段，或者把问题缩到具体章节。",
            llm_status="general_guidance",
        )
    evidence = " ".join(ref.text for ref in refs[:2] if ref.text)
    if len(evidence) > 260:
        evidence = evidence[:260] + "..."
    return ChatOutput(
        answer=(
            f"这段里最值得先抓的是：{evidence} "
            "我会先把它当成章节的核心线索，而不是零散信息。你可以顺着这些词去看作者怎么定义问题、"
            "怎么举例、最后把结论落在哪里；这样读完以后更容易形成自己的笔记。"
        ),
        sources=refs,
        follow_up_suggestion="可以把这段整理成一条笔记，标题就写最反复出现的那个概念。",
        llm_status="recovered",
    )


def _recommend_lead(books: List[RecommendationBookModel]) -> str:
    if not books:
        return "这次书库里没有匹配到足够合适的书，我先不硬凑书单。"
    first = books[0]
    if len(books) == 1:
        return f"可以先从《{first.title}》开读。{first.reason or '它比较适合先试一章，判断自己能不能读进去。'}"
    second = books[1]
    return (
        f"我会先把《{first.title}》放在前面，{first.reason or '它更适合拿来打开这个方向'}；"
        f"《{second.title}》可以排第二，{second.reason or '它能帮你从另一个角度补一块理解'}。"
    )


def _book_reason(book: Dict[str, Any], summary: str) -> str:
    rating = str(book.get("rating") or "").strip()
    rating_count = str(book.get("ratingCount") or book.get("rating_count") or "").strip()
    parts: List[str] = []
    if rating and rating != "0":
        score = f"书库评分 {rating}"
        if rating_count and rating_count != "0":
            score += f"，{rating_count} 人评分"
        parts.append(score)
    if summary:
        parts.append(summary[:64] + ("..." if len(summary) > 64 else ""))
    if not parts:
        parts.append("这本可以先试读一章，看看难度和你的节奏合不合拍。")
    return "；".join(parts)


def _weak_text(text: str) -> bool:
    value = (text or "").strip()
    if not value:
        return True
    weak_markers = ("已拦截", "结构不完整", "未校验", "换个关键词", "无法解析", "parser", "格式不稳定", "资料不足")
    return any(marker in value for marker in weak_markers)


def _too_short_answer(text: str) -> bool:
    value = (text or "").strip()
    return 0 < len(value) < 36


def _terse_text(text: str) -> bool:
    value = (text or "").strip()
    if not value:
        return True
    sentence_marks = 0
    for ch in value:
      if ch in "。！？!?":
        sentence_marks += 1
    if sentence_marks >= 2:
        return False
    return len(value) < 120


def _copy_reasoning(raw: Dict[str, Any], output: RecommendOutput | ChatOutput) -> None:
    reasoning = str(
        raw.get("hidden_reasoning")
        or raw.get("reasoning_content")
        or raw.get("reasoning")
        or ""
    )
    if reasoning:
        output.hidden_reasoning = reasoning
        output.reasoning_content = reasoning
        output.reasoning = reasoning
    stream_id = str(raw.get("stream_id") or "")
    if stream_id:
        output.stream_id = stream_id
    response_mode = str(raw.get("response_mode") or "")
    if response_mode:
        output.response_mode = response_mode
