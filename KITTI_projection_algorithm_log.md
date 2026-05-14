# KITTI 投影与自动匹配算法日志

## 1. 当前目标

项目中的 MMDet3D 联调入口以“左相机图像”为主要输入。用户在前端选择 `image_2` 下的一张图片后，后端根据同名规则自动找到对应的点云与标定文件，再调用 8000 端 MMDet3D 服务完成检测，最后用 KITTI calib 在后端重新生成左相机投影可视化。

核心输入关系如下：

```text
training/image_2/000123.png
training/velodyne/000123.bin
training/calib/000123.txt

testing/image_2/000123.png
testing/velodyne/000123.bin
testing/calib/000123.txt
```

注意：`training` 和 `testing` 可能存在相同 stem，例如都叫 `000001`。如果只上传单个 `000001.png` 且不传 split 信息，后端无法可靠判断用户选择的是训练集还是测试集。这正是之前 “testing/image_2 好用，training/image_2 不好用” 的主要原因之一。

## 2. 数据集根目录解析

### 2.1 可移植配置

主配置不再写死本机盘符：

```properties
detection.kitti-dataset-root=${KITTI_DATASET_ROOT:}
```

后端会按以下顺序解析 KITTI 根目录：

1. 如果设置了环境变量 `KITTI_DATASET_ROOT` 或 Spring 配置 `detection.kitti-dataset-root`：
   - 绝对路径直接使用。
   - 相对路径会分别相对后端工作目录与仓库根目录解析。
2. 如果没有显式配置，则尝试常见相对位置：
   - `kitti`
   - `data/kitti`
   - `../kitti`
   - `../data/kitti`
   - `../kitty`
   - `../data/kitty`
3. 只有满足以下结构之一的目录才会被视为合法 KITTI 根：
   - 根目录本身包含 `image_2 / velodyne / calib`
   - 根目录包含 `training/image_2` 或 `testing/image_2`

当前本机为了继续使用 `F:/YOLO/kitty`，只在 local profile 中保留：

```properties
detection.kitti-dataset-root=F:/YOLO/kitty
```

这属于本机覆盖配置，不应写进通用主配置。迁移到其他机器时，推荐通过环境变量或 `application-local.properties` 指向新数据集根目录。

### 2.2 前端传入相对路径 hint

前端 MMDet3D 模式增加了 KITTI split 选择：

- `training`
- `testing`

当浏览器不能提供 `webkitRelativePath` 时，前端会构造可移植相对路径：

```text
training/image_2/{filename}
testing/image_2/{filename}
```

这样后端拿到的不是 `F:/...` 这种本机绝对路径，而是相对于 KITTI 根目录的逻辑路径。这个设计方便后续把数据集移动到其他机器或其他目录。

## 3. 自动匹配规则

后端接收：

- 左相机图像 `imageFile` 或 `file`
- `imagePathHint`
- 可选 `calibFile`
- 可选点云 `.bin`

当前前端主流程只上传左相机图像，点云和 calib 由后端匹配。

匹配逻辑位于：

```text
SOFT-rear/src/main/java/org/soft/softrear/service/dify/DetectionPipelineService.java
```

关键方法：

- `resolveKittiDatasetRoot()`
- `resolveKittiSampleFiles(...)`
- `resolveHintedPath(...)`
- `preferredKittiRoots(...)`
- `resolveSampleFilesFromImage(...)`

实际流程：

1. 先解析数据集根目录。
2. 把 `imagePathHint` 作为相对路径拼到 KITTI 根目录下。
   - 例如：`training/image_2/000123.png`
   - 解析为：`{KITTI_ROOT}/training/image_2/000123.png`
3. 如果 hint 指向真实图片，则优先使用该图片反推样本根：
   - `training/image_2/000123.png -> training`
   - `testing/image_2/000123.png -> testing`
4. 在样本根内找同名文件：
   - `{split}/velodyne/{stem}.bin`
   - `{split}/calib/{stem}.txt`
5. 如果 hint 不可用，再按优先级搜索：
   - `training`
   - `testing`
   - KITTI 根目录本身

这能避免 training/testing 同名样本时误配到另一个 split。

## 4. KITTI 投影公式

KITTI 左相机投影链路为：

```text
p_velo = [x, y, z, 1]^T
p_cam  = Tr_velo_to_cam * p_velo
p_rect = R0_rect * p_cam
p_img  = P2 * [p_rect; 1]
```

展开为：

```text
u = p_img.x / p_img.z
v = p_img.y / p_img.z
```

矩阵含义：

- `Tr_velo_to_cam`：LiDAR 坐标到相机坐标的外参。
- `R0_rect`：相机校正矩阵。
- `P2`：KITTI 左相机 `image_2 / CAM2` 投影矩阵。

实现中等价使用：

```text
lidar2img = P2 * R0_rect_4x4 * Tr_velo_to_cam_4x4
```

Java 后端当前仍按分步方式实现：

1. `calibration.lidarToCamera(...)`
2. `calibration.projectToImage(...)`

这与上面的矩阵乘法等价。

## 5. 3D 框角点的正确约定

### 5.1 旧记录中的错误

之前日志写过：

```text
LiDAR 3D 框以几何中心为中心，z 使用 ±dz/2
```

这个说法对当前 MMDet3D PointPillars 输出是不准确的。MMDet3D 的 `LiDARInstance3DBoxes` 默认格式是：

```text
[x, y, z, dx, dy, dz, yaw]
```

其中：

- `(x, y, z)` 是 LiDAR 框的底部中心，而不是几何中心。
- `dx, dy, dz` 是沿 LiDAR `x/y/z` 的尺寸。
- `yaw` 绕 LiDAR `z` 轴旋转。
- 相对原点是 `(0.5, 0.5, 0)`。

因此，兜底角点不能写成 `z ± dz/2`。正确的未旋转局部角点应是：

```text
(-dx/2, -dy/2, 0)
(-dx/2, -dy/2, dz)
(-dx/2,  dy/2, dz)
(-dx/2,  dy/2, 0)
( dx/2, -dy/2, 0)
( dx/2, -dy/2, dz)
( dx/2,  dy/2, dz)
( dx/2,  dy/2, 0)
```

再绕 LiDAR `z` 轴旋转：

```text
Rz(yaw) =
[ cos(yaw)  -sin(yaw)   0 ]
[ sin(yaw)   cos(yaw)   0 ]
[    0          0       1 ]
```

最终：

```text
p_i = Rz(yaw) * c_i + [x, y, z]^T
```

### 5.2 当前最可靠做法

当前 8000 端 FastAPI 服务已改为直接返回 MMDet3D 原生角点：

```python
corners = pred.bboxes_3d.corners.detach().cpu().numpy()
```

每个 detection 中新增：

```json
{
  "bbox_3d": [x, y, z, dx, dy, dz, yaw],
  "corners_3d": [[x0, y0, z0], "..."],
  "box_type_3d": "LiDAR"
}
```

Java 后端投影时优先读取 `corners_3d`。只有外部服务没有返回角点时，才用 `bbox_3d` 兜底生成 LiDAR 角点。

这比在 Java 端重新猜 MMDet3D 的角点规则更稳，也能避免角点顺序、原点位置、坐标系约定不一致造成的投影框歪斜。

## 6. 8000 端 calib 修正

之前后端虽然把匹配到的 calib 通过 multipart 传给 8000 端，但 8000 端接口没有接收 `calib_file` 参数，导致服务内部可视化仍然可能使用固定 testing calib 兜底。

当前已修正：

- `fastapi_realtime_infer/app/main.py`
  - `/predict` 接收 `calib_file`
  - 保存到临时文件后传给 `render_image_visualization(...)`
- `fastapi_realtime_infer/app/detector.py`
  - `render_image_visualization(..., calib_path=None)`
  - 如果有上传 calib，优先使用上传 calib
  - 没有上传 calib 时才走内部 fallback
- `fastapi_realtime_infer/app/settings.py`
  - fallback 数据集根改为 `KITTI_DATASET_ROOT` 或相对 `PROJECT_ROOT/data/kitti`
  - 不再硬编码 `F:\YOLO\kitty\testing`

不过在本项目主流程中，最终显示给前端的 `image_visualization` 仍由 Java 后端基于匹配到的 calib 重新渲染并覆盖 8000 端返回图。这样可以把投影链路收口到后端，便于排查。

## 7. 代码对应关系

### 后端 Java

```text
SOFT-rear/src/main/java/org/soft/softrear/service/dify/DetectionPipelineService.java
```

关键职责：

- `resolveKittiDatasetRoot()`：解析可移植 KITTI 根目录。
- `resolveKittiSampleFiles(...)`：根据 image hint 和 stem 匹配 `bin/calib`。
- `renderCalibratedProjection(...)`：基于后端匹配到的 calib 重新渲染投影框。
- `resolveBoxCorners(...)`：优先读取 `corners_3d`，兜底处理 LiDAR/Camera box。
- `projectPoint(...)`：根据坐标系选择是否执行 LiDAR -> Camera，再投影到 image。

### 8000 FastAPI 服务

```text
F:/YOLO/kitty/fastapi_realtime_infer/app/detector.py
F:/YOLO/kitty/fastapi_realtime_infer/app/main.py
F:/YOLO/kitty/fastapi_realtime_infer/app/schemas.py
F:/YOLO/kitty/fastapi_realtime_infer/app/settings.py
```

关键职责：

- 使用 `pred.bboxes_3d.corners` 返回 MMDet3D 原生角点。
- 接收后端传入的 `calib_file`。
- 内部 fallback 不再硬编码本机 testing 路径。

### 前端 Vue

```text
web/src/components/ImageUpload.vue
web/src/api/image.js
```

关键职责：

- MMDet3D 模式选择 `training/testing`。
- 构造 `training/image_2/{filename}` 或 `testing/image_2/{filename}` 作为 `imagePathHint`。
- 上传左图，由后端自动匹配点云与 calib。

## 8. 排查结论

这次问题由三个因素叠加：

1. 后端默认 KITTI 根目录曾经偏向 `testing`，导致 training 图片容易匹配不到或匹配错。
2. 浏览器单文件上传无法暴露真实绝对路径，只传 `000123.png` 时无法区分 training/testing。
3. 投影框角点曾经按几何中心推导，与 MMDet3D `LiDARInstance3DBoxes` 的底部中心约定不一致。

当前修复后：

- 前端显式传入 split 相对路径。
- 后端使用可移植数据集根目录解析。
- 8000 端返回 MMDet3D 原生角点。
- Java 后端优先使用 `corners_3d` 并用对应 calib 重投影。

后续如果迁移环境，优先检查：

1. `KITTI_DATASET_ROOT` 是否指向包含 `training/testing` 的 KITTI 根目录。
2. 前端 split 是否选对。
3. `image_2 / velodyne / calib` 是否存在同名 stem。
4. 8000 端是否已重启，使 `corners_3d` 和 `calib_file` 修正生效。
