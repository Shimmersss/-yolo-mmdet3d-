<template>
  <div class="image-upload">
    <div class="upload-head">
      <div>
        <p class="subtitle">{{ subtitleText }}</p>
        <p class="service" :class="{ online: serviceOnline, offline: serviceOnline === false }">
          <span></span>{{ serviceText }}
        </p>
      </div>
      <button class="icon-btn" type="button" :title="refreshTitle" @click="loadHealth">↻</button>
    </div>

    <div class="mode-row">
      <span class="mode-label">检测模式</span>
      <div class="mode-tabs">
        <button
          type="button"
          class="mode-tab"
          :class="{ active: mode === 'yolo' }"
          @click="mode = 'yolo'"
        >
          YOLO 图像
        </button>
        <button
          type="button"
          class="mode-tab"
          :class="{ active: mode === 'mmdet3d' }"
          @click="mode = 'mmdet3d'"
        >
          MMDet3D 点云
        </button>
      </div>
    </div>

    <template v-if="isYolo">
      <label class="drop-zone" :class="{ dragging: isDraggingMain }" @dragover.prevent="isDraggingMain = true" @dragleave.prevent="isDraggingMain = false" @drop.prevent="handleMainDrop">
        <input type="file" accept="image/*" @change="handleMainFileChange">
        <span class="upload-icon">＋</span>
        <strong>{{ mainFileName || '选择或拖入图片' }}</strong>
        <small>支持 JPG / PNG / WEBP</small>
      </label>

      <div class="control-row">
        <label>
          置信度
          <input v-model.number="conf" type="range" min="0.05" max="0.95" step="0.05">
          <span>{{ conf.toFixed(2) }}</span>
        </label>
        <label>
          IoU
          <input v-model.number="iou" type="range" min="0.10" max="0.90" step="0.05">
          <span>{{ iou.toFixed(2) }}</span>
        </label>
      </div>
    </template>

    <template v-else>
      <label class="drop-zone" :class="{ dragging: isDraggingPoint }" @dragover.prevent="isDraggingPoint = true" @dragleave.prevent="isDraggingPoint = false" @drop.prevent="handlePointDrop">
        <input type="file" accept=".bin" @change="handlePointFileChange">
        <span class="upload-icon">＋</span>
        <strong>{{ pointFileName || '选择或拖入 KITTI .bin' }}</strong>
        <small>点云必填，按文件名自动匹配 pkl 中的 CAM2 投影</small>
      </label>

      <label class="drop-zone optional-zone" :class="{ dragging: isDraggingImage }" @dragover.prevent="isDraggingImage = true" @dragleave.prevent="isDraggingImage = false" @drop.prevent="handleImageDrop">
        <input type="file" accept="image/*" @change="handleImageFileChange">
        <span class="upload-icon">＋</span>
        <strong>{{ imageFileName || '选择可选左相机图片' }}</strong>
        <small>与点云同名时自动投影到图片</small>
      </label>

      <div class="control-row single">
        <label>
          置信度阈值
          <input v-model.number="scoreThr" type="range" min="0.05" max="0.95" step="0.05">
          <span>{{ scoreThr.toFixed(2) }}</span>
        </label>
      </div>
    </template>

    <button class="btn btn-primary run-btn" type="button" :disabled="!canRun || loading" @click="runDetection">
      {{ loading ? '检测中...' : '开始检测' }}
    </button>

    <div v-if="error" class="error">{{ error }}</div>

    <div v-if="previewImages.length" class="image-grid">
      <figure v-for="(item, index) in previewImages" :key="index" :class="item.className">
        <figcaption>{{ item.title }}</figcaption>
        <button type="button" class="image-button" @click="openViewer(item.src)">
          <img :src="item.src" :alt="item.title">
          <span class="zoom-badge">点击查看大图</span>
        </button>
      </figure>
    </div>

    <div v-if="hasResult" class="result-card">
      <button class="result-top" type="button" @click="showDetails = !showDetails">
        <strong>检测结果</strong>
        <span class="result-meta">{{ detections.length }} 项</span>
        <span class="toggle">{{ showDetails ? '收起' : '展开' }}</span>
      </button>

      <div v-if="showDetails" class="result-list">
        <div class="detection" v-for="(item, index) in detections" :key="index">
          <strong>{{ formatLabel(item, index) }}</strong>
          <span>{{ formatPercent(item.score) }}</span>
          <small>{{ formatBoxLabel(item) }}: {{ formatBox(item.bbox_3d) }}</small>
        </div>
        <div v-if="!detections.length" class="empty-result">未检测到目标，试试降低阈值后重试。</div>
      </div>
    </div>

    <div v-if="viewerOpen" class="viewer" @click.self="viewerOpen = false">
      <div class="viewer-panel">
        <button class="viewer-close" type="button" @click="viewerOpen = false">×</button>
        <img :src="viewerSrc" alt="检测结果大图">
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import {
  checkMmdet3dHealth,
  checkYoloHealth,
  uploadImage,
  uploadPointCloudWithImage
} from '../api/image'

const mode = ref('yolo')
const conf = ref(0.25)
const iou = ref(0.45)
const scoreThr = ref(0.3)
const loading = ref(false)
const error = ref('')
const serviceOnline = ref(null)
const serviceDevice = ref('')
const hasResult = ref(false)
const showDetails = ref(false)
const viewerOpen = ref(false)
const viewerSrc = ref('')
const detections = ref([])

const mainFile = ref(null)
const pointCloudFile = ref(null)
const imageFile = ref(null)
const previewImages = ref([])

const isDraggingMain = ref(false)
const isDraggingPoint = ref(false)
const isDraggingImage = ref(false)

const isYolo = computed(() => mode.value === 'yolo')

const mainFileName = computed(() => (mainFile.value ? mainFile.value.name : ''))
const pointFileName = computed(() => (pointCloudFile.value ? pointCloudFile.value.name : ''))
const imageFileName = computed(() => (imageFile.value ? imageFile.value.name : ''))
const canRun = computed(() => (isYolo.value ? !!mainFile.value : !!pointCloudFile.value))

const serviceLabel = computed(() => (isYolo.value ? 'YOLO' : 'MMDet3D'))
const refreshTitle = computed(() => '刷新服务状态')

const serviceText = computed(() => {
  if (serviceOnline.value === true) {
    return serviceLabel.value + ' 服务已连接' + (serviceDevice.value ? ' · ' + serviceDevice.value : '')
  }
  if (serviceOnline.value === false) {
    return serviceLabel.value + ' 服务未连接'
  }
  return '正在检查 ' + serviceLabel.value + ' 服务'
})

const subtitleText = computed(() => {
  return isYolo.value
    ? '上传图片后调用 YOLO HTTP 服务进行检测'
    : '上传点云，图片可选；若上传图片，将输出点云和左相机投影可视化'
})

const clearViewer = () => {
  viewerOpen.value = false
  viewerSrc.value = ''
}

const resetResult = () => {
  detections.value = []
  previewImages.value = []
  hasResult.value = false
  showDetails.value = false
  error.value = ''
  clearViewer()
}

const resetFiles = () => {
  mainFile.value = null
  pointCloudFile.value = null
  imageFile.value = null
  isDraggingMain.value = false
  isDraggingPoint.value = false
  isDraggingImage.value = false
}

const setMainFile = (file) => {
  if (!file) return
  if (!file.type.startsWith('image/')) {
    error.value = '请选择图片文件'
    return
  }
  mainFile.value = file
  error.value = ''
  resetResult()
}

const setPointCloudFile = (file) => {
  if (!file) return
  if (!file.name.toLowerCase().endsWith('.bin')) {
    error.value = '请选择 KITTI .bin 点云文件'
    return
  }
  pointCloudFile.value = file
  error.value = ''
  resetResult()
}

const setImageFile = (file) => {
  if (!file) return
  if (!file.type.startsWith('image/')) {
    error.value = '请选择图片文件'
    return
  }
  imageFile.value = file
  error.value = ''
  resetResult()
}

const handleMainFileChange = (event) => {
  setMainFile(event.target.files && event.target.files[0])
  event.target.value = ''
}

const handlePointFileChange = (event) => {
  setPointCloudFile(event.target.files && event.target.files[0])
  event.target.value = ''
}

const handleImageFileChange = (event) => {
  setImageFile(event.target.files && event.target.files[0])
  event.target.value = ''
}

const handleMainDrop = (event) => {
  isDraggingMain.value = false
  setMainFile(event.dataTransfer.files && event.dataTransfer.files[0])
}

const handlePointDrop = (event) => {
  isDraggingPoint.value = false
  setPointCloudFile(event.dataTransfer.files && event.dataTransfer.files[0])
}

const handleImageDrop = (event) => {
  isDraggingImage.value = false
  setImageFile(event.dataTransfer.files && event.dataTransfer.files[0])
}

const loadHealth = async () => {
  try {
    serviceOnline.value = null
    serviceDevice.value = ''
    const response = isYolo.value ? await checkYoloHealth() : await checkMmdet3dHealth()
    const data = response.data || {}
    serviceOnline.value = data.status === 'ok'
    if (data.device) {
      serviceDevice.value = 'device: ' + data.device
    }
  } catch {
    serviceOnline.value = false
  }
}

const runDetection = async () => {
  if (!canRun.value) return

  try {
    loading.value = true
    error.value = ''
    clearViewer()
    detections.value = []
    previewImages.value = []
    hasResult.value = false
    showDetails.value = false

    const response = isYolo.value
      ? await uploadImage(mainFile.value, { conf: conf.value, iou: iou.value })
      : await uploadPointCloudWithImage(pointCloudFile.value, imageFile.value, {
          scoreThr: scoreThr.value
        })

    const data = response.data || {}
    detections.value = Array.isArray(data.detections) ? data.detections : []
    previewImages.value = []

    if (isYolo.value) {
      if (data.annotated_image) {
        previewImages.value.push({
          title: 'YOLO 检测结果',
          src: data.annotated_image,
          className: 'result-figure'
        })
      }
    } else {
      if (data.pointcloud_visualization) {
        previewImages.value.push({
          title: '点云检测可视化',
          src: data.pointcloud_visualization,
          className: 'result-figure'
        })
      }
      if (data.image_visualization) {
        previewImages.value.push({
          title: '左相机投影可视化',
          src: data.image_visualization,
          className: 'result-figure'
        })
      }
    }

    serviceOnline.value = true
    hasResult.value = true
  } catch (err) {
    const detail = err && err.response && err.response.data && err.response.data.detail
    error.value = detail || err.message || '检测失败，请确认服务正在运行'
  } finally {
    loading.value = false
  }
}

const openViewer = (src) => {
  viewerSrc.value = src
  viewerOpen.value = true
}

const formatPercent = (value) => {
  if (value === undefined || value === null || Number.isNaN(Number(value))) return ''
  return (Number(value) * 100).toFixed(1) + '%'
}

const formatBox = (box) => {
  if (!Array.isArray(box)) return ''
  return box.map((value) => Number(value).toFixed(2)).join(', ')
}

const formatLabel = (item, index) => item.class_name || item.class || '目标 ' + (index + 1)
const formatBoxLabel = () => 'bbox3d'

onMounted(loadHealth)
onUnmounted(clearViewer)

watch(mode, () => {
  resetFiles()
  resetResult()
  loadHealth()
})
</script>

<style scoped>
.image-upload {
  display: grid;
  gap: 16px;
}

.upload-head,
.result-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.subtitle {
  color: var(--text-muted);
  margin-bottom: 6px;
}

.service {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: var(--text-muted);
  font-size: 13px;
}

.service span {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #9aa4b2;
}

.service.online span {
  background: #13a86b;
}

.service.offline span {
  background: #e5484d;
}

.icon-btn {
  width: 38px;
  height: 38px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fff;
  color: var(--brand);
  cursor: pointer;
  font-size: 20px;
}

.drop-zone {
  position: relative;
  min-height: 170px;
  border: 1px dashed #9fb0c7;
  border-radius: 8px;
  background: #f8fbff;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 8px;
  cursor: pointer;
  transition: border-color 180ms ease, background 180ms ease, transform 180ms ease;
  text-align: center;
}

.optional-zone {
  min-height: 150px;
}

.drop-zone.dragging,
.drop-zone:hover {
  border-color: var(--brand);
  background: #eef9f6;
  transform: translateY(-1px);
}

.drop-zone input {
  position: absolute;
  inset: 0;
  opacity: 0;
  cursor: pointer;
}

.upload-icon {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 8px;
  background: #e2f4f0;
  color: var(--brand);
  font-size: 28px;
  line-height: 1;
}

.drop-zone small {
  color: var(--text-muted);
}

.mode-row {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.mode-label {
  color: var(--text-muted);
  font-size: 13px;
  font-weight: 700;
}

.mode-tabs {
  display: inline-flex;
  gap: 8px;
  padding: 4px;
  border-radius: 999px;
  border: 1px solid var(--line);
  background: #fff;
}

.mode-tab {
  border: 0;
  padding: 6px 14px;
  border-radius: 999px;
  background: transparent;
  color: var(--text-muted);
  font-weight: 700;
  cursor: pointer;
}

.mode-tab.active {
  background: #e2f4f0;
  color: var(--brand);
}

.control-row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.control-row.single {
  grid-template-columns: minmax(0, 1fr);
}

.control-row label {
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 12px;
  background: #fff;
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 10px;
  font-weight: 700;
}

.control-row input {
  width: 100%;
  accent-color: var(--brand);
}

.control-row span {
  color: var(--brand);
  font-variant-numeric: tabular-nums;
}

.run-btn {
  width: 100%;
}

.error,
.empty-result {
  border-radius: 8px;
  padding: 10px 12px;
}

.error {
  color: #a11d21;
  background: #fff0f0;
  border: 1px solid #ffc9c9;
}

.image-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

figure,
.result-card {
  border: 1px solid var(--line);
  border-radius: 8px;
  overflow: hidden;
  background: #fff;
}

figcaption {
  padding: 10px 12px;
  color: var(--text-muted);
  font-size: 13px;
  border-bottom: 1px solid var(--line);
}

figure img,
.viewer-panel img {
  width: 100%;
  height: 280px;
  object-fit: contain;
  display: block;
  background: #f4f7fb;
}

.result-figure {
  padding-bottom: 12px;
}

.image-button {
  width: 100%;
  border: 0;
  padding: 0;
  background: transparent;
  cursor: zoom-in;
  display: grid;
  gap: 8px;
}

.zoom-badge {
  color: var(--text-muted);
  font-size: 12px;
  padding: 0 12px;
}

.result-top {
  width: 100%;
  padding: 12px;
  border: 0;
  background: transparent;
  cursor: pointer;
}

.result-meta {
  margin-left: auto;
  color: var(--brand);
  font-weight: 700;
}

.toggle {
  color: var(--text-muted);
  font-size: 13px;
}

.result-list {
  border-top: 1px solid var(--line);
}

.detection {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 4px 12px;
  padding: 10px 12px;
  border-top: 1px solid #eef2f7;
}

.detection:first-of-type {
  border-top: 0;
}

.detection span {
  color: var(--brand);
  font-weight: 700;
}

.detection small {
  grid-column: 1 / -1;
  color: var(--text-muted);
}

.viewer {
  position: fixed;
  inset: 0;
  background: rgba(9, 14, 25, 0.72);
  display: grid;
  place-items: center;
  z-index: 50;
  padding: 18px;
}

.viewer-panel {
  position: relative;
  width: min(96vw, 1100px);
  max-height: 92vh;
  background: #0f172a;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 28px 70px rgba(0, 0, 0, 0.35);
}

.viewer-panel img {
  height: auto;
  max-height: 92vh;
  object-fit: contain;
  background: #0f172a;
}

.viewer-close {
  position: absolute;
  top: 10px;
  right: 10px;
  width: 36px;
  height: 36px;
  border: 0;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.14);
  color: #fff;
  font-size: 24px;
  cursor: pointer;
  z-index: 1;
}

@media (max-width: 760px) {
  .control-row,
  .image-grid {
    grid-template-columns: 1fr;
  }
}
</style>
