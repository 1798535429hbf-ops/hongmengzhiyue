import json
from typing import Any, Dict, List

from .deepseek_client import DeepSeekClient
from .rag import retrieve_chunks
from .tools import commerce_search_tool, search_books_tool, tool_trace

client = DeepSeekClient()


def recommend_skill(payload: Dict[str, Any]) -> Dict[str, Any]:
    query = str(payload.get("query") or "")
    profile = payload.get("user_profile") or {}
    candidate_books = payload.get("candidate_books") or search_books_tool(query)["books"]
    chunks = retrieve_chunks(query, limit=6)
    trace = [tool_trace("rag_retrieve", "ok", {"query": query, "top_k": len(chunks)})]
    messages = [
        {"role": "system", "content": (
            "你是大学生阅读顾问。必须输出标准 JSON，不得编造不存在的书籍；"
            "若资料不足，明确说明资料不足。字段包含 intent, book_list, reason, difficulty, "
            "follow_up_suggestion。book_list 每项包含 id,title,author,difficulty,reason。"
        )},
        {"role": "user", "content": json.dumps({
            "user_profile": profile,
            "query": query,
            "candidate_books": candidate_books,
            "retrieved_chunks": chunks,
        }, ensure_ascii=False)},
    ]
    result = client.generate_json(messages)
    result["llm_status"] = "deepseek"
    result.setdefault("intent", "recommend")
    result.setdefault("sources", _sources(chunks))
    result.setdefault("tool_trace", trace)
    return result


def chat_skill(payload: Dict[str, Any]) -> Dict[str, Any]:
    question = str(payload.get("question") or "")
    book_id = _optional_int(payload.get("book_id"))
    chunks = retrieve_chunks(question, book_id=book_id, limit=5)
    trace = [tool_trace("rag_retrieve", "ok", {"book_id": book_id, "top_k": len(chunks)})]
    messages = [
        {"role": "system", "content": (
            "你是围绕图书知识库回答的 AI 伴读助手。回答必须贴合来源片段，"
            "输出 JSON 字段 answer, sources, follow_up_suggestion。"
        )},
        {"role": "user", "content": json.dumps({
            "question": question,
            "retrieved_chunks": chunks,
            "book": payload.get("book"),
        }, ensure_ascii=False)},
    ]
    result = client.generate_json(messages)
    result["llm_status"] = "deepseek"
    result.setdefault("sources", _sources(chunks))
    result.setdefault("tool_trace", trace)
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
        "text": chunk.get("chunk_text"),
    } for chunk in chunks]


def _optional_int(value: Any):
    try:
        number = int(value)
    except (TypeError, ValueError):
        return None
    return number if number > 0 else None
