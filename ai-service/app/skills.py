import json
from typing import Any, Dict, Iterator, List

from .deepseek_client import DeepSeekClient
from .intent_router import route_intent
from .output_parser import normalize_chat, normalize_recommend
from .rag import retrieve_chunks
from .tools import commerce_search_tool, external_book_search_tool, search_books_tool, tool_trace

client = DeepSeekClient()


def recommend_skill(payload: Dict[str, Any]) -> Dict[str, Any]:
    query = str(payload.get("query") or "")
    profile = payload.get("user_profile") or {}
    intent = route_intent(query)
    trace: List[Dict[str, Any]] = []
    plans = payload.get("plans") or []
    favorites = payload.get("favorites") or []
    chat_records = payload.get("chat_records") or []
    reading_history = payload.get("reading_history") or []
    profile_analysis = payload.get("profile_analysis") or {}
    fallback_strategy = str(payload.get("fallback_strategy") or "")
    fallback_reason = str(payload.get("fallback_reason") or "")

    if query.strip() and intent in {"smalltalk", "clarify", "interest_analysis", "chat"}:
        analysis = _reader_context_answer(
            query=query,
            intent=intent,
            profile=profile,
            profile_analysis=profile_analysis,
            reading_history=reading_history,
            favorites=favorites,
            plans=plans,
            chat_records=chat_records,
        )
        analysis["tool_trace"] = [tool_trace("reader_context", "ok", {
            "intent": intent,
            "favorites": len(favorites),
            "plans": len(plans),
            "chat_records": len(chat_records),
        })]
        return analysis

    candidate_books = payload.get("candidate_books") or []
    if candidate_books:
        trace.append(tool_trace("candidate_books", "ok", {"source": "backend", "count": len(candidate_books)}))
    else:
        tool_result = search_books_tool(query or _profile_query(profile))
        candidate_books = tool_result["books"]
        trace.append(tool_result["trace"])
    chunks = payload.get("retrieved_chunks") or retrieve_chunks(query or _profile_query(profile), limit=8)
    trace.append(tool_trace("rag_retrieve", "ok", {"query": query, "top_k": len(chunks)}))
    if not candidate_books:
        return _title_only_recommendation(
            query=query or _profile_query(profile),
            chunks=chunks,
            trace=trace,
            allow_external=bool(payload.get("allow_external_search", False)),
        )
    messages = _recommend_messages(
        intent=intent,
        profile=profile,
        query=query,
        candidate_books=candidate_books,
        chunks=chunks,
        profile_analysis=profile_analysis,
        reading_history=reading_history,
        favorites=favorites,
        plans=plans,
        chat_records=chat_records,
        fallback_strategy=fallback_strategy,
        fallback_reason=fallback_reason,
    )
    raw = client.generate_json(messages)
    result = normalize_recommend(raw, candidate_books=candidate_books, sources=chunks, tool_trace=trace)
    result.setdefault("intent", "recommend")
    return result


def recommend_stream(payload: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    query = str(payload.get("query") or "")
    profile = payload.get("user_profile") or {}
    intent = route_intent(query)
    plans = payload.get("plans") or []
    favorites = payload.get("favorites") or []
    chat_records = payload.get("chat_records") or []
    reading_history = payload.get("reading_history") or []
    profile_analysis = payload.get("profile_analysis") or {}

    if query.strip() and intent in {"smalltalk", "clarify", "interest_analysis", "chat"}:
        trace = [tool_trace("reader_context", "ok", {
            "intent": intent,
            "favorites": len(favorites),
            "plans": len(plans),
            "chat_records": len(chat_records),
        })]
        yield {"type": "status", "message": "正在分析你的阅读上下文"}
        messages = _reader_context_messages(
            query=query,
            intent=intent,
            profile=profile,
            profile_analysis=profile_analysis,
            reading_history=reading_history,
            favorites=favorites,
            plans=plans,
            chat_records=chat_records,
        )
        final_emitted = False
        for event in client.stream_json_field(messages, "reason"):
            if event.get("type") == "raw_final":
                raw = event.get("data") or {}
                result = normalize_recommend(raw, candidate_books=[], sources=[], tool_trace=trace)
                result["intent"] = str(result.get("intent") or intent or "clarify")
                result["book_list"] = []
                result["llm_status"] = str(result.get("llm_status") or "context_analysis")
                yield {"type": "final", "data": result}
                final_emitted = True
            else:
                yield event
        if not final_emitted:
            result = _reader_context_answer(
                query=query,
                intent=intent,
                profile=profile,
                profile_analysis=profile_analysis,
                reading_history=reading_history,
                favorites=favorites,
                plans=plans,
                chat_records=chat_records,
            )
            result["tool_trace"] = trace
            yield {"type": "final", "data": result}
        return

    trace: List[Dict[str, Any]] = []
    fallback_strategy = str(payload.get("fallback_strategy") or "")
    fallback_reason = str(payload.get("fallback_reason") or "")
    candidate_books = payload.get("candidate_books") or []
    if candidate_books:
        trace.append(tool_trace("candidate_books", "ok", {"source": "backend", "count": len(candidate_books)}))
    else:
        tool_result = search_books_tool(query or _profile_query(profile))
        candidate_books = tool_result["books"]
        trace.append(tool_result["trace"])
    chunks = payload.get("retrieved_chunks") or retrieve_chunks(query or _profile_query(profile), limit=8)
    trace.append(tool_trace("rag_retrieve", "ok", {"query": query, "top_k": len(chunks)}))
    if not candidate_books:
        result = _title_only_recommendation(
            query=query or _profile_query(profile),
            chunks=chunks,
            trace=trace,
            allow_external=bool(payload.get("allow_external_search", False)),
        )
        yield {"type": "delta", "delta": result["reason"]}
        yield {"type": "final", "data": result}
        return

    messages = _recommend_messages(
        intent=intent,
        profile=profile,
        query=query,
        candidate_books=candidate_books,
        chunks=chunks,
        profile_analysis=profile_analysis,
        reading_history=reading_history,
        favorites=favorites,
        plans=plans,
        chat_records=chat_records,
        fallback_strategy=fallback_strategy,
        fallback_reason=fallback_reason,
    )
    yield {"type": "status", "message": "正在从书库候选里判断更适合你的书"}
    final_emitted = False
    for event in client.stream_json_field(messages, "reason"):
        if event.get("type") == "raw_final":
            raw = event.get("data") or {}
            result = normalize_recommend(raw, candidate_books=candidate_books, sources=chunks, tool_trace=trace)
            result.setdefault("intent", "recommend")
            yield {"type": "final", "data": result}
            final_emitted = True
        else:
            yield event
    if not final_emitted:
        result = recommend_skill(payload)
        yield {"type": "final", "data": result}


def chat_skill(payload: Dict[str, Any]) -> Dict[str, Any]:
    question = str(payload.get("question") or "")
    paragraph = str(payload.get("paragraph") or "")
    book_id = _optional_int(payload.get("book_id"))
    retrieval_query = f"{question} {paragraph}".strip()
    chunks = payload.get("sources") or retrieve_chunks(retrieval_query or question, book_id=book_id, limit=6)
    trace = [tool_trace("rag_retrieve", "ok", {"book_id": book_id, "top_k": len(chunks)})]
    if not chunks:
        allow_external = bool(payload.get("allow_external_search", False))
        if allow_external:
            external = external_book_search_tool(retrieval_query or question, limit=3)
            trace.append(external["trace"])
            chunks = external["sources"]
        if chunks:
            trace.append(tool_trace("external_context", "used", {"reason": "insufficient_rag"}))
    has_grounded_sources = bool(chunks)
    if not chunks:
        trace.append(tool_trace("deepseek_reasoning", "used", {"reason": "no_retrievable_sources"}))
        chunks = [{
            "chunk_id": None,
            "book_id": book_id,
            "title": "DeepSeek general guidance",
            "source": "DeepSeek reasoning",
            "chunk_text": (
                "No retrievable book source is available. Provide general reading or learning guidance, "
                "clearly label it as general guidance, and do not invent book-specific facts, chapter text, "
                "quotes, characters, inventory, or source claims."
            ),
            "text": (
                "No retrievable book source is available. Provide general reading or learning guidance, "
                "clearly label it as general guidance, and do not invent book-specific facts."
            ),
            "chunk_index": 0,
        }]
    messages = _chat_messages(
        question=question,
        paragraph=paragraph,
        chunks=chunks,
        payload=payload,
        has_grounded_sources=has_grounded_sources,
    )
    raw = client.generate_json(messages)
    result = normalize_chat(raw, sources=chunks if has_grounded_sources else [], tool_trace=trace)
    if not has_grounded_sources:
        result["sources"] = []
        result["llm_status"] = result.get("llm_status") or "general_guidance"
        if result["llm_status"] == "ok":
            result["llm_status"] = "general_guidance"
    return result


def chat_stream(payload: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    question = str(payload.get("question") or "")
    paragraph = str(payload.get("paragraph") or "")
    book_id = _optional_int(payload.get("book_id"))
    retrieval_query = f"{question} {paragraph}".strip()
    chunks = payload.get("sources") or retrieve_chunks(retrieval_query or question, book_id=book_id, limit=6)
    trace = [tool_trace("rag_retrieve", "ok", {"book_id": book_id, "top_k": len(chunks)})]
    if not chunks:
        allow_external = bool(payload.get("allow_external_search", False))
        if allow_external:
            external = external_book_search_tool(retrieval_query or question, limit=3)
            trace.append(external["trace"])
            chunks = external["sources"]
        if chunks:
            trace.append(tool_trace("external_context", "used", {"reason": "insufficient_rag"}))
    has_grounded_sources = bool(chunks)
    if not chunks:
        trace.append(tool_trace("deepseek_reasoning", "used", {"reason": "no_retrievable_sources"}))
        chunks = [{
            "chunk_id": None,
            "book_id": book_id,
            "title": "DeepSeek general guidance",
            "source": "DeepSeek reasoning",
            "chunk_text": (
                "No retrievable book source is available. Provide general reading or learning guidance, "
                "clearly label it as general guidance, and do not invent book-specific facts, chapter text, "
                "quotes, characters, inventory, or source claims."
            ),
            "text": (
                "No retrievable book source is available. Provide general reading or learning guidance, "
                "clearly label it as general guidance, and do not invent book-specific facts."
            ),
            "chunk_index": 0,
        }]

    messages = _chat_messages(
        question=question,
        paragraph=paragraph,
        chunks=chunks,
        payload=payload,
        has_grounded_sources=has_grounded_sources,
    )
    yield {"type": "status", "message": "正在贴着当前图书线索生成导读"}
    final_emitted = False
    for event in client.stream_json_field(messages, "answer"):
        if event.get("type") == "raw_final":
            raw = event.get("data") or {}
            result = normalize_chat(raw, sources=chunks if has_grounded_sources else [], tool_trace=trace)
            if not has_grounded_sources:
                result["sources"] = []
                result["llm_status"] = result.get("llm_status") or "general_guidance"
                if result["llm_status"] == "ok":
                    result["llm_status"] = "general_guidance"
            yield {"type": "final", "data": result}
            final_emitted = True
        else:
            yield event
    if not final_emitted:
        result = chat_skill(payload)
        yield {"type": "final", "data": result}


def commerce_skill(payload: Dict[str, Any]) -> Dict[str, Any]:
    book = payload.get("book") or {"isbn": payload.get("isbn", ""), "title": payload.get("title", "未知图书")}
    channels = payload.get("channels") or ["library", "jd", "dangdang", "second_hand"]
    tool_result = commerce_search_tool(book, channels)
    return {
        "intent": "commerce_search",
        "results": tool_result["results"],
        "tool_trace": [tool_result["trace"]],
        "message": "已聚合馆藏、电商和校园二手书来源，购买或借阅仍需用户点击确认。",
    }


def _sources(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [{
        "chunk_id": chunk.get("chunk_id"),
        "book_id": chunk.get("book_id"),
        "title": chunk.get("title"),
        "source": chunk.get("source"),
        "text": chunk.get("chunk_text") or chunk.get("text", ""),
    } for chunk in chunks]


def _title_only_recommendation(
    *,
    query: str,
    chunks: List[Dict[str, Any]],
    trace: List[Dict[str, Any]],
    allow_external: bool,
) -> Dict[str, Any]:
    book_list: List[Dict[str, Any]] = []
    next_trace = list(trace)
    if allow_external:
        external = external_book_search_tool(query or "大学生 阅读 推荐", limit=6)
        next_trace.append(external["trace"])
        seen_titles = set()
        for source in external.get("sources", []):
            title = str(source.get("title") or "").strip()
            if not title or title in seen_titles:
                continue
            seen_titles.add(title)
            book_list.append({
                "id": 0,
                "title": title,
                "titleOnly": True,
            })
    if book_list:
        reason = "书库暂时没有可打开详情的候选，我先只列出可继续检索的书名。"
        status = "title_only"
    else:
        reason = "这次后端没有给到可推荐的候选书，我先不硬凑书单。"
        status = "insufficient_context"
    return {
        "intent": "recommend",
        "book_list": book_list,
        "reason": reason,
        "difficulty": "待确认" if book_list else "资料不足",
        "follow_up_suggestion": "",
        "sources": [] if book_list else _sources(chunks),
        "tool_trace": next_trace,
        "llm_status": status,
        "response_mode": "final_with_collapsed_reasoning",
    }


def _optional_int(value: Any):
    try:
        number = int(value)
    except (TypeError, ValueError):
        return None
    return number if number > 0 else None


def _profile_query(profile: Dict[str, Any]) -> str:
    return " ".join([
        str(profile.get("major") or ""),
        str(profile.get("interests") or ""),
        str(profile.get("goal") or ""),
    ]).strip()


def _recommend_messages(
    *,
    intent: str,
    profile: Dict[str, Any],
    query: str,
    candidate_books: List[Dict[str, Any]],
    chunks: List[Dict[str, Any]],
    profile_analysis: Dict[str, Any],
    reading_history: List[Dict[str, Any]],
    favorites: List[Dict[str, Any]],
    plans: List[Dict[str, Any]],
    chat_records: List[Dict[str, Any]],
    fallback_strategy: str,
    fallback_reason: str,
) -> List[Dict[str, str]]:
    return [
        {"role": "system", "content": (
            "你是大学生身边会挑书的同伴，像熟悉课程、备考和兴趣阅读节奏的学长学姐。"
            "先听懂用户这句话真正想解决什么，再从 candidate_books 里挑书和排序；不要新增候选外的书。"
            "说话要落在具体书上：适合谁、为什么现在读、先读哪一段或用什么节奏读。"
            "避免官腔和验收口吻，不要写“用户画像”“基于画像”“可追溯来源”“不能编造”这类规则说明。"
            "如果 fallback_strategy 是 top_rated_fallback，要坦白说个性化线索不够稳定，所以先按书库评分和阅读热度挑；"
            "这种情况下不要假装分析出了细腻偏好，也不要要求用户继续补充偏好才能得到书。"
            "reason 像一句真人推荐，不要只说“贴近方向”“主题相关”；follow_up_suggestion 给一个小而可做的下一步。"
            "返回给前端的内容仍是 JSON：intent, book_list, reason, difficulty, follow_up_suggestion, sources, llm_status；"
            "book_list 每项包含 id,title,author,difficulty,reason。只返回 JSON object。"
        )},
        {"role": "user", "content": json.dumps({
            "intent": intent,
            "user_profile": profile,
            "query": query,
            "candidate_books": candidate_books,
            "retrieved_chunks": chunks,
            "profile_analysis": profile_analysis,
            "reading_history": reading_history,
            "favorites": favorites,
            "plans": plans,
            "chat_records": chat_records,
            "fallback_strategy": fallback_strategy,
            "fallback_reason": fallback_reason,
        }, ensure_ascii=False)},
    ]


def _chat_messages(
    *,
    question: str,
    paragraph: str,
    chunks: List[Dict[str, Any]],
    payload: Dict[str, Any],
    has_grounded_sources: bool,
) -> List[Dict[str, str]]:
    companion_policy = (
        "Answer like a warm reading companion, not a policy checker. "
        "Book-specific facts must come from retrieved_chunks, book, chapter, or paragraph. "
        "Use general reasoning for explanation, analogies, reading advice, and concept connections. "
        "When book evidence is missing, give general guidance without pretending it came from the book, keep sources empty, and set llm_status to general_guidance. "
        "Return only JSON with answer, sources, follow_up_suggestion, and llm_status."
    )
    return [
        {"role": "system", "content": companion_policy},
        {"role": "system", "content": (
            "你是陪大学生读书的伴读，像坐在旁边帮他把书读顺的人：先回应问题，再把关键点讲清，最后给一个很小的下一步。"
            "有书内片段时，多引用片段里的具体概念、章节线索或矛盾点；没有书内片段时，就坦白这是一般阅读建议。"
            "不要用“首先、其次、最后”堆列表，也不要反复说“资料不足”“可追溯”“不能编造”。"
            "语气可以轻一点、有一点判断，但别油腻；少讲流程，多帮用户真的读懂或选下一步。"
            "输出 JSON 字段 answer, sources, follow_up_suggestion, llm_status。只返回 JSON object。"
        )},
        {"role": "user", "content": json.dumps({
            "question": question,
            "paragraph": paragraph,
            "retrieved_chunks": chunks,
            "book": payload.get("book"),
            "chapter": payload.get("chapter"),
            "tone": payload.get("tone") or "warm_companion",
            "reasoning_policy": payload.get("reasoning_policy") or "grounded_sources_plus_deepseek_reasoning",
            "answer_scope": payload.get("answer_scope") or "",
            "has_grounded_sources": has_grounded_sources,
            "user_profile": payload.get("user_profile") or {},
        }, ensure_ascii=False)},
    ]


def _reader_context_messages(
    *,
    query: str,
    intent: str,
    profile: Dict[str, Any],
    profile_analysis: Dict[str, Any],
    reading_history: List[Dict[str, Any]],
    favorites: List[Dict[str, Any]],
    plans: List[Dict[str, Any]],
    chat_records: List[Dict[str, Any]],
) -> List[Dict[str, str]]:
    return [
        {"role": "system", "content": (
            "你是鸿蒙智阅里的阅读分析顾问。先基于用户画像、收藏、计划、问答历史和阅读记录理解用户，"
            "再回答用户当前这句话。不要条件反射推荐书；只有用户明确要找书、挑书、制定书单时才给 book_list。"
            "如果用户只是打招呼，要简短回应并引导他说学习目标、最近卡住的问题或想读的感觉。"
            "如果用户问阅读兴趣或问题分析，要从本地上下文提炼倾向：主题、难度、学习目标、最近关注点、下一步建议。"
            "语气像懂学习节奏的同伴，有判断、有具体观察，不要说空话。"
            "返回 JSON：intent, book_list, reason, difficulty, follow_up_suggestion, sources, llm_status。"
        )},
        {"role": "user", "content": json.dumps({
            "intent": intent,
            "query": query,
            "user_profile": profile,
            "profile_analysis": profile_analysis,
            "reading_history": reading_history[:8],
            "favorites": favorites[:8],
            "plans": plans[:8],
            "chat_records": chat_records[:10],
        }, ensure_ascii=False)},
    ]


def _reader_context_answer(
    *,
    query: str,
    intent: str,
    profile: Dict[str, Any],
    profile_analysis: Dict[str, Any],
    reading_history: List[Dict[str, Any]],
    favorites: List[Dict[str, Any]],
    plans: List[Dict[str, Any]],
    chat_records: List[Dict[str, Any]],
) -> Dict[str, Any]:
    messages = _reader_context_messages(
        query=query,
        intent=intent,
        profile=profile,
        profile_analysis=profile_analysis,
        reading_history=reading_history,
        favorites=favorites,
        plans=plans,
        chat_records=chat_records,
    )
    try:
        raw = client.generate_json(messages)
    except Exception:
        raw = {}
    reason = str(raw.get("reason") or "").strip()
    follow = str(raw.get("follow_up_suggestion") or "").strip()
    returned_intent = str(raw.get("intent") or intent or "clarify")
    if not reason:
        reason = _local_context_fallback(query, intent, profile, favorites, plans, chat_records)
    if not follow:
        follow = ""
    return {
        "intent": returned_intent,
        "book_list": [],
        "reason": reason,
        "difficulty": str(raw.get("difficulty") or ""),
        "follow_up_suggestion": follow,
        "sources": [],
        "llm_status": str(raw.get("llm_status") or "context_analysis"),
    }


def _local_context_fallback(
    query: str,
    intent: str,
    profile: Dict[str, Any],
    favorites: List[Dict[str, Any]],
    plans: List[Dict[str, Any]],
    chat_records: List[Dict[str, Any]],
) -> str:
    if intent == "smalltalk":
        return "你好，我在。你可以直接说最近想解决什么阅读问题：找入门书、备考资料、课程延伸，或者把一个概念丢给我分析。"
    topics = _context_topics(profile, favorites, plans, chat_records)
    if topics:
        return f"从你留下的阅读线索看，你最近更偏向 {topics}。我可以继续帮你判断适合轻松读、系统学，还是围绕考试目标补资料。"
    if query:
        return "我还没抓到明确的阅读目标。你可以说得更像真实需求一点，比如“我想入门人工智能但数学一般”，我就能结合你的画像和历史问题来分析。"
    return "我可以根据你的画像、收藏、计划和提问记录分析阅读兴趣，也能继续帮你挑书。"


def _context_topics(
    profile: Dict[str, Any],
    favorites: List[Dict[str, Any]],
    plans: List[Dict[str, Any]],
    chat_records: List[Dict[str, Any]],
) -> str:
    values: List[str] = []
    for key in ("interests", "goal", "major"):
        value = str(profile.get(key) or "").strip()
        if value:
            values.append(value)
    for item in favorites[:3] + plans[:3]:
        title = str(item.get("title") or "").strip()
        if title:
            values.append(f"《{title}》")
    for record in chat_records[:3]:
        question = str(record.get("question") or "").strip()
        if question:
            values.append(question[:18])
    compact: List[str] = []
    for value in values:
        if value and value not in compact:
            compact.append(value)
    return "、".join(compact[:5])
