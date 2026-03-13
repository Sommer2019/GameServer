import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
})

// Attach JWT token from localStorage to every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Auth
export const register = (data) => api.post('/auth/register', data)
export const login = (data) => api.post('/auth/login', data)

// Server management
export const getServer = () => api.get('/servers')
export const createServer = (data) => api.post('/servers', data)
export const startServer = () => api.post('/servers/start')
export const stopServer = () => api.post('/servers/stop')
export const deleteServer = () => api.delete('/servers')

export default api
