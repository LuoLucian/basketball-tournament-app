<template>
  <div class="page-container">
    <h1 class="page-title">系统监控</h1>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      <div class="card p-4">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-lg bg-primary-600/20 flex items-center justify-center">
            <svg class="w-5 h-5 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
            </svg>
          </div>
          <div>
            <p class="text-2xl font-bold text-white">{{ stats.totalUsers }}</p>
            <p class="text-xs text-dark-500">总用户数</p>
          </div>
        </div>
      </div>

      <div class="card p-4">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-lg bg-accent-600/20 flex items-center justify-center">
            <svg class="w-5 h-5 text-accent-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
            </svg>
          </div>
          <div>
            <p class="text-2xl font-bold text-white">{{ stats.activeGames }}</p>
            <p class="text-xs text-dark-500">进行中比赛</p>
          </div>
        </div>
      </div>

      <div class="card p-4">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-lg bg-success/20 flex items-center justify-center">
            <svg class="w-5 h-5 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </div>
          <div>
            <p class="text-2xl font-bold text-white">{{ stats.totalPlayers }}</p>
            <p class="text-xs text-dark-500">球员总数</p>
          </div>
        </div>
      </div>

      <div class="card p-4">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-lg bg-warning/20 flex items-center justify-center">
            <svg class="w-5 h-5 text-warning" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
          </div>
          <div>
            <p class="text-2xl font-bold text-white">{{ stats.todayGames }}</p>
            <p class="text-xs text-dark-500">今日比赛</p>
          </div>
        </div>
      </div>
    </div>

    <!-- 活跃用户趋势 -->
    <div class="card p-5 mb-5">
      <h2 class="font-semibold text-white mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
        </svg>
        用户活跃统计
      </h2>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="text-center p-3 bg-dark-800/50 rounded-lg">
          <p class="text-3xl font-bold text-primary-400">{{ stats.todayUsers }}</p>
          <p class="text-xs text-dark-500 mt-1">今日活跃</p>
        </div>
        <div class="text-center p-3 bg-dark-800/50 rounded-lg">
          <p class="text-3xl font-bold text-accent-400">{{ stats.weekUsers }}</p>
          <p class="text-xs text-dark-500 mt-1">本周活跃</p>
        </div>
        <div class="text-center p-3 bg-dark-800/50 rounded-lg">
          <p class="text-3xl font-bold text-success">{{ stats.monthUsers }}</p>
          <p class="text-xs text-dark-500 mt-1">本月活跃</p>
        </div>
        <div class="text-center p-3 bg-dark-800/50 rounded-lg">
          <p class="text-3xl font-bold text-warning">{{ stats.totalTeams }}</p>
          <p class="text-xs text-dark-500 mt-1">球队总数</p>
        </div>
      </div>
    </div>

    <!-- 最近活跃用户 -->
    <div class="card p-5">
      <h2 class="font-semibold text-white mb-4 flex items-center gap-2">
        <svg class="w-4 h-4 text-accent-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        最近活跃用户
      </h2>
      
      <div v-if="loading" class="text-center py-8">
        <svg class="w-8 h-8 text-primary-400 animate-spin mx-auto" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
        </svg>
        <p class="text-dark-500 text-sm mt-2">加载中...</p>
      </div>

      <div v-else-if="recentUsers.length === 0" class="text-center py-8 text-dark-500">
        暂无数据
      </div>

      <div v-else class="space-y-2">
        <div v-for="user in recentUsers" :key="user.id" 
             class="flex items-center justify-between p-3 bg-dark-800/50 rounded-lg hover:bg-dark-800 transition-colors">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 rounded-full bg-primary-600/30 flex items-center justify-center">
              <span class="text-sm font-medium text-primary-400">{{ user.display_name?.charAt(0) || 'U' }}</span>
            </div>
            <div>
              <p class="text-sm font-medium text-white">{{ user.display_name || user.username }}</p>
              <p class="text-xs text-dark-500">{{ user.username }} · {{ user.role }}</p>
            </div>
          </div>
          <div class="text-right">
            <p class="text-xs text-dark-500">最后活跃</p>
            <p class="text-xs text-dark-400">{{ formatTime(user.updated_at) }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- 刷新按钮 -->
    <div class="mt-5 flex justify-center">
      <button @click="loadStats" :disabled="loading"
              class="btn-secondary flex items-center gap-2">
        <svg class="w-4 h-4" :class="{ 'animate-spin': loading }" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
        刷新数据
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/utils/supabase'

const loading = ref(true)
const stats = ref({
  totalUsers: 0,
  activeGames: 0,
  totalPlayers: 0,
  todayGames: 0,
  todayUsers: 0,
  weekUsers: 0,
  monthUsers: 0,
  totalTeams: 0
})
const recentUsers = ref([])

async function loadStats() {
  loading.value = true
  try {
    const now = new Date()
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString()
    const weekStart = new Date(now - 7 * 24 * 60 * 60 * 1000).toISOString()
    const monthStart = new Date(now - 30 * 24 * 60 * 60 * 1000).toISOString()

    // 并行查询所有统计
    const [
      usersRes,
      todayUsersRes,
      weekUsersRes,
      monthUsersRes,
      gamesRes,
      todayGamesRes,
      playersRes,
      teamsRes,
      recentUsersRes
    ] = await Promise.all([
      // 总用户数
      supabase.from('profiles').select('id', { count: 'exact', head: true }),
      // 今日活跃用户（updated_at 在今天）
      supabase.from('profiles').select('id', { count: 'exact', head: true }).gte('updated_at', todayStart),
      // 本周活跃用户
      supabase.from('profiles').select('id', { count: 'exact', head: true }).gte('updated_at', weekStart),
      // 本月活跃用户
      supabase.from('profiles').select('id', { count: 'exact', head: true }).gte('updated_at', monthStart),
      // 进行中比赛
      supabase.from('games').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      // 今日比赛
      supabase.from('games').select('id', { count: 'exact', head: true }).gte('created_at', todayStart),
      // 球员总数
      supabase.from('players').select('id', { count: 'exact', head: true }).eq('is_active', true),
      // 球队总数
      supabase.from('teams').select('id', { count: 'exact', head: true }).eq('is_active', true),
      // 最近活跃用户
      supabase.from('profiles')
        .select('id, username, display_name, role, updated_at')
        .order('updated_at', { ascending: false })
        .limit(10)
    ])

    stats.value = {
      totalUsers: usersRes.count || 0,
      todayUsers: todayUsersRes.count || 0,
      weekUsers: weekUsersRes.count || 0,
      monthUsers: monthUsersRes.count || 0,
      activeGames: gamesRes.count || 0,
      todayGames: todayGamesRes.count || 0,
      totalPlayers: playersRes.count || 0,
      totalTeams: teamsRes.count || 0
    }

    recentUsers.value = recentUsersRes.data || []
  } catch (e) {
    console.error('加载统计失败:', e)
  } finally {
    loading.value = false
  }
}

function formatTime(isoString) {
  if (!isoString) return '未知'
  const date = new Date(isoString)
  const now = new Date()
  const diff = now - date
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)
  
  if (minutes < 1) return '刚刚'
  if (minutes < 60) return `${minutes}分钟前`
  if (hours < 24) return `${hours}小时前`
  if (days < 7) return `${days}天前`
  return date.toLocaleDateString('zh-CN')
}

onMounted(() => {
  loadStats()
  // 每30秒自动刷新
  setInterval(loadStats, 30000)
})
</script>
