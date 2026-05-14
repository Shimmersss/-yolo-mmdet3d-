# Worklog

## 2026-05-13

### Dify 接入收尾

- 已将 Spring Boot 后端的 Dify 调用改为配置化：
  - `dify.base-url`
  - `dify.api-key`
  - `dify.workflow-id`
  - `dify.workflow-user-prefix`
- 已把本机覆盖配置写入 `SOFT-rear/src/main/resources/application-local.properties`，后端启动后会直接连接到已发布的 Dify 工作流。
- 前端已改为通过后端统一编排接口调用检测和 Dify，结果继续在检测面板和右侧摘要面板展示。

### 已验证的 Dify 结果

- 控制台可登录。
- 原始 `Drone Perception Pipeline` 工作流存在占位 HTTP 节点，运行时报 `Invalid port: 'PORT'`。
- 已导入并发布可运行版本 `Drone Decision Pipeline DeepSeek`。
- `POST /v1/workflows/run` 已成功返回 `succeeded`，并输出：
  - `validated`
  - `reason`
  - `command`
- 本地前端 `npm run build` 在 Windows 路径环境下仍会遇到 Vite 的 `index.html` 绝对路径问题，属于构建环境问题，不是业务接口问题。
- 后端代码已接入新工作流，但 Maven 本地编译仍受依赖下载网络限制影响，后续需要在可联网环境下再跑一次编译验证。

### 2026-05-13 启动排障结论

- 后端本机 MySQL 连接密码实际可用的是 `root/124142`，数据库本身没有坏。
- IDE 启动失败的真正原因是没有激活 `local` profile，Spring Boot 只读到了默认的 `spring.datasource.password=changeme`。
- 已把 `SOFT-rear/src/main/resources/application.properties` 改为默认启用 `local`，这样本机联调时 `application-local.properties` 会自动生效。
- Dify Service API 已验证可用，`/v1/workflows/<workflow_id>/run` 能返回 `succeeded`，当前剩余问题集中在后端启动配置。

### 2026-05-13 最终联调通过

- 已使用本机 `target/classes` + `.m2` 依赖直接拉起后端，`http://localhost:8080` 正常监听。
- 已拉起前端开发服务器，`http://localhost:3000` 可访问。
- `GET /external/dify/status` 返回 `enabled=true`、`apiKeyConfigured=true`、`workflowIdConfigured=true`。
- `POST /external/dify/chat` 已返回 `succeeded` 的 Dify 结果，说明后端到 Dify 的链路已经打通。

### 2026-05-13 Dify 输入修正

- `media_url` 已避免把超长 `data:` 图片直接送进工作流，改为短引用/文件名/占位符。
- `mission_context` 已做长度裁剪和检测摘要压缩，避免 88 项检测结果把 Dify 输入表单撑爆。
- 后端已重新编译并重启，`POST /external/dify/chat` 复测仍可返回 `succeeded`。

### 2026-05-13 KITTI calib 投影改造

- 前端 MMDet3D 入口已改成左相机图片单入口，并由后端自动匹配同名点云和 `calib.txt`。
- 后端 `/external/dify/drone-pipeline` 已新增 `calibFile` 入参，并会把 `calib_file` 透传给 `8000` 端。
- 后端新增了基于 `P2 / R0_rect / Tr_velo_to_cam` 的本地投影重绘逻辑，优先用 `calib.txt` 重新生成左图投影结果，避免直接信任外部服务返回的可视化图。
- 已修正 LiDAR 3D box 的底面中心约定，避免按几何中心画角点导致投影偏移。
- 本机前端 `npm run build` 仍会碰到 Vite 的绝对路径 `index.html` 问题，属于既有构建环境问题，不是这次 `calib` 改造引入的。
- 后端 `javac` 语法编译已通过；`mvn` 这条线仍受本地 Maven 解析方式影响，后续如需完整构建再按仓库根目录的运行脚本继续走。

### 2026-05-13 KITTI 单图自动匹配

- 结合 `F:\YOLO\kitty\testing` 的实际数据结构，MMDet3D 入口改成单张左相机图片上传。
- 后端会按图片文件名 stem 自动去 `image_2 / velodyne / calib` 三个目录里找同名文件，不再要求前端手动先选样本目录。
- 如果同名 `bin` 或 `calib.txt` 缺失，后端会直接报出具体缺失路径，便于排查数据集一致性问题。

### 2026-05-14 前端打包路径修正

- `web/vite.config.js` 已显式把前端根目录固定到 `web/`，避免从仓库根目录或其他 cwd 启动时，`index.html` 被 Vite 当成绝对路径产物名。
- 前端 `npm run build` 已在 `web/` 目录和仓库根目录两种启动方式下复测通过。

### 2026-05-13 启动脚本修复

- `start-all.ps1` 之前用的是 JDK 17，但当前后端类已按 Java 21 编译，导致脚本启动时 `GlobalExceptionHandler` 类版本不匹配。
- 已将启动脚本里的 `JAVA_HOME` 改回 `C:\Users\Shienroxic\.jdks\openjdk-21.0.2`，和 IDE 运行环境保持一致。

### 后续排障入口

- 如果后端仍返回 `Workflow not published`，先检查 `dify.workflow-id` 是否还是旧值。
- 如果 Dify 返回 `Provider ... does not exist`，先检查工作流节点使用的 provider 是否已在当前工作区启用。
- 如果后端拿不到 Dify 输出，先确认 `application-local.properties` 是否被加载。
## 2026-05-14 后端与投影联调

- `start-all.ps1` 改为优先使用本机安装的 `apache-maven-3.9.12`，并统一走 Java 21 + local profile，避免 Maven wrapper 在当前环境里提前退出。
- 前端 MMDet3D 仍然只上传左相机图像，但会把 `webkitRelativePath` / 文件名作为 `imagePathHint` 传给后端。
- 后端 `/external/dify/drone-pipeline` 新增 `imagePathHint` 透传，`DetectionPipelineService` 也补了递归搜索、父目录 sibling 匹配和兜底回退逻辑。
- 3D 框投影角点改成了与 8000 端一致的中心式定义，避免只改 calib 但几何仍然偏移。
- 新增 `KITTI_projection_algorithm_log.md`，把自动匹配规则、矩阵公式和代码位置整理成后续写论文可直接复用的日志说明。

### 2026-05-14 构建链继续排障

- `start-all.ps1` 现在会显式带上后端的本地 Maven settings，避免脚本启动时又回到默认仓库路径。
- `SOFT-rear/pom.xml` 已重新确认 Spring Boot 3.5.9 父 POM 通过本地副本接入，不再依赖外网解析。
- 继续排查 `mvn clean compile` 时的 Windows/JDK 资源关闭异常，当前现象已经从“依赖找不到”缩小到“编译器关闭 jar 资源时报错”。
- 结论先记为：后端源码层面已能编译到正常阶段，剩余问题更像是本机 JDK / Windows 路径资源关闭行为，而不是业务代码本身。

### 2026-05-14 后端运行确认

- 用户在 IDE 中用 `C:\Users\Shienroxic\.jdks\openjdk-21.0.2` 启动后端成功，Tomcat 已监听 `8080`。
- 日志显示 `application-local.properties` 已生效，`HikariPool` 成功连上 MySQL，说明后端运行链路已经恢复。
- 当前后端问题不再是“起不来”，而是可以继续往前端联调和 Dify 流程验证推进。

### 2026-05-14 启动脚本修正

- `start-all.ps1` 已改为优先使用 IntelliJ 自带的 JBR 17，避免 `openjdk-21.0.2` 在 `spring-boot:run` 时触发编译器资源关闭异常。
- 脚本里的 Maven 启动参数也已清理，去掉了会被 PowerShell 拆坏的 `spring-boot.run.profiles` 传参，改为只依赖 `SPRING_PROFILES_ACTIVE=local`。
- 实测 `spring-boot:run` 在 JBR 17 下可以正常启动，8080 后端链路已经再次确认可用。

### 2026-05-14 KITTI 匹配回滚

- 将 MMDet3D 的 KITTI 自动匹配规则恢复为昨晚那版的宽松逻辑：先按左图 `stem` 找同名图片，再在数据集根目录里递归找对应的 `velodyne/*.bin` 和 `calib/*.txt`。
- 不再强制要求 `bin` 和 `calib` 必须出现在同一个父目录，避免 `Missing sibling KITTI files` 直接卡死。
- 当前保留的投影角点计算仍然是按 8000 服务一致的中心式 3D 框定义，后续如果还偏，再单独拆几何公式继续调。
