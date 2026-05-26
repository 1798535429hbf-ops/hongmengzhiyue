from typing import Any, Dict, List, Optional

from .db import query_all


def retrieve_chunks(query: str, book_id: Optional[int] = None, limit: int = 5) -> List[Dict[str, Any]]:
    words = [word.strip() for word in query.replace("，", " ").replace(",", " ").split() if word.strip()]
    like = f"%{query.strip()}%" if query.strip() else "%"
    params: List[Any] = []
    sql = """
        SELECT c.id AS chunk_id, c.book_id, b.title, b.author, c.source, c.chunk_text, c.chunk_index,
               b.difficulty, b.tags, b.target_reader
        FROM book_chunk c
        JOIN book b ON b.id = c.book_id
        WHERE 1=1
    """
    if book_id:
        sql += " AND c.book_id = %s"
        params.append(book_id)
    if words:
        clauses = []
        for word in words[:4]:
            clauses.append("(b.title LIKE %s OR b.tags LIKE %s OR c.chunk_text LIKE %s)")
            pattern = f"%{word}%"
            params.extend([pattern, pattern, pattern])
        sql += " AND (" + " OR ".join(clauses) + ")"
    else:
        sql += " AND (b.title LIKE %s OR b.tags LIKE %s OR c.chunk_text LIKE %s)"
        params.extend([like, like, like])
    sql += " ORDER BY c.book_id, c.chunk_index LIMIT %s"
    params.append(limit)
    rows = query_all(sql, params)
    if rows:
        return rows
    return query_all("""
        SELECT c.id AS chunk_id, c.book_id, b.title, b.author, c.source, c.chunk_text, c.chunk_index,
               b.difficulty, b.tags, b.target_reader
        FROM book_chunk c
        JOIN book b ON b.id = c.book_id
        ORDER BY c.book_id, c.chunk_index
        LIMIT %s
    """, [limit])


def search_books(query: str, limit: int = 8) -> List[Dict[str, Any]]:
    pattern = f"%{query}%"
    return query_all("""
        SELECT id, isbn, title, author, tags, summary, difficulty,
               target_reader AS targetReader, cover_color AS coverColor
        FROM book
        WHERE title LIKE %s OR author LIKE %s OR tags LIKE %s OR summary LIKE %s
        ORDER BY id
        LIMIT %s
    """, [pattern, pattern, pattern, pattern, limit])
