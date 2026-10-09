import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import { initSupabase } from './utils/supabase'
import './assets/main.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// 先选 Supabase 线路（主线路不通自动切备用），再初始化认证（带兜底，确保应用一定能启动）
const authStore = useAuthStore()
initSupabase()
  .catch(() => {})
  .then(() => authStore.init())
  .then(() => app.mount('#app'))
  .catch(() => app.mount('#app'))

// 保底：最多等 5 秒，强制挂载
setTimeout(() => {
  if (!document.getElementById('app').__vue_app__) {
    app.mount('#app')
  }
}, 5000)
