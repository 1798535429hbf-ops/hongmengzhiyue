# 同组开发一键启动说明

## 首次准备

1. 安装 Docker Desktop，并确认 Docker Engine 已启动。
2. 从 GitHub clone 本仓库。
3. 双击 `start.bat`，或在 PowerShell 中运行：

```powershell
.\start.ps1
```

首次运行时脚本会自动从 `.env.example` 创建 `.env`，并提示填写 `DEEPSEEK_API_KEY`。密钥只保存在本机 `.env`，不要提交到 GitHub。

## 启动内容

脚本会通过 Docker Compose 启动三项服务：

- MySQL 8：`localhost:3306`
- Spring Boot 后端：`http://localhost:8081/api`
- FastAPI AI 服务：`http://localhost:8001`

数据库初始化来自：

- `backend/src/main/resources/schema.sql`
- `backend/src/main/resources/data.sql`

这两份 SQL 会在新的 MySQL volume 第一次创建时自动执行，用来同步基础表结构、图书数据和 RAG 知识片段。

## 常用命令

```powershell
.\start.ps1             # 启动或更新服务
.\start.ps1 -Logs       # 启动后持续查看日志
.\start.ps1 -ResetDb    # 删除旧数据库 volume 并重新导入初始化数据
docker compose logs -f  # 查看全部服务日志
docker compose down     # 停止服务
```

注意：`-ResetDb` 会清空本机 Docker 里的开发数据库，只适合需要重置为仓库初始化数据时使用。
