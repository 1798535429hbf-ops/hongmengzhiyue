# 鸿蒙智阅

鸿蒙智阅是一个按 PRD 落地的端云智全栈项目：HarmonyOS ArkTS/ArkUI 前端、Spring Boot 业务后端、Python FastAPI AI/RAG 服务、MySQL 8 数据库。前端不使用 mock 数据，所有核心页面通过 REST API 完成真实查询、AI 推荐、伴读、购书/馆藏聚合和行为回写。

## 目录

- `harmony-app/`：鸿蒙 Stage 模型应用，包名 `com.hakimi.smartread`，显示名“鸿蒙智阅”。
- `backend/`：Spring Boot REST API，统一响应 `{code,message,data}`。
- `ai-service/`：FastAPI AI/RAG 服务，固定 DeepSeek 接入。
- `database/`：MySQL 初始化入口脚本。
- `docs/api.http`：接口联调样例。

## 启动顺序

1. 创建 MySQL 数据库与种子数据：

```powershell
mysql -uroot -p < database/schema.sql
```

如果 MySQL 客户端不支持 `SOURCE` 相对路径，先执行 `CREATE DATABASE hongmeng_zhiyue ...; USE hongmeng_zhiyue;`，再分别导入 `backend/src/main/resources/schema.sql` 和 `backend/src/main/resources/data.sql`。

2. 启动 AI 服务：

```powershell
cd ai-service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:DEEPSEEK_API_KEY="你的 DeepSeek Key"
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

3. 启动后端：

```powershell
cd backend
.\mvnw.cmd spring-boot:run
```

4. 打开鸿蒙端：

用 DevEco Studio 导入 `harmony-app/`，运行 `entry` 模块。默认接口地址在 `entry/src/main/ets/common/ApiClient.ets`：`http://127.0.0.1:8080/api`。真机调试时改为电脑局域网 IP。

## 验收闭环

- 填写“我的画像”，后端写入 `user`。
- 首页输入需求并点击 AI 推荐，后端读取画像和图书数据，AI 服务检索 `book_chunk` 并调用 DeepSeek。
- 推荐结果展示书单、理由、难度和来源片段，后端写入 `recommend_record`。
- 图书详情进入 AI 伴读，保存回答后写入 `chat_record` 和 `note`。
- 查购书/馆藏并确认预约后写入 `commerce_result`、`purchase_record`，同时生成阅读计划。
