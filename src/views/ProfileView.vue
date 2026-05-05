<template>
  <div class="page-container max-w-2xl mx-auto">
    <!-- 个人资料头部 - 渐变暗色 -->
    <div class="relative rounded-2xl p-6 mb-5 overflow-hidden
                bg-gradient-to-br from-primary-700/30 via-dark-850 to-dark-900
                border border-primary-600/20">
      <div class="absolute -top-10 -right-10 w-32 h-32 bg-primary-500/10 rounded-full blur-2xl"></div>
      <div class="absolute -bottom-10 -left-10 w-24 h-24 bg-accent-500/10 rounded-full blur-2xl"></div>
      <div class="relative z-10 flex items-center gap-4">
        <div class="w-16 h-16 rounded-full bg-primary-600/20 border-2 border-primary-500/40
                    text-primary-400 flex items-center justify-center text-2xl font-bold flex-shrink-0">
          <img v-if="auth.profile?.avatar_url" :src="auth.profile.avatar_url" class="w-16 h-16 rounded-full object-cover" />
          <span v-else>{{ getInitials(auth.profile?.display_name || '') }}</span>
        </div>
        <div>
          <p class="font-bold text-white text-lg">{{ auth.profile?.display_name || '未设置' }}</p>
          <p class="text-sm text-dark-400">@{{ auth.user?.username }}</p>
          <span class="badge mt-1.5" :class="roleClass">{{ ROLE_LABELS[auth.role] }}</span>
        </div>
      </div>
    </div>

    <!-- 编辑资料 -->
    <div class="card card-body mb-5">
      <h2 class="section-title mb-4">编辑资料</h2>
      <form @submit.prevent="saveProfile" class="space-y-4">
        <div class="form-group">
          <label class="label">显示名称</label>
          <input v-model="form.displayName" type="text" class="input" />
        </div>
        <div class="form-group">
          <label class="label">手机号</label>
          <input v-model="form.phone" type="tel" class="input" placeholder="可选" />
        </div>
        <div v-if="saveMsg" class="text-sm px-3 py-2 rounded-xl"
          :class="saveMsg.startsWith('✅') ? 'bg-success/10 text-success border border-success/20' : 'bg-danger/10 text-danger-light border border-danger/20'">
          {{ saveMsg }}
        </div>
        <button type="submit" class="btn-primary" :disabled="saving">
          {{ saving ? '保存中...' : '保存' }}
        </button>
      </form>
    </div>

    <!-- 修改密码 -->
    <div class="card card-body mb-5">
      <h2 class="section-title mb-4">修改密码</h2>
      <form @submit.prevent="handleChangePassword" class="space-y-4">
        <div class="form-group">
          <label class="label">原密码</label>
          <input v-model="pwdForm.oldPassword" type="password" class="input" placeholder="输入当前密码" required />
        </div>
        <div class="form-group">
          <label class="label">新密码</label>
          <input v-model="pwdForm.newPassword" type="password" class="input" placeholder="至少6位新密码" required minlength="6" />
        </div>
        <div v-if="pwdMsg" class="text-sm px-3 py-2 rounded-xl"
          :class="pwdMsg.startsWith('✅') ? 'bg-success/10 text-success border border-success/20' : 'bg-danger/10 text-danger-light border border-danger/20'">
          {{ pwdMsg }}
        </div>
        <button type="submit" class="btn-secondary" :disabled="changingPwd">
          {{ changingPwd ? '修改中...' : '修改密码' }}
        </button>
      </form>
    </div>

    <!-- 退出 -->
    <button @click="handleSignOut" class="btn-danger w-full">退出登录</button>

    <!-- 版本号 -->
    <p class="text-center text-dark-600 text-[10px] mt-4">v{{ version }}</p>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { getInitials, ROLE_LABELS } from '@/utils/helpers'

const version = __APP_VERSION__

const auth = useAuthStore()
const router = useRouter()
const saving = ref(false)
const saveMsg = ref('')
const changingPwd = ref(false)
const pwdMsg = ref('')

const form = reactive({ displayName: '', phone: '' })
const pwdForm = reactive({ oldPassword: '', newPassword: '' })

const roleClass = computed(() => ({
  'badge-blue': auth.isSuperAdmin,
  'badge-orange': auth.role === 'admin',
  'badge-green': auth.role === 'recorder',
  'badge-gray': auth.role === 'user'
}))

onMounted(() => {
  form.displayName = auth.profile?.display_name || ''
  form.phone = auth.profile?.phone || ''
})

async function saveProfile() {
  saving.value = true
  try {
    await auth.updateProfile({ display_name: form.displayName, phone: form.phone })
    saveMsg.value = '✅ 保存成功'
    setTimeout(() => { saveMsg.value = '' }, 2000)
  } catch (e) {
    saveMsg.value = '❌ 保存失败：' + e.message
  } finally {
    saving.value = false
  }
}

async function handleChangePassword() {
  changingPwd.value = true
  pwdMsg.value = ''
  try {
    await auth.changePassword(pwdForm.oldPassword, pwdForm.newPassword)
    pwdMsg.value = '✅ 密码修改成功'
    pwdForm.oldPassword = ''
    pwdForm.newPassword = ''
    setTimeout(() => { pwdMsg.value = '' }, 2000)
  } catch (e) {
    const msg = e.message || ''
    pwdMsg.value = msg.includes('原密码') ? '❌ 原密码错误' : '❌ ' + msg
  } finally {
    changingPwd.value = false
  }
}

async function handleSignOut() {
  await auth.signOut()
  router.push('/')
}
</script>
