# KITTI 投影与自动匹配算法日志

## 1. 目标

当前工程的 MMDet3D 联调流程改成了“只上传左相机图像”，后端自动根据同名样本去匹配：

- 点云文件：`velodyne/{stem}.bin`
- 标定文件：`calib/{stem}.txt`

其中 `stem` 来自左图文件名，例如 `000001.png -> 000001`。

## 2. 自动匹配规则

### 2.1 输入

- 前端上传左相机图像
- 前端附带 `imagePathHint`
  - 优先取 `file.webkitRelativePath`
  - 没有相对路径时退化为 `file.name`

### 2.2 后端匹配顺序

1. 先把 `imagePathHint` 当作相对路径尝试解析
2. 如果能在数据集根目录下直接定位到图片，则取它的父目录作为样本目录
3. 再按同名规则去找：
   - `sample_root/velodyne/{stem}.bin`
   - `sample_root/calib/{stem}.txt`
4. 如果上一步没找到，回退到数据集根目录下递归搜索同名图片，再反推 sibling 目录

### 2.3 说明

浏览器不会暴露真实本地绝对路径，所以这里的“上级目录”不是用户磁盘绝对路径，而是前端可见的相对路径提示。真正的目录审查和 sibling 匹配都在后端数据集根目录内完成。

## 3. 投影公式

KITTI 的左相机投影链路为：

```text
p_velo = [x, y, z, 1]^T
p_cam  = Tr_velo_to_cam * p_velo
p_rect = R0_rect * p_cam
p_img  = P2 * [p_rect; 1]
```

展开后：

```text
u = p_img.x / p_img.z
v = p_img.y / p_img.z
```

其中：

- `Tr_velo_to_cam`：LiDAR 到相机坐标系外参
- `R0_rect`：KITTI 右图/左图的校正矩阵
- `P2`：左相机（CAM2 / image_2）投影矩阵

最终使用的是：

```text
lidar2img = P2 * R0_rect_4x4 * Tr_velo_to_cam_4x4
```

## 4. 3D 框角点计算

当前实现与 `fastapi_realtime_infer/app/detector.py` 保持一致，使用的是**几何中心为中心**的角点定义：

```text
C = {
  (+dx/2, +dy/2, +dz/2),
  (+dx/2, -dy/2, +dz/2),
  (-dx/2, -dy/2, +dz/2),
  (-dx/2, +dy/2, +dz/2),
  (+dx/2, +dy/2, -dz/2),
  (+dx/2, -dy/2, -dz/2),
  (-dx/2, -dy/2, -dz/2),
  (-dx/2, +dy/2, -dz/2)
}
```

绕 LiDAR 的 `z` 轴旋转：

```text
Rz(yaw) =
[ cos(yaw)  -sin(yaw)   0 ]
[ sin(yaw)   cos(yaw)   0 ]
[    0          0       1 ]
```

每个角点的世界坐标为：

```text
p_i = Rz(yaw) * c_i + [x, y, z]^T
```

最后再用 `lidar2img` 投影到图像平面。

## 5. 代码对应关系

### 后端 Java

- `SOFT-rear/src/main/java/org/soft/softrear/service/dify/DetectionPipelineService.java`
  - `resolveKittiSampleFiles(...)`：自动匹配 `bin` / `calib`
  - `renderCalibratedProjection(...)`：基于 calib 重新投影
  - `boxCorners(...)`：3D 框 8 个角点计算
  - `projectPoint(...)`：LiDAR -> Camera -> Image

- `SOFT-rear/src/main/java/org/soft/softrear/controller/ExternalServiceController.java`
  - `imagePathHint` 请求参数透传

### 前端 Vue

- `web/src/components/ImageUpload.vue`
  - 只保留左相机上传
  - 将 `webkitRelativePath` / `file.name` 传给后端

- `web/src/api/image.js`
  - `runDronePipeline(...)` 增加 `imagePathHint`

## 6. 经验结论

之前投影偏差主要来自两类问题：

1. 只传左图，但后端仍按固定样本根目录找文件，容易找错样本
2. 角点定义和可视化实现没有和 8000 端的实际输出保持一致

当前做法把“路径匹配”和“投影公式”都收口到了后端，论文里可以直接按这条链路写。
