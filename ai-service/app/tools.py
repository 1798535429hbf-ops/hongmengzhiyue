from typing import Any, Dict, List

from .rag import search_books


def tool_trace(name: str, status: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    return {"tool": name, "tool_name": name, "status": status, "payload": payload}


def search_books_tool(query: str) -> Dict[str, Any]:
    books = search_books(query)
    return {
        "books": books,
        "trace": tool_trace("search_books", "ok", {"query": query, "count": len(books)}),
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
