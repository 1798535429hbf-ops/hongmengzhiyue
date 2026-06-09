import json
import re
from typing import Any, Dict, Iterator, List

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

    def stream_json_field(self, messages: List[Dict[str, str]], visible_field: str) -> Iterator[Dict[str, Any]]:
        api_key = _validated_api_key()
        request_json = {
            "model": settings.deepseek_model,
            "messages": messages,
            "temperature": settings.deepseek_temperature,
            "response_format": {"type": "json_object"},
            "max_tokens": settings.deepseek_max_tokens,
            "stream": True,
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
                timeout=60,
                stream=True,
            )
        except requests.RequestException as exc:
            raise DeepSeekError(f"DeepSeek request failed: {exc}") from exc
        if response.status_code >= 400:
            raise DeepSeekError(f"DeepSeek HTTP {response.status_code}: {response.text[:300]}")

        content = ""
        reasoning = ""
        field_streamer = _JsonFieldStreamer(visible_field)
        try:
            for raw_line in response.iter_lines(decode_unicode=True):
                if not raw_line:
                    continue
                line = raw_line.strip()
                if line.startswith("data:"):
                    line = line[5:].strip()
                if line == "[DONE]":
                    break
                try:
                    body = json.loads(line)
                    delta = body["choices"][0].get("delta") or {}
                except (KeyError, IndexError, ValueError, TypeError):
                    continue
                reasoning_delta = str(delta.get("reasoning_content") or "")
                content_delta = str(delta.get("content") or "")
                if reasoning_delta:
                    reasoning += reasoning_delta
                    yield {"type": "reasoning", "delta": reasoning_delta}
                if content_delta:
                    content += content_delta
                    visible_delta = field_streamer.feed(content_delta)
                    if visible_delta:
                        yield {"type": "delta", "delta": visible_delta}
        finally:
            response.close()
        parsed = _parse_json_content(content)
        if reasoning:
            parsed.setdefault("hidden_reasoning", reasoning)
            parsed.setdefault("reasoning_content", reasoning)
        yield {"type": "raw_final", "data": parsed}


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


class _JsonFieldStreamer:
    def __init__(self, field_name: str) -> None:
        self.field_name = field_name
        self.buffer = ""
        self.emitted = ""

    def feed(self, chunk: str) -> str:
        self.buffer += chunk
        visible = self._extract_prefix()
        if len(visible) <= len(self.emitted):
            return ""
        delta = visible[len(self.emitted):]
        self.emitted = visible
        return delta

    def _extract_prefix(self) -> str:
        start = self._field_value_start()
        if start < 0:
            return ""
        raw_value = self._string_prefix(start)
        if raw_value == "":
            return ""
        return self._decode_prefix(raw_value)

    def _field_value_start(self) -> int:
        pattern = f'"{self.field_name}"'
        key_index = self.buffer.find(pattern)
        if key_index < 0:
            return -1
        colon_index = self.buffer.find(":", key_index + len(pattern))
        if colon_index < 0:
            return -1
        quote_index = self.buffer.find('"', colon_index + 1)
        return quote_index + 1 if quote_index >= 0 else -1

    def _string_prefix(self, start: int) -> str:
        escaped = False
        value_chars: List[str] = []
        for ch in self.buffer[start:]:
            if escaped:
                value_chars.append(ch)
                escaped = False
                continue
            if ch == "\\":
                value_chars.append(ch)
                escaped = True
                continue
            if ch == '"':
                break
            value_chars.append(ch)
        return "".join(value_chars)

    def _decode_prefix(self, raw_value: str) -> str:
        candidate = raw_value
        while candidate:
            try:
                return json.loads(f'"{candidate}"')
            except json.JSONDecodeError:
                candidate = candidate[:-1]
        return ""
