import logging
from typing import Any, Dict

from fastapi import FastAPI, HTTPException
from pymysql import MySQLError

from .db import query_all
from .deepseek_client import DeepSeekError
from .harness import run_eval
from .mcp_tools import call_tool, list_tools
from .settings import settings
from .skills import chat_skill, commerce_skill, recommend_skill

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
