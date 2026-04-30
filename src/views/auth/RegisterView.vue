<template>
  <div class="min-h-screen bg-gradient-to-br from-primary-900 via-primary-800 to-primary-700 flex items-center justify-center p-4">
    <div class="w-full max-w-sm">
      <div class="text-center mb-8">
        <div class="inline-flex items-center justify-center w-16 h-16 bg-white rounded-2xl shadow-lg mb-4">
          <svg class="w-10 h-10" viewBox="0 0 32 32" fill="none">
            <rect width="32" height="32" rx="8" fill="#1565c0"/>
            <circle cx="16" cy="16" r="9" stroke="white" stroke-width="1.5" fill="none"/>
            <line x1="16" y1="7" x2="16" y2="25" stroke="white" stroke-width="1.5"/>
            <path d="M7 16 Q11 12 16 16 Q21 20 25 16" stroke="white" stroke-width="1.5" fill="none"/>
          </svg>
        </div>
        <h1 class="text-2xl font-bold text-white">德泰篮球赛事</h1>
        <p class="text-primary-200 text-sm mt-1">创建你的账号</p>
      </div>

      <div class="bg-white rounded-2xl shadow-xl p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-5">注册账号</h2>

        <form @submit.prevent="handleRegister" class="space-y-4">
          <div class="form-group">
            <label class="label">昵称</label>
            <input v-model="form.displayName" type="text" class="input"
              placeholder="你的显示名称" required />
          </div>
          <div class="form-group">
            <label class="label">邮箱</label>
            <input v-model="form.email" type="email" class="input"
              placeholder="请输入邮箱" required />
          </div>
          <div class="form-group">
            <label class="label">密码</label>
            <input v-model="form.password" type="password" class="input"
              placeholder="至少6位" required minlength="6" />
          </div>

          <div v-if="error" class="flex items-center gap-2 p-3 bg-red-50 rounded-lg text-sm text-red-600">
            <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>
            {{ error }}
          </div>
          <div v-if="success" class="flex items-center gap-2 p-3 bg-green-50 rounded-lg text-sm text-green-700">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>
            {{ success }}
          </div>

          <button type="submit" class="btn-primary w-full btn-lg" :disabled="loading">
            <svg v-if="loading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
            </svg>
            {{ loading ? '注册中...' : '注 册' }}
          </button>
        </form>

        <div class="mt-4 text-center text-sm text-gray-500">
          已有账号？
          <router-link to="/login" class="text-primary-600 font-medium hover:underline">去登录</router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const form = reactive({ displayName: '', email: '', password: '' })
const error = ref('')
const success = ref('')
const loading = ref(false)

async function handleRegister() {
  error.value = ''
  success.value = ''
  loading.value = true
  try {
    await auth.signUp(form.email, form.password, form.displayName)
    success.value = '注册成功！请查收邮件进行验证后登录。'
  } catch (e) {
    const msg = e.message || ''
    if (msg.includes('already registered')) {
      error.value = '该邮箱已注册，请直接登录'
    } else {
      error.value = msg || '注册失败，请稍后重试'
    }
  } finally {
    loading.value = false
  }
}
</script>
