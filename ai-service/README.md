# AI/RAG 服务

FastAPI 服务负责 RAG 检索、DeepSeek 调用、工具编排和评测端点。

## 运行

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:DEEPSEEK_API_KEY="sk-替换为你的真实DeepSeekKey"
$env:DEEPSEEK_MODEL="deepseek-v4-pro"
$env:DEEPSEEK_USE_PROXY="false"
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

启动时必须提供真实的 `DEEPSEEK_API_KEY`，不要保留示例占位文本；DeepSeek Key 通常以 `sk-` 开头。默认调用 `deepseek-v4-pro`，也可以通过 `DEEPSEEK_MODEL` 覆盖。默认不读取系统代理；如确实需要代理访问 DeepSeek，可设置 `DEEPSEEK_USE_PROXY=true` 并确保 `HTTP_PROXY` / `HTTPS_PROXY` 可用。推荐与伴读问答只返回 DeepSeek API 生成的结果；如果 DeepSeek 不可用、Key 无效或返回格式不合规，服务会返回 502 错误，不再使用本地写死兜底答案。

## 工具与评测

- `GET /internal/mcp/tools`：查看可用工具清单。
- `POST /internal/mcp/call`：按 `{name, arguments}` 调用工具。
- `POST /internal/eval/run`：返回 Prompt/Eval Harness 检查结果。
