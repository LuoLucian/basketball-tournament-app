import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/utils/supabase'

const AUTH_KEY = 'basketball_auth_user'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const profile = ref(null)
  const loading = ref(true)

  const isLoggedIn = computed(() => !!user.value)
  const role = computed(() => profile.value?.role || 'user')
  const isSuperAdmin = computed(() => role.value === 'super_admin')
  const isAdmin = computed(() => ['super_admin', 'admin'].includes(role.value))
  const isRecorder = computed(() => role.value === 'recorder')

  // 初始化：从 localStorage 恢复登录状态
  async function init() {
    loading.value = true
    try {
      // 从 localStorage 恢复
      const saved = localStorage.getItem(AUTH_KEY)
      if (saved) {
        try {
          const parsed = JSON.parse(saved)
          user.value = parsed
          // 从数据库获取最新 profile
          const { data } = await supabase
            .from('profiles')
            .select('id, username, display_name, avatar_url, role, phone, jersey_no, is_active, created_at, updated_at')
            .eq('id', parsed.id)
            .single()
          if (data) {
            profile.value = data
          } else {
            // profile 不存在，清除登录状态
            clearAuth()
          }
        } catch {
          clearAuth()
        }
      }
    } finally {
      loading.value = false
    }
  }

  function clearAuth() {
    user.value = null
    profile.value = null
    localStorage.removeItem(AUTH_KEY)
  }

  // 保存登录状态
  function saveAuth(userInfo) {
    localStorage.setItem(AUTH_KEY, JSON.stringify(userInfo))
  }

  // 用户名密码登录
  async function signIn(username, password) {
    const { data, error } = await supabase.rpc('login_by_username', {
      p_username: username,
      p_password: password
    })
    if (error) throw error

    // 保存登录信息（data 是 RPC 返回的 JSONB）
    const userInfo = {
      id: data.id,
      username: data.username,
      display_name: data.display_name,
      role: data.role,
      avatar_url: data.avatar_url
    }
    user.value = userInfo
    profile.value = { ...userInfo }
    saveAuth(userInfo)

    return data
  }

  // 超管创建新用户（用户名+密码模式）
  async function createUser({ username, password, displayName, role = 'user' }) {
    const { data, error } = await supabase.rpc('create_user', {
      p_username: username,
      p_password: password,
      p_display_name: displayName,
      p_role: role
    })
    if (error) throw error
    return data
  }

  // 超管重置用户密码
  async function resetUserPassword(username, newPassword) {
    const { data, error } = await supabase.rpc('reset_user_password', {
      p_username: username,
      p_new_password: newPassword
    })
    if (error) throw error
    return data
  }

  // 超管删除用户
  async function deleteUser(username) {
    const { data, error } = await supabase.rpc('delete_user', {
      p_username: username
    })
    if (error) throw error
    return data
  }

  // 修改自己的密码
  async function changePassword(oldPassword, newPassword) {
    const { data, error } = await supabase.rpc('change_my_password', {
      p_old_password: oldPassword,
      p_new_password: newPassword
    })
    if (error) throw error
    return data
  }

  // 登出
  function signOut() {
    clearAuth()
  }

  // 更新个人资料
  async function updateProfile(updates) {
    if (!user.value) return
    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.value.id)
      .select()
      .single()
    if (error) throw error
    profile.value = { ...profile.value, ...data }
    // 同步更新 user ref
    user.value = { ...user.value, ...updates }
    saveAuth(user.value)
    return data
  }

  return {
    user,
    profile,
    loading,
    isLoggedIn,
    role,
    isSuperAdmin,
    isAdmin,
    isRecorder,
    init,
    signIn,
    createUser,
    resetUserPassword,
    deleteUser,
    changePassword,
    signOut,
    updateProfile
  }
})
