# 鸿蒙智阅

鸿蒙智阅是一个按 PRD 落地的端云智全栈项目：HarmonyOS ArkTS/ArkUI 前端、Spring Boot 业务后端、Python FastAPI AI/RAG 服务、MySQL 8 数据库。前端不使用 mock 数据，所有核心页面通过 REST API 完成真实查询、AI 推荐、伴读、购书/馆藏聚合和行为回写。

## 目录

- `harmony-app/`：鸿蒙 Stage 模型应用，包名 `com.hakimi.smartread`，显示名"鸿蒙智阅"。
- `backend/`：Spring Boot REST API，统一响应 `{code,message,data}`。
- `ai-service/`：FastAPI AI/RAG 服务，固定 DeepSeek 接入。
- `database/`：MySQL 初始化入口脚本。
- `docs/api.http`：接口联调样例。
- `docker-compose.yml`：一键启动 MySQL + 后端 + AI 服务。

---

## 方式一：Docker Compose 一键启动（推荐）

**不需要安装 Java、Python、MySQL。** 只需要 Docker Desktop。

首次使用前确认 Docker Desktop 状态栏图标显示 "Engine running"（绿色）。如果没有：
- 从开始菜单启动 "Docker Desktop"
- 等待右下角系统托盘图标变绿

### 首次启动

```powershell
# 1. 配置 API Key
copy .env.example .env
notepad .env    # 改 DEEPSEEK_API_KEY=sk-xxxxx

# 2. 一键启动（首次会下载镜像，需要几分钟）
docker compose up -d

# 3. 等待就绪后检查
docker compose ps
# 三个服务状态都是 "running" 即为成功
```

### 日常使用

```powershell
docker compose up -d              # 启动
docker compose logs -f            # 查看日志
docker compose logs ai-service    # 只看某个服务的日志
docker compose down               # 停止

# 5. 停止
docker compose down
```

启动后：
- 后端 API：http://localhost:8081
- AI 服务：http://localhost:8001
- MySQL：localhost:3306

**这不需要本地安装 Java、Python 或 MySQL**，只要装好 Docker Desktop 即可。

---

## 方式二：本地手动启动

### 环境要求

- Java 17+
- Python 3.12+
- MySQL 8.0+
- DevEco Studio（仅鸿蒙前端需要）

### 1. 创建 MySQL 数据库与种子数据

```powershell
mysql -uroot -p < database/schema.sql
```

如果 MySQL 客户端不支持 `SOURCE` 相对路径，先执行 `CREATE DATABASE hongmeng_zhiyue ...; USE hongmeng_zhiyue;`，再分别导入 `backend/src/main/resources/schema.sql` 和 `backend/src/main/resources/data.sql`。

### 2. 启动 AI 服务

```powershell
cd ai-service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:DEEPSEEK_API_KEY="你的 DeepSeek Key"
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

### 3. 启动后端

```powershell
cd backend
.\mvnw.cmd spring-boot:run
```

### 4. 打开鸿蒙端

用 DevEco Studio 导入 `harmony-app/`，运行 `entry` 模块。默认接口地址在 `entry/src/main/ets/common/ApiClient.ets`：`http://127.0.0.1:8081/api`。真机调试时改为电脑局域网 IP。

---

## 验收闭环

- 填写"我的画像"，后端写入 `user`。
- 首页输入需求并点击 AI 推荐，后端读取画像和图书数据，AI 服务检索 `book_chunk` 并调用 DeepSeek。
- 推荐结果展示书单、理由、难度和来源片段，后端写入 `recommend_record`。
- 图书详情进入 AI 伴读，保存回答后写入 `chat_record` 和 `note`。
- 查购书/馆藏并确认预约后写入 `commerce_result`、`purchase_record`，同时生成阅读计划。

## 数据规模

种子数据包含 **50 本图书** 和 **100 个 RAG 知识片段**，覆盖计算机科学、数学、英语/考研、文学、经济管理和理工设计六大类别。
