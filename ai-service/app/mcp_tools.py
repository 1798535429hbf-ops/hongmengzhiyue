from typing import Any, Dict, List

from .db import execute
from .tools import commerce_search_tool, create_order_draft_tool, search_books_tool


TOOL_SPECS: List[Dict[str, Any]] = [
    {
        "name": "search_books",
        "description": "Search project books from MySQL by keyword.",
        "input_schema": {"query": "string"},
    },
    {
        "name": "commerce_search",
        "description": "Aggregate commerce, library, and campus second-hand channels.",
        "input_schema": {"book": "object", "channels": "array"},
    },
    {
        "name": "library_search",
        "description": "Search campus library availability for one book.",
        "input_schema": {"book": "object"},
    },
    {
        "name": "save_note",
        "description": "Persist a reading note after user confirmation.",
        "input_schema": {"user_id": "number", "book_id": "number", "content": "string"},
    },
    {
        "name": "create_plan",
        "description": "Persist a reading plan after user confirmation.",
        "input_schema": {"user_id": "number", "book_id": "number", "target_days": "number"},
    },
    {
        "name": "create_order",
        "description": "Create an order draft that still requires user confirmation.",
        "input_schema": {"user_id": "number", "book_id": "number", "platform": "string", "action": "string"},
    },
]


def list_tools() -> Dict[str, Any]:
    return {"tools": TOOL_SPECS}


def call_tool(name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
    if name == "search_books":
        return search_books_tool(str(arguments.get("query", "")))
    if name == "commerce_search":
        return commerce_search_tool(arguments.get("book") or {}, arguments.get("channels") or [])
    if name == "library_search":
        return commerce_search_tool(arguments.get("book") or {}, ["library"])
    if name == "save_note":
        execute(
            "INSERT INTO note (user_id, book_id, content, type) VALUES (%s, %s, %s, 'ai_answer')",
            [arguments.get("user_id"), arguments.get("book_id"), arguments.get("content", "")],
        )
        return {"status": "ok", "tool_name": name}
    if name == "create_plan":
        execute(
            "INSERT INTO reading_plan (user_id, book_id, target_days, progress, status) VALUES (%s, %s, %s, 0, 'active')",
            [arguments.get("user_id"), arguments.get("book_id"), arguments.get("target_days", 14)],
        )
        return {"status": "ok", "tool_name": name}
    if name == "create_order":
        return create_order_draft_tool(arguments)
    return {"status": "error", "message": f"Unknown tool: {name}"}
