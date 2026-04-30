<template>
  <div class="min-h-screen bg-dark-900 flex items-center justify-center p-4 relative overflow-hidden">
    <!-- 装饰背景 -->
    <div class="absolute inset-0 bg-gradient-to-br from-primary-900/50 via-dark-900 to-dark-950"></div>
    <div class="absolute top-1/4 left-1/4 w-64 h-64 bg-primary-600/5 rounded-full blur-3xl animate-float"></div>
    <div class="absolute bottom-1/4 right-1/4 w-48 h-48 bg-accent-500/5 rounded-full blur-3xl animate-float" style="animation-delay: 1.5s"></div>

    <!-- 浮动篮球 SVG -->
    <svg class="absolute top-20 right-10 w-16 h-16 text-dark-800 animate-float opacity-30" viewBox="0 0 32 32" fill="none">
      <circle cx="16" cy="16" r="14" stroke="currentColor" stroke-width="1.5"/>
      <line x1="16" y1="2" x2="16" y2="30" stroke="currentColor" stroke-width="1"/>
      <path d="M2 16 Q10 10 16 16 Q22 22 30 16" stroke="currentColor" stroke-width="1" fill="none"/>
    </svg>
    <svg class="absolute bottom-24 left-16 w-10 h-10 text-dark-800 animate-float opacity-20" viewBox="0 0 32 32" fill="none" style="animation-delay: 0.8s">
      <circle cx="16" cy="16" r="14" stroke="currentColor" stroke-width="1.5"/>
      <line x1="16" y1="2" x2="16" y2="30" stroke="currentColor" stroke-width="1"/>
      <path d="M2 16 Q10 10 16 16 Q22 22 30 16" stroke="currentColor" stroke-width="1" fill="none"/>
    </svg>

    <div class="w-full max-w-sm relative z-10">
      <!-- Logo -->
      <div class="text-center mb-8">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl
                    bg-gradient-to-br from-primary-500 to-primary-700 shadow-neon-blue mb-4">
          <svg class="w-10 h-10" viewBox="0 0 32 32" fill="none">
            <circle cx="16" cy="16" r="9" stroke="white" stroke-width="1.5" fill="none"/>
            <line x1="16" y1="7" x2="16" y2="25" stroke="white" stroke-width="1.5"/>
            <path d="M7 16 Q11 12 16 16 Q21 20 25 16" stroke="white" stroke-width="1.5" fill="none"/>
          </svg>
        </div>
        <h1 class="text-2xl font-bold text-white mb-1">德泰篮球赛事</h1>
        <p class="text-dark-500 text-sm">德泰科技园篮球赛事管理系统</p>
      </div>

      <!-- 登录卡片 -->
      <div class="bg-dark-850/80 backdrop-blur-xl rounded-2xl border border-dark-700/50 p-6 shadow-glass">
        <h2 class="text-lg font-semibold text-white mb-5">管理员登录</h2>

        <form @submit.prevent="handleLogin" class="space-y-4">
          <div class="form-group">
            <label class="label">用户名</label>
            <input v-model="form.username" type="text" class="input"
              placeholder="请输入用户名" required autocomplete="username" />
          </div>

          <div class="form-group">
            <label class="label">密码</label>
            <div class="relative">
              <input v-model="form.password"
                :type="showPassword ? 'text' : 'password'"
                class="input pr-10" placeholder="请输入密码"
                required autocomplete="current-password" />
              <button type="button" @click="showPassword = !showPassword"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-dark-500 hover:text-dark-300"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path v-if="!showPassword" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- 错误提示 -->
          <div v-if="error" class="flex items-center gap-2 p-3 bg-danger/10 border border-danger/20 rounded-xl text-sm text-danger-light">
            <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
            {{ error }}
          </div>

          <button type="submit" class="btn-primary w-full btn-lg" :disabled="loading">
            <svg v-if="loading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
            </svg>
            {{ loading ? '登录中...' : '登 录' }}
          </button>
        </form>

        <div class="mt-4 text-center text-sm text-dark-500">
          <router-link to="/" class="text-primary-400 hover:text-primary-300 font-medium transition-colors">← 返回首页</router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const form = reactive({ username: '', password: '' })
const error = ref('')
const loading = ref(false)
const showPassword = ref(false)

async function handleLogin() {
  error.value = ''
  loading.value = true
  try {
    await auth.signIn(form.username, form.password)
    const redirect = route.query.redirect || '/'
    router.push(redirect)
  } catch (e) {
    const msg = e.message || ''
    if (msg.includes('用户名不存在') || msg.includes('密码错误')) {
      error.value = msg
    } else {
      error.value = msg || '登录失败，请稍后重试'
    }
  } finally {
    loading.value = false
  }
}
</script>
