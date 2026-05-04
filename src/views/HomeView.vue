<template>
  <div class="page-container">
    <!-- 欢迎横幅 -->
    <div class="relative rounded-2xl p-5 mb-6 text-white overflow-hidden
                bg-gradient-to-r from-primary-700 via-primary-600 to-accent-600">
      <div class="absolute right-0 top-0 w-48 h-48 bg-white/5 rounded-full -translate-y-16 translate-x-12"></div>
      <div class="absolute right-16 bottom-0 w-32 h-32 bg-white/5 rounded-full translate-y-10"></div>
      <div class="absolute left-1/2 top-0 w-24 h-24 bg-accent-400/10 rounded-full -translate-y-12"></div>
      <svg class="absolute right-4 bottom-4 w-20 h-20 opacity-10" viewBox="0 0 32 32" fill="none">
        <circle cx="16" cy="16" r="14" stroke="white" stroke-width="1.5"/>
        <line x1="16" y1="2" x2="16" y2="30" stroke="white" stroke-width="1"/>
        <path d="M2 16 Q8 10 16 16 Q24 22 30 16" stroke="white" stroke-width="1" fill="none"/>
      </svg>

      <div class="relative z-10">
        <p class="text-white/60 text-sm mb-1">{{ auth.isLoggedIn ? `你好，${auth.profile?.display_name || '球员'}` : '欢迎来到' }}</p>
        <h1 class="text-2xl font-black mb-3 text-glow-blue">德泰科技园篮球赛事</h1>
        <div class="flex gap-2 flex-wrap">
          <router-link to="/games"
            class="px-4 py-1.5 rounded-xl text-sm font-semibold bg-white/15 text-white
                   hover:bg-white/25 border border-white/20 backdrop-blur-sm transition-all duration-200">
            查看赛事
          </router-link>
          <router-link v-if="auth.isAdmin" to="/games/create"
            class="px-4 py-1.5 rounded-xl text-sm font-semibold bg-white text-primary-700
                   hover:bg-white/90 shadow-lg transition-all duration-200">
            ＋ 创建赛事
          </router-link>
          <router-link v-if="!auth.isLoggedIn" to="/login"
            class="px-4 py-1.5 rounded-xl text-sm font-semibold bg-white/15 text-white
                   hover:bg-white/25 border border-white/20 backdrop-blur-sm transition-all duration-200">
            管理员登录
          </router-link>
        </div>
      </div>
    </div>

    <!-- 排行榜快捷入口 -->
    <router-link to="/stats/leaderboard"
      class="block rounded-2xl p-4 mb-5 bg-dark-800/60 border border-dark-700/40
             hover:border-primary-500/40 hover:bg-dark-800/80 transition-all duration-200 group">
      <div class="flex items-center gap-4">
        <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-yellow-500/20 to-orange-500/20
                    border border-yellow-500/20 flex items-center justify-center text-lg flex-shrink-0">
          🏆
        </div>
        <div class="flex-1 min-w-0">
          <h3 class="text-sm font-semibold text-white group-hover:text-primary-300 transition-colors">排行榜</h3>
          <p class="text-xs text-dark-500 mt-0.5">查看得分、篮板、助攻等数据排名</p>
        </div>
        <svg class="w-4 h-4 text-dark-600 group-hover:text-dark-400 transition-colors flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </div>
    </router-link>

    <!-- 比赛预告（核心区域） -->
    <div class="mb-6">
      <div class="flex items-center justify-between mb-3">
        <h2 class="section-title">
          <span class="inline-block w-2 h-2 rounded-full bg-accent-400 mr-1"></span>
          比赛预告
        </h2>
        <router-link to="/games" class="text-sm text-primary-400 hover:text-primary-300 transition-colors">全部赛事 →</router-link>
      </div>

      <!-- 有预告 -->
      <div v-if="upcomingGames.length > 0" class="space-y-2">
        <router-link v-for="(game, idx) in upcomingGames" :key="game.id"
          :to="`/games/${game.id}`"
          class="card card-body flex items-center gap-4 group
                 hover:border-accent-500/30 hover:shadow-neon-orange transition-all duration-300 animate-fade-in"
          :style="{ animationDelay: `${idx * 80}ms` }"
        >
          <!-- 时间 -->
          <div class="flex-shrink-0 text-center w-14">
            <p class="text-lg font-bold text-accent-400">{{ fmtUpcomingDay(game.scheduled_at) }}</p>
            <p class="text-xs text-dark-500">{{ fmtUpcomingMonth(game.scheduled_at) }}</p>
          </div>
          <!-- 对阵 -->
          <div class="flex-1 min-w-0">
            <div v-if="game.home_team && game.away_team" class="flex items-center gap-3">
              <span class="font-semibold text-sm truncate flex-1" :style="{ color: game.home_team.color }">
                {{ game.home_team.short_name || game.home_team.name }}
              </span>
              <span class="text-dark-600 font-bold text-sm px-2">VS</span>
              <span class="font-semibold text-sm truncate flex-1 text-right" :style="{ color: game.away_team.color }">
                {{ game.away_team.short_name || game.away_team.name }}
              </span>
            </div>
            <div v-else class="text-sm font-medium text-dark-200 truncate">{{ game.title }}</div>
            <div class="flex items-center gap-2 mt-1">
              <span class="badge text-xs badge-gray">{{ fmtUpcomingTime(game.scheduled_at) }}</span>
              <span class="badge text-xs" :class="game.game_type === 'entertainment' ? 'badge-orange' : 'badge-blue'">
                {{ game.game_type === 'entertainment' ? '娱乐制' : '正式制' }}
              </span>
              <span v-if="game.venue" class="text-xs text-dark-500 truncate">{{ game.venue }}</span>
            </div>
          </div>
          <!-- 箭头 -->
          <svg class="w-4 h-4 text-dark-600 group-hover:text-accent-400 flex-shrink-0 transition-all duration-200 group-hover:translate-x-0.5"
            fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </router-link>
      </div>

      <!-- 无预告 -->
      <div v-else class="card card-body text-center py-12">
        <svg class="w-16 h-16 text-dark-600 mx-auto mb-3" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.5">
          <rect x="10" y="10" width="44" height="36" rx="4" opacity="0.3"/>
          <line x1="10" y1="20" x2="54" y2="20" opacity="0.2"/>
          <rect x="14" y="24" width="12" height="6" rx="2" opacity="0.2"/>
          <rect x="30" y="24" width="12" height="6" rx="2" opacity="0.2"/>
          <circle cx="32" cy="48" r="4" opacity="0.3"/>
          <path d="M20 52 L44 52" opacity="0.15"/>
        </svg>
        <p class="text-dark-400 text-sm mb-1">暂无比赛预告</p>
        <p class="text-dark-600 text-xs">有新的赛事安排后会在这里展示</p>
      </div>
    </div>

    <!-- 进行中的赛事 -->
    <div v-if="activeGames.length > 0" class="mb-6">
      <div class="flex items-center justify-between mb-3">
        <h2 class="section-title">
          <span class="inline-block w-2 h-2 rounded-full bg-success animate-pulse mr-1"></span>
          正在进行
        </h2>
        <router-link to="/games" class="text-sm text-primary-400 hover:text-primary-300 transition-colors">全部 →</router-link>
      </div>
      <div class="space-y-2">
        <GameCard v-for="g in activeGames" :key="g.id" :game="g" />
      </div>
    </div>

    <!-- 统计概览 -->
    <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
      <div v-for="(stat, idx) in overviewStats" :key="stat.label"
        class="stat-card animate-fade-in"
        :style="{ animationDelay: `${idx * 80}ms` }"
      >
        <div class="w-10 h-10 rounded-xl mx-auto mb-2 flex items-center justify-center"
          :style="{ backgroundColor: stat.bgColor }">
          <span class="text-lg">{{ stat.icon }}</span>
        </div>
        <div class="text-2xl font-black text-gradient-accent">{{ stat.value }}</div>
        <div class="text-xs text-dark-500 mt-0.5">{{ stat.label }}</div>
      </div>
    </div>

    <!-- 最近结束赛事 -->
    <div v-if="recentGames.length > 0" class="mb-6">
      <div class="flex items-center justify-between mb-3">
        <h2 class="section-title">最近赛事</h2>
        <router-link to="/games" class="text-sm text-primary-400 hover:text-primary-300 transition-colors">全部 →</router-link>
      </div>
      <div class="space-y-2">
        <GameCard v-for="g in recentGames" :key="g.id" :game="g" />
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import GameCard from '@/components/game/GameCard.vue'

const auth = useAuthStore()
const games = ref([])
const stats = ref({ totalGames: 0, totalPlayers: 0, totalTeams: 0 })

// 比赛预告：pending 状态，按 scheduled_at 升序，有时间的排前面，没时间的排后面
const upcomingGames = computed(() => {
  const pending = games.value.filter(g => g.status === 'pending')
  return pending.sort((a, b) => {
    // 有 scheduled_at 的排前面
    if (a.scheduled_at && !b.scheduled_at) return -1
    if (!a.scheduled_at && b.scheduled_at) return 1
    if (a.scheduled_at && b.scheduled_at) return new Date(a.scheduled_at) - new Date(b.scheduled_at)
    return 0
  })
})

const activeGames = computed(() => games.value.filter(g => g.status === 'active' || g.status === 'halftime'))
const recentGames = computed(() => games.value.filter(g => g.status === 'finished').slice(0, 4))

const overviewStats = computed(() => [
  { icon: '🏀', label: '总场次', value: stats.value.totalGames, bgColor: 'rgba(59,130,246,0.15)' },
  { icon: '👥', label: '球员人数', value: stats.value.totalPlayers, bgColor: 'rgba(34,197,94,0.15)' },
  { icon: '🏅', label: '球队数量', value: stats.value.totalTeams, bgColor: 'rgba(249,115,22,0.15)' },
  { icon: '📋', label: '待开赛', value: upcomingGames.value.length, bgColor: 'rgba(234,179,8,0.15)' }
])

// 预告时间格式化
function fmtUpcomingDay(dateStr) {
  if (!dateStr) return '?'
  const d = new Date(dateStr)
  return String(d.getDate()).padStart(2, '0')
}
function fmtUpcomingMonth(dateStr) {
  if (!dateStr) return ''
  const d = new Date(dateStr)
  const months = ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月']
  const weekdays = ['周日','周一','周二','周三','周四','周五','周六']
  return months[d.getMonth()] + ' ' + weekdays[d.getDay()]
}
function fmtUpcomingTime(dateStr) {
  if (!dateStr) return '待定'
  const d = new Date(dateStr)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

onMounted(async () => {
  const { data: gamesData } = await supabase
    .from('games')
    .select(`
      id, title, game_type, status, home_score, away_score, scheduled_at, started_at, venue,
      home_team:home_team_id(id, name, short_name, color),
      away_team:away_team_id(id, name, short_name, color)
    `)
    .order('created_at', { ascending: false })
    .limit(20)
  if (gamesData) games.value = gamesData

  const [{ count: gamesCount }, { count: playersCount }, { count: teamsCount }] = await Promise.all([
    supabase.from('games').select('*', { count: 'exact', head: true }),
    supabase.from('players').select('*', { count: 'exact', head: true }).eq('is_active', true),
    supabase.from('teams').select('*', { count: 'exact', head: true }).eq('is_active', true)
  ])
  stats.value = {
    totalGames: gamesCount || 0,
    totalPlayers: playersCount || 0,
    totalTeams: teamsCount || 0
  }
})
</script>
