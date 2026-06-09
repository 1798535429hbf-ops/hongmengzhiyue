import json
import logging
from typing import Any, Dict, Iterator

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pymysql import MySQLError

from .db import query_all
from .deepseek_client import DeepSeekError
from .harness import run_eval
from .mcp_tools import call_tool, list_tools
from .settings import settings
from .skills import chat_skill, chat_stream, commerce_skill, recommend_skill, recommend_stream

app = FastAPI(title="鸿蒙智阅 AI/RAG Service", version="1.0.0")
logger = logging.getLogger("hongmeng_zhiyue.ai")


@app.on_event("startup")
def require_deepseek_key() -> None:
    settings.require_runtime()


@app.get("/health")
def health() -> Dict[str, str]:
    return {
        "service": "hongmeng-zhiyue-ai",
        "status": "UP",
        "model": settings.deepseek_model,
        "temperature": str(settings.deepseek_temperature),
        "thinking": settings.deepseek_thinking,
        "use_proxy": str(settings.deepseek_use_proxy).lower(),
    }


@app.get("/health/db")
def database_health() -> Dict[str, Any]:
    try:
        rows = query_all("SELECT DATABASE() AS database_name, 1 AS ok")
    except MySQLError as exc:
        logger.error("AI service database check failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"AI 服务数据库连接失败：{exc}") from exc
    row = rows[0] if rows else {}
    return {
        "service": "hongmeng-zhiyue-ai",
        "status": "UP",
        "database": row.get("database_name", settings.mysql_database),
    }


@app.post("/internal/rag/recommend")
def recommend(payload: Dict[str, Any]) -> Dict[str, Any]:
    try:
        return recommend_skill(payload)
    except MySQLError as exc:
        logger.error("AI recommend database failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"AI 服务数据库连接失败：{exc}") from exc
    except DeepSeekError as exc:
        logger.error("DeepSeek recommend failed: %s", exc)
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("AI recommend failed")
        raise HTTPException(status_code=500, detail=f"AI 推荐内部错误：{exc}") from exc


@app.post("/internal/rag/recommend/stream")
def recommend_stream_endpoint(payload: Dict[str, Any]) -> StreamingResponse:
    return StreamingResponse(
        _ndjson_events(recommend_stream(payload), "AI recommend stream failed"),
        media_type="application/x-ndjson",
    )


@app.post("/internal/rag/chat")
def chat(payload: Dict[str, Any]) -> Dict[str, Any]:
    try:
        return chat_skill(payload)
    except MySQLError as exc:
        logger.error("AI chat database failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"AI 服务数据库连接失败：{exc}") from exc
    except DeepSeekError as exc:
        logger.error("DeepSeek chat failed: %s", exc)
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("AI chat failed")
        raise HTTPException(status_code=500, detail=f"AI 伴读内部错误：{exc}") from exc


@app.post("/internal/rag/chat/stream")
def chat_stream_endpoint(payload: Dict[str, Any]) -> StreamingResponse:
    return StreamingResponse(
        _ndjson_events(chat_stream(payload), "AI chat stream failed"),
        media_type="application/x-ndjson",
    )


@app.post("/internal/tools/commerce-search")
def commerce_search(payload: Dict[str, Any]) -> Dict[str, Any]:
    return commerce_skill(payload)


@app.get("/internal/mcp/tools")
def mcp_tools() -> Dict[str, Any]:
    return list_tools()


@app.post("/internal/mcp/call")
def mcp_call(payload: Dict[str, Any]) -> Dict[str, Any]:
    return call_tool(str(payload.get("name", "")), payload.get("arguments") or {})


@app.post("/internal/eval/run")
def eval_run() -> Dict[str, Any]:
    return run_eval()


def _ndjson_events(events: Iterator[Dict[str, Any]], log_prefix: str) -> Iterator[str]:
    try:
        for event in events:
            yield json.dumps(event, ensure_ascii=False) + "\n"
    except MySQLError as exc:
        logger.error("%s database failed: %s", log_prefix, exc)
        yield json.dumps({"type": "error", "message": f"AI 服务数据库连接失败：{exc}"}, ensure_ascii=False) + "\n"
    except DeepSeekError as exc:
        logger.error("%s DeepSeek failed: %s", log_prefix, exc)
        yield json.dumps({"type": "error", "message": str(exc)}, ensure_ascii=False) + "\n"
    except Exception as exc:
        logger.exception(log_prefix)
        yield json.dumps({"type": "error", "message": f"AI 流式内部错误：{exc}"}, ensure_ascii=False) + "\n"
