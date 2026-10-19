import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import { initSupabase } from './utils/supabase'
import { installImageRouting } from './utils/imageRoute'
import './assets/main.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// 先选 Supabase 线路（主线路不通自动切备用），再初始化认证（带兜底，确保应用一定能启动）
const authStore = useAuthStore()
initSupabase()
  .catch(() => {})
  .then(() => {
    // 线路确定后再启用图片跟随（头像/队标自动走当前线路，失败自动换线重试）
    installImageRouting()
    return authStore.init()
  })
  .then(() => app.mount('#app'))
  .catch(() => {
    installImageRouting()
    app.mount('#app')
  })

// 保底：最多等 5 秒，强制挂载
setTimeout(() => {
  if (!document.getElementById('app').__vue_app__) {
    app.mount('#app')
  }
}, 5000)
