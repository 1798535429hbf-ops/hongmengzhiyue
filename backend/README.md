# 后端服务

Spring Boot 服务负责 REST API、MySQL 持久化和 AI 服务转发。

## 运行

```powershell
.\mvnw.cmd spring-boot:run
```

默认环境变量：

- `MYSQL_URL=jdbc:mysql://localhost:3306/hongmeng_zhiyue?...`
- `MYSQL_USER=root`
- `MYSQL_PASSWORD=`
- `AI_SERVICE_BASE_URL=http://localhost:8001`

接口统一返回：

```json
{"code":0,"message":"ok","data":{}}
```
