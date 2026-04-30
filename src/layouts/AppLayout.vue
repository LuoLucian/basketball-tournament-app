<template>
  <div class="min-h-screen bg-dark-900 flex flex-col">

    <!-- 顶部导航栏 - 毛玻璃暗色 -->
    <header class="glass-nav sticky top-0 z-40">
      <div class="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
        <!-- Logo -->
        <router-link to="/" class="flex items-center gap-3 font-bold text-white group">
          <div class="relative">
            <!-- 图片 Logo -->
            <div v-if="logoLoaded" class="w-12 h-12 rounded-full overflow-hidden bg-white
                     border-2 border-primary-500/50 shadow-neon-blue
                     group-hover:shadow-neon-blue-lg transition-all duration-300">
              <img src="/德泰LOGO2.png" alt="德泰篮球" class="w-full h-full object-cover"
                @error="logoLoaded = false" />
            </div>
            <!-- 降级：文字 Logo -->
            <div v-else class="w-12 h-12 bg-gradient-to-br from-primary-500 to-primary-700 rounded-full flex items-center justify-center
                        border-2 border-primary-400/50 shadow-neon-blue group-hover:shadow-neon-blue-lg transition-all duration-300">
              <span class="text-white font-black text-base tracking-tighter">德泰</span>
            </div>
            <!-- 发光辉光 -->
            <div class="absolute -inset-1.5 rounded-full bg-gradient-to-br from-primary-500/30 to-primary-700/20 blur-md -z-10
                        group-hover:from-primary-500/40 group-hover:to-primary-700/30 transition-all duration-300"></div>
          </div>
          <span class="hidden sm:inline bg-gradient-to-r from-white to-dark-300 bg-clip-text text-transparent text-lg tracking-wide">德泰篮球赛事</span>
        </router-link>

        <!-- 桌面端导航 -->
        <nav class="hidden md:flex items-center gap-1">
          <router-link v-for="item in navItems" :key="item.to"
            :to="item.to"
            class="relative px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200"
            :class="isActive(item.to) ? 'text-primary-400' : 'text-dark-400 hover:text-white hover:bg-dark-800/50'"
          >
            {{ item.label }}
            <span v-if="isActive(item.to)"
              class="absolute bottom-0 left-1/2 -translate-x-1/2 w-5 h-0.5 bg-primary-500 rounded-full shadow-neon-blue"></span>
          </router-link>
        </nav>

        <!-- 右侧用户区 -->
        <div class="flex items-center gap-2">
          <!-- 未登录 -->
          <template v-if="!auth.isLoggedIn">
            <router-link to="/login"
              class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-semibold
                     text-primary-400 hover:text-white bg-dark-800 hover:bg-dark-700
                     border border-dark-600 hover:border-primary-600/30
                     transition-all duration-200 hover:shadow-neon-blue"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"/>
              </svg>
              <span class="hidden sm:inline">登录</span>
            </router-link>
          </template>

          <!-- 已登录 -->
          <template v-else>
            <span class="hidden sm:inline badge"
              :class="{
                'badge-blue': auth.isSuperAdmin,
                'badge-orange': auth.role === 'admin',
                'badge-green': auth.role === 'recorder',
                'badge-gray': auth.role === 'user'
              }"
            >{{ ROLE_LABELS[auth.role] }}</span>

            <div class="relative" ref="dropdownRef">
              <button @click="showDropdown = !showDropdown"
                class="flex items-center gap-1.5 p-1 rounded-xl hover:bg-dark-800 transition-all duration-200"
              >
                <div class="w-8 h-8 player-avatar text-sm"
                  :style="auth.profile?.avatar_url ? '' : `background-color: ${getAvatarColor(auth.profile?.display_name)}`"
                >
                  <img v-if="auth.profile?.avatar_url" :src="auth.profile.avatar_url" class="w-8 h-8 rounded-full object-cover" />
                  <span v-else>{{ getInitials(auth.profile?.display_name || auth.user?.username) }}</span>
                </div>
                <svg class="w-4 h-4 text-dark-500 transition-transform duration-200"
                  :class="showDropdown ? 'rotate-180' : ''"
                  fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                </svg>
              </button>

              <!-- 下拉菜单 - 暗色毛玻璃 -->
              <Transition name="dropdown">
                <div v-if="showDropdown"
                  class="absolute right-0 mt-2 w-48 bg-dark-850/95 backdrop-blur-xl rounded-2xl
                         border border-dark-700/50 shadow-glass py-1 z-50"
                >
                  <div class="px-4 py-2.5 border-b border-dark-700/50">
                    <p class="text-sm font-semibold text-white truncate">{{ auth.profile?.display_name || '用户' }}</p>
                    <p class="text-xs text-dark-500 truncate">{{ auth.user?.username }}</p>
                  </div>
                  <router-link to="/profile" @click="showDropdown = false"
                    class="flex items-center gap-2.5 px-4 py-2.5 text-sm text-dark-300 hover:text-white hover:bg-dark-800/50 transition-colors"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                    个人主页
                  </router-link>
                  <router-link v-if="auth.isAdmin" to="/admin" @click="showDropdown = false"
                    class="flex items-center gap-2.5 px-4 py-2.5 text-sm text-dark-300 hover:text-white hover:bg-dark-800/50 transition-colors"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                    系统管理
                  </router-link>
                  <div class="border-t border-dark-700/50 my-1"></div>
                  <button @click="handleSignOut"
                    class="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm text-danger-light hover:bg-danger/10 transition-colors"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
                    退出登录
                  </button>
                </div>
              </Transition>
            </div>
          </template>
        </div>
      </div>
    </header>

    <!-- 主内容区 -->
    <main class="flex-1 pb-20 md:pb-6">
      <router-view v-slot="{ Component }">
        <Transition name="page" mode="out-in">
          <component :is="Component" />
        </Transition>
      </router-view>
    </main>

    <!-- 移动端底部导航 - 暗色霓虹 -->
    <nav class="md:hidden fixed bottom-0 left-0 right-0 z-40 bottom-nav">
      <div class="flex items-stretch">
        <router-link v-for="item in mobileNavItems" :key="item.to"
          :to="item.to"
          class="flex-1 flex flex-col items-center justify-center py-2 gap-0.5 transition-all duration-200"
          :class="isActive(item.to) ? 'text-primary-400' : 'text-dark-500'"
        >
          <component :is="item.icon" class="w-5 h-5" />
          <span class="text-[10px] font-medium">{{ item.label }}</span>
          <span v-if="isActive(item.to)"
            class="absolute -top-px left-1/2 -translate-x-1/2 w-8 h-0.5 bg-primary-500 rounded-full"></span>
        </router-link>
      </div>
    </nav>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ROLE_LABELS, getInitials } from '@/utils/helpers'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const showDropdown = ref(false)
const dropdownRef = ref(null)
const logoLoaded = ref(true) // 尝试加载图片，失败后降级为文字

const navItems = [
  { to: '/', label: '首页' },
  { to: '/games', label: '赛事' },
  { to: '/teams', label: '球队' },
  { to: '/stats/leaderboard', label: '排行榜' },
  { to: '/players', label: '球员' }
]

const mobileNavItems = [
  { to: '/', label: '首页', icon: HomeIcon },
  { to: '/games', label: '赛事', icon: TrophyIcon },
  { to: '/teams', label: '球队', icon: TeamIcon },
  { to: '/players', label: '球员', icon: UsersIcon },
  { to: '/profile', label: '我的', icon: UserIcon }
]

function isActive(path) {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}

function getAvatarColor(name) {
  const colors = ['#3b82f6', '#f97316', '#22c55e', '#8b5cf6', '#ec4899', '#06b6d4']
  if (!name) return colors[0]
  return colors[name.charCodeAt(0) % colors.length]
}

async function handleSignOut() {
  showDropdown.value = false
  await auth.signOut()
  router.push('/')
}

// 点击外部关闭下拉
function handleClickOutside(e) {
  if (dropdownRef.value && !dropdownRef.value.contains(e.target)) {
    showDropdown.value = false
  }
}
onMounted(() => document.addEventListener('click', handleClickOutside))
onUnmounted(() => document.removeEventListener('click', handleClickOutside))
</script>

<!-- 图标组件 -->
<script>
import { h } from 'vue'
function HomeIcon(props, { attrs }) {
  return h('svg', { ...attrs, fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24' }, [
    h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6' })
  ])
}
function TrophyIcon(props, { attrs }) {
  return h('svg', { ...attrs, fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24' }, [
    h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z' })
  ])
}
function ChartIcon(props, { attrs }) {
  return h('svg', { ...attrs, fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24' }, [
    h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z' })
  ])
}
function UsersIcon(props, { attrs }) {
  return h('svg', { ...attrs, fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24' }, [
    h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z' })
  ])
}
function TeamIcon(props, { attrs }) {
  return h('svg', { ...attrs, fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24' }, [
    h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z' })
  ])
}
function UserIcon(props, { attrs }) {
  return h('svg', { ...attrs, fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24' }, [
    h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2', d: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z' })
  ])
}
</script>

<style scoped>
.dropdown-enter-active, .dropdown-leave-active { transition: all 0.2s ease; }
.dropdown-enter-from, .dropdown-leave-to { opacity: 0; transform: translateY(-4px) scale(0.97); }
</style>
