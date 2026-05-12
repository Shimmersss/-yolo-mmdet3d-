# 毕设 — YOLO + MMDet3D 图像/点云服务平台

本科毕设仓库，monorepo 组织：Spring Boot 后端 + Vite/Vue 3 前端 + PowerShell 一键启停脚本。前端通过 `/api` 代理到 Spring Boot (`:8080`)，通过 `/mmdet3d` 代理到独立的 MMDet3D 推理服务 (`:8000`)。

## 目录结构

```
毕设/
├── SOFT-rear/              # Spring Boot 3.5 后端（Java 17, Maven）
│   ├── src/main/java/org/soft/softrear/
│   │   ├── controller/     # User / Image / Model / ExternalService
│   │   ├── service/        # IUserService + UserService
│   │   ├── repository/     # Spring Data JPA
│   │   ├── pojo/           # User, DTO, ResponseMessage
│   │   └── handler/        # GlobalExceptionHandler
│   ├── src/main/resources/
│   │   ├── application.properties            # ← 公共配置，使用 ${DB_PASSWORD} 占位
│   │   └── application-local.properties      # ← 本地真值，git 已忽略
│   ├── upload/             # 运行时上传目录（内容已忽略）
│   └── pom.xml
├── web/                    # Vite 6 + Vue 3 + Vue Router 4 前端
│   ├── src/
│   │   ├── api/            # auth.js / image.js / model.js（axios 封装）
│   │   ├── components/     # ImageUpload / ModelChat / LoginForm 等
│   │   ├── views/          # HomeView / LoginView
│   │   ├── router/         # vue-router 配置
│   │   └── utils/axios.js  # 请求拦截器
│   └── vite.config.js      # /api → :8080, /mmdet3d → :8000 代理
├── start-all.ps1           # 同时启动前后端，带端口/HTTP 健康检查
├── stop-all.ps1            # 按 PID / 端口停止
├── status-all.ps1          # 查看运行状态（支持 -Watch）
├── test.py                 # 独立 MNIST 示例脚本（与主服务无关）
└── 前后端启动暂停方法.md    # 手动启停速查
```

## 环境要求

| 组件 | 版本 |
| --- | --- |
| JDK | **17**（项目父 POM 为 Spring Boot 3.5.9，不兼容 Java 8） |
| Node.js | 18+（Vite 6 要求） |
| MySQL | 8.x，数据库名 `VUE` |
| Python | 3.10+（仅当运行 MMDet3D 推理服务时需要） |

## 快速开始

### 1) 数据库

登录 MySQL，创建库：

```sql
CREATE DATABASE VUE DEFAULT CHARACTER SET utf8mb4;
```

Hibernate `ddl-auto=update`，首次启动后端时会自动建表。

### 2) 后端配置

仓库里的 `application.properties` 数据库密码是 **占位符**：

```properties
spring.datasource.username=${DB_USERNAME:root}
spring.datasource.password=${DB_PASSWORD:changeme}
```

两种写法任选其一：

**A. 环境变量（推荐）**

```powershell
$env:DB_USERNAME = "root"
$env:DB_PASSWORD = "你的密码"
```

**B. 本地覆盖文件**

在 `SOFT-rear/src/main/resources/` 下放一个 `application-local.properties`（已被 `.gitignore` 屏蔽）：

```properties
spring.datasource.password=你的密码
```

启动时追加 `--spring.profiles.active=local` 即可生效。

### 3) 一键启动（Windows PowerShell）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\BD\MAVEN\毕设\start-all.ps1"
```

脚本会：

- 用 `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot` 启动 `mvnw.cmd spring-boot:run`
- 用 `C:\Program Files\nodejs\npm.cmd run dev -- --host` 启动前端
- 轮询端口 8080 / 3000 直到健康检查通过
- 把 PID、日志路径写入 `.run/dev-processes.json`

停止：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\BD\MAVEN\毕设\stop-all.ps1"
```

查看状态：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\BD\MAVEN\毕设\status-all.ps1" -Watch -IntervalSec 3
```

> JDK / Node 路径与 `start-all.ps1:14-15` 硬编码。如果你机器上的安装位置不同，改那两行即可。

### 4) 手动启动（速查）

后端：

```powershell
$env:JAVA_HOME="C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
Set-Location "E:\BD\MAVEN\毕设\SOFT-rear"
.\mvnw.cmd spring-boot:run
```

前端：

```powershell
$env:Path="C:\Program Files\nodejs;$env:Path"
Set-Location "E:\BD\MAVEN\毕设\web"
npm install
npm run dev -- --host
```

默认地址：后端 `http://localhost:8080`，前端 `http://localhost:3000`。

更多细节见 [`前后端启动暂停方法.md`](./前后端启动暂停方法.md)。

## 后端 REST API

均以 `http://localhost:8080` 为根。

### 用户 `/user`

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/user` | 新建用户 |
| POST | `/user/login` | 登录 |
| GET | `/user` | 查询用户列表 |
| GET | `/user/{id}` | 按 ID 查询 |
| GET | `/user/name/{userName}` | 按用户名查询 |
| PUT | `/user/find` | 条件查找 |
| DELETE | `/user/{id}` | 按 ID 删除 |
| DELETE | `/user/name/{userName}` | 按用户名删除 |

### 图像 `/image`

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/image/upload` | 图片上传，落到 `SOFT-rear/upload/` |
| POST | `/image/process` | 触发图像处理流程 |

### 模型推理 `/model`

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/model/chat` | 对话类推理 |
| POST | `/model/generate` | 生成类推理 |

### 外部服务代理 `/external`

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/external/python/process-image` | 转发到 Python 侧图像处理服务 |
| POST | `/external/dify/chat` | 转发到 Dify Chat |

## 前端

路由在 `web/src/router/index.js`，两个主视图：

- `LoginView.vue` — 登录页，调用 `api/auth.js`
- `HomeView.vue` — 主工作台，挂载 `ImageUpload.vue` 与 `ModelChat.vue`

Axios 封装在 `src/utils/axios.js`；请求统一走 `/api/**` 前缀，由 Vite 代理到 Spring Boot，避免跨域。

## 常见问题

**`class file version 61` / Java 版本不兼容**
系统默认 Java 是 8。按 [第 4 步手动启动](#4-手动启动速查) 里的 `JAVA_HOME` 写法临时切到 JDK 17。

**`node` 不是内部或外部命令**
当前终端 Path 没有 Node。把 `C:\Program Files\nodejs` 加到 `$env:Path` 再启动。

**前端 `/api` 请求 404**
先确认 `http://localhost:8080/user` 可访问；`vite.config.js` 的代理前缀会被 `rewrite` 掉，后端路径不带 `/api`。

## 许可证

仅作本科毕设提交用途，未附开源许可。
