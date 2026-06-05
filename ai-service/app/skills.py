import json
from typing import Any, Dict, List

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
        return {
            "intent": "recommend",
            "book_list": [],
            "reason": "书库里暂时没有足够匹配的候选书，不能为了回答而编造书名。",
            "difficulty": "资料不足",
            "follow_up_suggestion": "可以换成更具体的关键词，例如“考研英语写作”“数学一基础”或“人工智能入门”。",
            "sources": _sources(chunks),
            "tool_trace": trace,
            "llm_status": "insufficient_context",
        }
    messages = [
        {"role": "system", "content": (
            "你是像朋友一样说话的大学生阅读顾问。必须输出标准 JSON，不得编造不存在的书籍；"
            "推荐书必须只来自 candidate_books，不能新增 id、书名或作者；"
            "先理解用户当下问题，再结合 reading_history、favorites、plans、chat_records 做个性化排序；"
            "不要使用‘用户画像’‘基于画像’这类机械措辞，要自然说明为什么此刻适合读这些书；"
            "若资料不足，llm_status 使用 insufficient_context 并明确说明。"
            "输出字段必须包含 intent, book_list, reason, difficulty, follow_up_suggestion, sources, llm_status。"
            "book_list 每项包含 id,title,author,difficulty,reason，reason 要短而具体。"
            "只返回 JSON object，例如 {\"intent\":\"recommend\",\"book_list\":[],\"reason\":\"\",\"difficulty\":\"\",\"follow_up_suggestion\":\"\",\"sources\":[],\"llm_status\":\"ok\"}。"
        )},
        {"role": "user", "content": json.dumps({
            "intent": intent,
            "user_profile": profile,
            "query": query,
            "candidate_books": candidate_books,
            "retrieved_chunks": chunks,
            "reading_history": payload.get("reading_history") or [],
            "favorites": payload.get("favorites") or [],
            "plans": payload.get("plans") or [],
            "chat_records": payload.get("chat_records") or [],
        }, ensure_ascii=False)},
    ]
    raw = client.generate_json(messages)
    result = normalize_recommend(raw, candidate_books=candidate_books, sources=chunks, tool_trace=trace)
    result.setdefault("intent", "recommend")
    return result


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
    if not chunks:
        return {
            "answer": "这本书目前没有足够的来源片段，我不能用常识替它补内容。",
            "sources": [],
            "follow_up_suggestion": "可以先导入章节内容，或把问题限定到已有章节摘要。",
            "tool_trace": trace,
            "llm_status": "insufficient_context",
        }
    messages = [
        {"role": "system", "content": (
            "你是陪大学生读书的 AI 伴读，语气要像耐心、灵动的同伴，温和但不油腻。"
            "回答必须贴合 retrieved_chunks、book、chapter 和 paragraph；不能编造章节原文、人物关系、库存或书中没有的结论。"
            "如果来源来自外部检索，只能作为资料不足时的补充，并要提醒用户回到书内来源核对。"
            "不要用公式化的“首先、其次、最后”堆叠；可以有一点情绪和鼓励，但每个判断都要能追溯到来源。"
            "输出 JSON 字段 answer, sources, follow_up_suggestion, llm_status。"
            "只返回 JSON object，例如 {\"answer\":\"\",\"sources\":[],\"follow_up_suggestion\":\"\",\"llm_status\":\"ok\"}。"
        )},
        {"role": "user", "content": json.dumps({
            "question": question,
            "paragraph": paragraph,
            "retrieved_chunks": chunks,
            "book": payload.get("book"),
            "chapter": payload.get("chapter"),
            "tone": payload.get("tone") or "warm_companion",
            "user_profile": payload.get("user_profile") or {},
        }, ensure_ascii=False)},
    ]
    raw = client.generate_json(messages)
    result = normalize_chat(raw, sources=chunks, tool_trace=trace)
    return result


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
