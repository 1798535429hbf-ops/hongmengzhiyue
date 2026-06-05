from typing import Any, Dict, List

import requests

from .rag import search_books


def tool_trace(name: str, status: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    return {"tool": name, "tool_name": name, "status": status, "payload": payload}


def search_books_tool(query: str) -> Dict[str, Any]:
    books = search_books(query)
    return {
        "books": books,
        "trace": tool_trace("search_books", "ok", {"query": query, "count": len(books)}),
    }


def external_book_search_tool(query: str, limit: int = 3) -> Dict[str, Any]:
    safe_query = (query or "").strip()
    if not safe_query:
        return {
            "sources": [],
            "trace": tool_trace("external_book_search", "skipped", {"reason": "empty_query"}),
        }
    try:
        response = requests.get(
            "https://openlibrary.org/search.json",
            params={"q": safe_query, "limit": limit},
            timeout=8,
        )
        response.raise_for_status()
        body = response.json()
    except requests.RequestException as exc:
        return {
            "sources": [],
            "trace": tool_trace("external_book_search", "failed", {"query": safe_query, "error": str(exc)[:180]}),
        }
    docs = body.get("docs") or []
    sources: List[Dict[str, Any]] = []
    for index, item in enumerate(docs[:limit]):
        title = str(item.get("title") or "")
        author = ", ".join(item.get("author_name") or [])
        year = item.get("first_publish_year") or ""
        key = str(item.get("key") or "")
        url = f"https://openlibrary.org{key}" if key else "https://openlibrary.org/search"
        text = "；".join(part for part in [
            f"书名：{title}" if title else "",
            f"作者：{author}" if author else "",
            f"首次出版：{year}" if year else "",
        ] if part)
        if text:
            sources.append({
                "chunk_id": None,
                "book_id": None,
                "title": title or "OpenLibrary result",
                "source": url,
                "text": text,
                "chunk_text": text,
                "chunk_index": index,
            })
    return {
        "sources": sources,
        "trace": tool_trace("external_book_search", "ok", {"query": safe_query, "count": len(sources)}),
    }


def commerce_search_tool(book: Dict[str, Any], channels: List[str]) -> Dict[str, Any]:
    isbn = str(book.get("isbn") or "")
    title = str(book.get("title") or "未知图书")
    requested = channels or ["library", "jd", "dangdang", "second_hand"]
    results: List[Dict[str, Any]] = []
    if "library" in requested:
        results.append({
            "platform": "library",
            "price": 0,
            "stock": 3,
            "url": f"https://library.example.edu/search?isbn={isbn}",
            "status": "available",
            "delivery": "校图书馆可预约，预计当日取书",
            "title": title,
            "isbn": isbn,
        })
    if "jd" in requested:
        results.append({
            "platform": "jd",
            "price": 68,
            "stock": 24,
            "url": f"https://search.jd.com/Search?keyword={isbn or title}",
            "status": "in_stock",
            "delivery": "预计 1-2 天送达",
            "title": title,
            "isbn": isbn,
        })
    if "dangdang" in requested:
        results.append({
            "platform": "dangdang",
            "price": 59,
            "stock": 12,
            "url": f"https://search.dangdang.com/?key={isbn or title}",
            "status": "in_stock",
            "delivery": "预计 2-3 天送达",
            "title": title,
            "isbn": isbn,
        })
    if "second_hand" in requested:
        results.append({
            "platform": "campus_second_hand",
            "price": 32,
            "stock": 2,
            "url": f"https://secondhand.example.edu/books?keyword={isbn or title}",
            "status": "limited",
            "delivery": "校内自提",
            "title": title,
            "isbn": isbn,
        })
    return {
        "results": sorted(results, key=lambda item: (float(item["price"]), -int(item["stock"]))),
        "trace": tool_trace("commerce_search", "ok", {"isbn": isbn, "channels": requested}),
    }


def create_order_draft_tool(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "draft": {
            "book_id": payload.get("book_id"),
            "platform": payload.get("platform", "library"),
            "action": payload.get("action", "reserve"),
            "requires_user_confirmation": True,
        },
        "trace": tool_trace("create_order_draft", "ok", {"confirmed": False}),
    }
