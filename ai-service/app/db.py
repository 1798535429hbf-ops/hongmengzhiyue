from contextlib import contextmanager
from typing import Any, Dict, Iterable, List, Optional

import pymysql
from pymysql.cursors import DictCursor

from .settings import settings


@contextmanager
def connection():
    conn = pymysql.connect(
        host=settings.mysql_host,
        port=settings.mysql_port,
        user=settings.mysql_user,
        password=settings.mysql_password,
        database=settings.mysql_database,
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=True,
    )
    try:
        yield conn
    finally:
        conn.close()


def query_all(sql: str, params: Optional[Iterable[Any]] = None) -> List[Dict[str, Any]]:
    with connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, tuple(params or ()))
            return list(cursor.fetchall())


def execute(sql: str, params: Optional[Iterable[Any]] = None) -> int:
    with connection() as conn:
        with conn.cursor() as cursor:
            return cursor.execute(sql, tuple(params or ()))
