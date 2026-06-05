import json
import re
from typing import Any, Dict, List

import requests

from .settings import settings


class DeepSeekError(RuntimeError):
    pass


class DeepSeekClient:
    def generate_json(self, messages: List[Dict[str, str]]) -> Dict[str, Any]:
        api_key = _validated_api_key()
        request_json = {
            "model": settings.deepseek_model,
            "messages": messages,
            "temperature": settings.deepseek_temperature,
            "response_format": {"type": "json_object"},
            "max_tokens": settings.deepseek_max_tokens,
        }
        if settings.deepseek_thinking in {"enabled", "disabled"}:
            request_json["thinking"] = {"type": settings.deepseek_thinking}
        try:
            session = requests.Session()
            session.trust_env = settings.deepseek_use_proxy
            response = session.post(
                f"{settings.deepseek_base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=request_json,
                timeout=45,
            )
        except requests.RequestException as exc:
            raise DeepSeekError(f"DeepSeek request failed: {exc}") from exc
        if response.status_code >= 400:
            raise DeepSeekError(f"DeepSeek HTTP {response.status_code}: {response.text[:300]}")
        try:
            body = response.json()
            content = body["choices"][0]["message"]["content"]
        except (KeyError, IndexError, ValueError) as exc:
            raise DeepSeekError(f"DeepSeek response format is invalid: {exc}") from exc
        return _parse_json_content(content)


def _validated_api_key() -> str:
    api_key = settings.deepseek_api_key.strip()
    if not api_key:
        raise DeepSeekError("DEEPSEEK_API_KEY is missing")
    placeholder_markers = ("你的", "DeepSeek Key", "DeepSeek API Key", "your api key", "your deepseek")
    if any(marker.lower() in api_key.lower() for marker in placeholder_markers):
        raise DeepSeekError("DEEPSEEK_API_KEY 仍是示例占位文本，请替换为 DeepSeek 控制台生成的真实 API Key")
    try:
        api_key.encode("ascii")
    except UnicodeEncodeError as exc:
        raise DeepSeekError("DEEPSEEK_API_KEY 包含中文或其他非 ASCII 字符，请填入真实 API Key，通常以 sk- 开头") from exc
    return api_key


def _parse_json_content(content: str) -> Dict[str, Any]:
    try:
        parsed = json.loads(content)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", content, re.S)
        if not match:
            raise DeepSeekError("DeepSeek response is not JSON")
        parsed = json.loads(match.group(0))
    if not isinstance(parsed, dict):
        raise DeepSeekError("DeepSeek response root must be an object")
    return parsed
