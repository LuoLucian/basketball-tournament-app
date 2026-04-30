import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import './assets/main.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// 初始化认证状态（带兜底，确保应用一定能启动）
const authStore = useAuthStore()
authStore.init()
  .then(() => app.mount('#app'))
  .catch(() => app.mount('#app'))

// 保底：最多等 5 秒，强制挂载
setTimeout(() => {
  if (!document.getElementById('app').__vue_app__) {
    app.mount('#app')
  }
}, 5000)
