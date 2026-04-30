<template>
  <div class="page-container">
    <div class="flex items-center justify-between mb-5">
      <h1 class="text-xl font-bold text-white">用户管理</h1>
      <button @click="showCreateModal = true" class="btn-primary btn-sm">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        创建用户
      </button>
    </div>

    <!-- 用户列表 -->
    <div class="card">
      <div class="card-header">
        <h2 class="font-semibold text-white">所有用户</h2>
        <span class="text-xs text-dark-500">{{ users.length }} 人</span>
      </div>
      <div class="divide-y divide-dark-700/30">
        <div v-for="u in users" :key="u.id"
          class="flex items-center gap-3 px-4 py-3 hover:bg-dark-800/50 transition-colors"
        >
          <div class="w-9 h-9 rounded-full bg-primary-600/20 border border-primary-600/30
                      text-primary-400 flex items-center justify-center text-sm font-semibold flex-shrink-0">
            {{ getInitials(u.display_name || u.username) }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-white">{{ u.display_name || u.username }}</p>
            <p class="text-xs text-dark-500">@{{ u.username }}</p>
          </div>
          <!-- 角色彩色 badge -->
          <span class="badge"
            :class="{
              'badge-blue': u.role === 'super_admin',
              'badge-orange': u.role === 'admin',
              'badge-green': u.role === 'recorder',
              'badge-gray': u.role === 'user'
            }"
          >{{ ROLE_LABELS[u.role] }}</span>
          <!-- 角色切换 -->
          <select
            :value="u.role"
            @change="updateRole(u.id, $event.target.value)"
            class="text-xs bg-dark-800 border border-dark-700 rounded-lg px-2 py-1
                   text-dark-300 focus:outline-none focus:ring-1 focus:ring-primary-500"
          >
            <option v-for="(label, val) in ROLE_LABELS" :key="val" :value="val">{{ label }}</option>
          </select>
          <!-- 删除按钮 -->
          <button @click="handleDelete(u)"
            class="text-dark-600 hover:text-danger transition-colors p-1"
            title="删除用户"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- 创建用户弹窗 -->
    <Teleport v-if="showCreateModal" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="showCreateModal = false">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showCreateModal = false"></div>
          <div class="relative bg-dark-850 rounded-2xl w-full max-w-md p-6 shadow-glass border border-dark-700/50">
            <h3 class="font-semibold text-white mb-2">创建新用户</h3>
            <p class="text-xs text-dark-500 mb-5">创建后将自动分配用户名和密码，请将该信息告知对方。</p>

            <form @submit.prevent="handleCreateUser" class="space-y-4">
              <div class="form-group">
                <label class="label">姓名 <span class="text-danger">*</span></label>
                <input v-model="form.displayName" type="text" class="input" placeholder="用户的显示名称" required />
              </div>
              <div class="form-group">
                <label class="label">用户名 <span class="text-danger">*</span></label>
                <input v-model="form.username" type="text" class="input" placeholder="字母、数字或下划线，至少3位" required minlength="3" pattern="[a-zA-Z0-9_]+" />
              </div>
              <div class="form-group">
                <label class="label">密码 <span class="text-danger">*</span></label>
                <div class="relative">
                  <input v-model="form.password"
                    :type="showPwd ? 'text' : 'password'"
                    class="input pr-10" placeholder="至少6位密码" required minlength="6" />
                  <button type="button" @click="showPwd = !showPwd"
                    class="absolute right-3 top-1/2 -translate-y-1/2 text-dark-500 hover:text-dark-300"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path v-if="!showPwd" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                      <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>
                    </svg>
                  </button>
                </div>
                <!-- 密码强度指示器 -->
                <div class="flex gap-1 mt-1.5">
                  <div class="h-1 flex-1 rounded-full transition-colors duration-300"
                    :class="pwdStrength >= 1 ? 'bg-danger' : 'bg-dark-700'"></div>
                  <div class="h-1 flex-1 rounded-full transition-colors duration-300"
                    :class="pwdStrength >= 2 ? 'bg-warning' : 'bg-dark-700'"></div>
                  <div class="h-1 flex-1 rounded-full transition-colors duration-300"
                    :class="pwdStrength >= 3 ? 'bg-success' : 'bg-dark-700'"></div>
                </div>
              </div>
              <div class="form-group">
                <label class="label">角色</label>
                <select v-model="form.role" class="input">
                  <option value="user">普通用户</option>
                  <option value="recorder">记录员</option>
                  <option value="admin">普通管理员</option>
                  <option value="super_admin">总管理员</option>
                </select>
              </div>

              <!-- 错误/成功提示 -->
              <div v-if="error" class="flex items-center gap-2 p-3 bg-danger/10 border border-danger/20 rounded-xl text-sm text-danger-light">
                <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>
                {{ error }}
              </div>
              <div v-if="successMsg" class="flex items-center gap-2 p-3 bg-success/10 border border-success/20 rounded-xl text-sm text-success">
                <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>
                {{ successMsg }}
              </div>

              <div class="flex gap-2 pt-2">
                <button type="button" @click="closeModal" class="btn-secondary flex-1">取消</button>
                <button type="submit" class="btn-primary flex-1" :disabled="creating">
                  {{ creating ? '创建中...' : '创建用户' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { getInitials, ROLE_LABELS } from '@/utils/helpers'

const auth = useAuthStore()
const users = ref([])
const showCreateModal = ref(false)
const creating = ref(false)
const error = ref('')
const successMsg = ref('')
const showPwd = ref(false)

const form = reactive({
  displayName: '',
  username: '',
  password: '',
  role: 'user'
})

const pwdStrength = computed(() => {
  const p = form.password
  if (!p) return 0
  let s = 0
  if (p.length >= 6) s++
  if (/[A-Z]/.test(p) && /[a-z]/.test(p)) s++
  if (/[0-9]/.test(p) && /[^a-zA-Z0-9]/.test(p)) s++
  return s
})

function closeModal() {
  showCreateModal.value = false
  error.value = ''
  successMsg.value = ''
}

async function loadUsers() {
  const { data } = await supabase.from('profiles').select('*').order('created_at')
  if (data) users.value = data
}

onMounted(loadUsers)

async function updateRole(userId, newRole) {
  await supabase.from('profiles').update({ role: newRole }).eq('id', userId)
}

async function handleDelete(u) {
  if (!confirm(`确定要删除用户 "${u.display_name || u.username}" 吗？此操作不可恢复。`)) return
  try {
    await auth.deleteUser(u.username)
    await loadUsers()
  } catch (e) {
    alert(e.message || '删除失败')
  }
}

async function handleCreateUser() {
  if (!form.displayName.trim() || !form.username.trim() || !form.password) {
    error.value = '请填写所有必填项'
    return
  }
  error.value = ''
  successMsg.value = ''
  creating.value = true
  try {
    await auth.createUser({
      username: form.username.trim(),
      password: form.password,
      displayName: form.displayName.trim(),
      role: form.role
    })
    successMsg.value = `用户创建成功！用户名: ${form.username}，密码: ${form.password}`
    form.displayName = ''
    form.username = ''
    form.password = ''
    form.role = 'user'
    await loadUsers()
  } catch (e) {
    const msg = e.message || ''
    if (msg.includes('用户名已存在')) {
      error.value = '该用户名已被使用'
    } else if (msg.includes('密码') || msg.includes('6位')) {
      error.value = '密码不符合要求（至少6位）'
    } else if (msg.includes('字母') || msg.includes('3个字符')) {
      error.value = '用户名至少3个字符，只能包含字母、数字和下划线'
    } else {
      error.value = msg || '创建失败，请稍后重试'
    }
  } finally {
    creating.value = false
  }
}
</script>

<style scoped>
.modal-enter-active { transition: all 0.2s ease; }
.modal-leave-active { transition: all 0.15s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-from > div:last-child { transform: scale(0.95); }
</style>
