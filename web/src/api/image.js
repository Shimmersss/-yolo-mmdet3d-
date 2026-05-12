import axios from 'axios'

const yoloApi = axios.create({
  baseURL: import.meta.env.VITE_YOLO_API_BASE || 'http://127.0.0.1:9000',
  timeout: 120000
})

const mmdet3dApi = axios.create({
  baseURL: import.meta.env.VITE_MMDET3D_API_BASE || '/mmdet3d',
  timeout: 120000
})

export const checkYoloHealth = () => yoloApi.get('/health')
export const checkMmdet3dHealth = () => mmdet3dApi.get('/health')

export const uploadImage = (file, options = {}) => {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('conf', String(options.conf ?? 0.25))
  formData.append('iou', String(options.iou ?? 0.45))
  return yoloApi.post('/predict', formData)
}

export const uploadPointCloud = (file, options = {}) => {
  const formData = new FormData()
  formData.append('point_cloud_file', file)
  if (options.scoreThr !== undefined) {
    formData.append('score_thr', String(options.scoreThr))
  }
  return mmdet3dApi.post('/predict', formData)
}

export const uploadPointCloudWithImage = (pointCloudFile, imageFile, options = {}) => {
  const formData = new FormData()
  formData.append('point_cloud_file', pointCloudFile)
  if (imageFile) {
    formData.append('image_file', imageFile)
  }
  formData.append('score_thr', String(options.scoreThr ?? 0.3))
  return mmdet3dApi.post('/predict', formData)
}
