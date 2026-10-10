<template>
  <div class="page-container">
    <!-- Hero 区域 - 简洁大气 -->
    <div class="relative mb-5 animate-fade-in-up">
      <!-- 背景图 + 柔和遮罩 -->
      <div class="absolute inset-0 -mx-4 sm:-mx-6 lg:-mx-8 rounded-2xl overflow-hidden">
        <div class="absolute inset-0 bg-cover bg-center"
          :style="{ backgroundImage: `url(${heroBg})` }">
        </div>
        <!-- 柔和渐变遮罩 -->
        <div class="absolute inset-0 bg-gradient-to-b from-dark-900/60 via-dark-900/80 to-dark-900"></div>
        <!-- 粒子光效装饰 -->
        <div class="absolute inset-0 overflow-hidden pointer-events-none">
          <!-- 游走光点 -->
          <div class="absolute w-1 h-1 rounded-full bg-blue-400/50 animate-particle-1" style="top:20%;left:15%"></div>
          <div class="absolute w-1.5 h-1.5 rounded-full bg-purple-400/40 animate-particle-2" style="top:35%;right:25%"></div>
          <div class="absolute w-1 h-1 rounded-full bg-orange-400/40 animate-particle-3" style="bottom:30%;left:30%"></div>
          <div class="absolute w-0.5 h-0.5 rounded-full bg-blue-300/60 animate-particle-4" style="top:50%;right:15%"></div>
          <div class="absolute w-1 h-1 rounded-full bg-blue-400/30 animate-particle-5" style="bottom:40%;right:40%"></div>
          <div class="absolute w-0.5 h-0.5 rounded-full bg-purple-300/50 animate-particle-6" style="top:15%;left:50%"></div>
          <!-- 光线扫过 -->
          <div class="absolute w-60 h-px bg-gradient-to-r from-transparent via-blue-400/35 to-transparent animate-light-sweep" style="top:20%"></div>
          <div class="absolute w-48 h-px bg-gradient-to-r from-transparent via-purple-400/25 to-transparent animate-light-sweep-reverse" style="top:45%"></div>
          <div class="absolute w-36 h-px bg-gradient-to-r from-transparent via-blue-300/20 to-transparent animate-light-sweep" style="top:70%; animation-delay:2s"></div>
          <div class="absolute w-24 h-[2px] bg-gradient-to-r from-transparent via-orange-400/20 to-transparent animate-light-sweep-reverse" style="top:10%; animation-delay:1.5s"></div>
          <div class="absolute w-32 h-[2px] bg-gradient-to-r from-transparent via-cyan-400/20 to-transparent animate-light-sweep" style="top:55%; animation-delay:3s"></div>
          <!-- 背景光晕呼吸灯（跟随图片发光处，与文字呼吸同节奏） -->
          <div class="absolute w-24 h-24 rounded-full bg-blue-400/15 blur-2xl animate-glow-breath-1" style="top:28%;left:35%"></div>
          <div class="absolute w-16 h-16 rounded-full bg-blue-500/15 blur-2xl animate-glow-breath-2" style="top:18%;left:12%"></div>
          <div class="absolute w-20 h-20 rounded-full bg-orange-400/12 blur-2xl animate-glow-breath-3" style="bottom:30%;right:22%"></div>
        </div>
      </div>

      <!-- 内容 - 全部左对齐 -->
      <div class="relative z-10 py-6 sm:py-8 lg:py-10">
        <div class="text-center lg:text-left">
          <!-- 标题区 -->
          <p class="text-white/50 text-xs tracking-[0.2em] uppercase mb-2 animate-fade-in">
            {{ auth.isLoggedIn ? 'Welcome Back' : 'Welcome to' }}
          </p>
          <h1 class="text-3xl sm:text-4xl lg:text-5xl font-black text-white tracking-tight mb-1 animate-slide-in-left text-glow-breath">
            德泰科技园
          </h1>
          <p class="text-xl sm:text-2xl lg:text-3xl font-black animate-gradient-flow"
             style="background: linear-gradient(90deg, #60a5fa, #a78bfa, #f97316, #60a5fa); background-size: 300% 100%; -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
            篮球赛事
          </p>

          <!-- 按钮组 - 左对齐 -->
          <div class="flex justify-center lg:justify-start gap-2.5 flex-wrap mt-4 animate-slide-in-up" style="animation-delay: 200ms">
            <router-link to="/games"
              class="px-5 py-2 rounded-full text-sm font-bold bg-white text-dark-900
                     hover:bg-white/90 shadow-lg shadow-white/20
                     transition-all duration-200 hover:scale-105 active:scale-95">
              查看赛事
            </router-link>
            <router-link v-if="auth.isAdmin" to="/games/create"
              class="px-5 py-2 rounded-full text-sm font-bold
                     bg-gradient-to-r from-primary-500 to-primary-600 text-white
                     hover:from-primary-400 hover:to-primary-500
                     shadow-lg shadow-primary-500/30
                     transition-all duration-200 hover:scale-105 active:scale-95">
              + 创建赛事
            </router-link>
            <router-link v-if="!auth.isLoggedIn" to="/login"
              class="px-5 py-2 rounded-full text-sm font-bold
                     bg-white/10 text-white border border-white/20
                     hover:bg-white/20 backdrop-blur-sm
                     transition-all duration-200 hover:scale-105 active:scale-95">
              登录
            </router-link>
            <router-link v-if="!auth.isLoggedIn" to="/register"
              class="px-5 py-2 rounded-full text-sm font-bold
                     bg-gradient-to-r from-accent-500 to-orange-500 text-white
                     hover:from-accent-400 hover:to-orange-400
                     shadow-lg shadow-accent-500/30
                     transition-all duration-200 hover:scale-105 active:scale-95">
              注册
            </router-link>
          </div>
        </div>
      </div>
    </div>

    <!-- ═══ 锦标赛专区入口（大横幅，最显眼）═══ -->
    <router-link to="/tournaments"
      class="relative block mb-5 rounded-2xl overflow-hidden animate-fade-in-up group
             border border-purple-500/50 hover:border-purple-400
             transition-all duration-300 hover:scale-[1.01] active:scale-[0.99]"
      style="animation-delay: 80ms"
    >
      <!-- 渐变背景 -->
      <div class="absolute inset-0 bg-gradient-to-r from-purple-700/40 via-indigo-700/30 to-amber-600/30
                  group-hover:from-purple-600/50 group-hover:via-indigo-600/40 group-hover:to-amber-500/40
                  transition-all duration-500"></div>
      <!-- 扫光效果 -->
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute w-40 h-full bg-gradient-to-r from-transparent via-white/10 to-transparent
                    animate-light-sweep -skew-x-12" style="animation-duration: 3.5s"></div>
      </div>
      <!-- 奖杯光晕呼吸 -->
      <div class="absolute w-28 h-28 rounded-full bg-amber-400/20 blur-2xl animate-glow-breath-1" style="left:16px;top:-20px"></div>

      <div class="relative z-10 flex items-center gap-4 px-5 py-4">
        <!-- 奖杯图标 -->
        <div class="w-14 h-14 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0
                    bg-gradient-to-br from-amber-500/30 to-purple-500/30 border border-amber-400/30
                    group-hover:scale-110 group-hover:rotate-6 transition-transform duration-300
                    drop-shadow-[0_0_12px_rgba(251,191,36,0.4)]">
          🏆
        </div>
        <!-- 文案 -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <h3 class="text-lg font-black text-white tracking-wide">锦标赛专区</h3>
            <span class="px-2 py-0.5 rounded-full text-[10px] font-bold
                         bg-gradient-to-r from-amber-500 to-orange-500 text-dark-900">LIVE</span>
          </div>
          <p class="text-xs text-purple-200/70 mt-0.5 truncate">
            {{ featuredTournament
              ? `${featuredTournament.name} · ${tStatusText(featuredTournament)} · ${featuredTournament.teamCount} 支球队`
              : '小组赛 · 淘汰赛 · 冠军之路，全程直播' }}
          </p>
        </div>
        <!-- 右侧信息 -->
        <div class="flex items-center gap-2 flex-shrink-0">
          <span v-if="featuredTournament" class="badge hidden sm:inline-flex" :class="tStatusClass(featuredTournament.status)">
            {{ tStatusText(featuredTournament) }}
          </span>
          <svg class="w-5 h-5 text-amber-400 group-hover:translate-x-1.5 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5l7 7-7 7"/>
          </svg>
        </div>
      </div>
    </router-link>

    <!-- ═══ 抽签阶段提醒（锦标赛待抽签时显示）═══ -->
    <router-link v-if="featuredTournament?.status === 'draft'"
      :to="`/tournaments/${featuredTournament.id}`"
      class="relative block mb-5 rounded-2xl overflow-hidden animate-fade-in-up group
             border border-amber-500/60 hover:border-amber-400
             transition-all duration-300 hover:scale-[1.01] active:scale-[0.99]"
      style="animation-delay: 120ms"
    >
      <div class="absolute inset-0 bg-gradient-to-r from-amber-600/35 via-orange-600/25 to-purple-600/25
                  group-hover:from-amber-500/45 group-hover:via-orange-500/35 group-hover:to-purple-500/35
                  transition-all duration-500"></div>
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute w-40 h-full bg-gradient-to-r from-transparent via-white/10 to-transparent
                    animate-light-sweep -skew-x-12" style="animation-duration: 3s"></div>
      </div>

      <div class="relative z-10 flex items-center gap-4 px-5 py-4">
        <div class="w-14 h-14 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0
                    bg-gradient-to-br from-amber-500/30 to-orange-500/30 border border-amber-400/40
                    group-hover:scale-110 group-hover:-rotate-6 transition-transform duration-300
                    drop-shadow-[0_0_12px_rgba(251,191,36,0.5)]">
          <span class="inline-block animate-bounce">🎲</span>
        </div>
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <h3 class="text-lg font-black text-white tracking-wide">抽签仪式进行中</h3>
            <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-400 text-dark-900 animate-pulse">待抽签</span>
          </div>
          <p class="text-xs text-amber-200/80 mt-0.5 truncate">
            {{ featuredTournament.name }} · 抽签进度 {{ featuredTournament.drawnCount ?? 0 }} / {{ featuredTournament.teamCount }}
          </p>
          <p class="text-[11px] text-dark-400 mt-0.5">仅球队管理员可为本队抽签 · 超管可代抽</p>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <span class="px-3 py-1.5 rounded-full text-xs font-bold bg-gradient-to-r from-amber-500 to-orange-500 text-dark-900
                       group-hover:scale-105 transition-transform">进入抽签</span>
          <svg class="w-5 h-5 text-amber-400 group-hover:translate-x-1.5 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5l7 7-7 7"/>
          </svg>
        </div>
      </div>
    </router-link>

    <!-- 排行榜入口 - 精美入口卡片 -->
    <router-link to="/stats/leaderboard"
      class="relative block mb-6 overflow-hidden rounded-2xl group animate-fade-in-up"
      style="animation-delay: 100ms">
      <!-- 渐变背景 -->
      <div class="absolute inset-0 bg-gradient-to-r from-amber-600/25 via-orange-600/15 to-yellow-500/20
                  group-hover:from-amber-600/35 group-hover:via-orange-600/20 group-hover:to-yellow-500/30
                  transition-all duration-500"></div>
      <!-- 顶部分割光 + 底部金色描边 -->
      <div class="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-amber-400/70 to-transparent"></div>
      <div class="absolute inset-0 rounded-2xl border border-amber-500/30 group-hover:border-amber-400/60 transition-colors duration-300"></div>
      <!-- 背景装饰光晕 -->
      <div class="absolute w-24 h-24 rounded-full bg-amber-400/15 blur-2xl group-hover:bg-amber-400/25 transition-all duration-500" style="left:-10px; top:-10px;"></div>

      <div class="relative z-10 flex items-center gap-4 px-5 py-4">
        <!-- 奖牌图标 -->
        <div class="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0
                    bg-gradient-to-br from-amber-500/30 to-orange-500/30 border border-amber-400/40
                    group-hover:scale-110 group-hover:-rotate-6 transition-transform duration-300
                    shadow-[0_0_16px_rgba(251,191,36,0.25)]">
          <svg class="w-7 h-7 text-amber-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 15a5 5 0 1 0 0-10 5 5 0 0 0 0 10z"/>
            <path stroke-linecap="round" stroke-linejoin="round" d="m8.5 14-1.5 7 5-3 5 3-1.5-7"/>
          </svg>
        </div>
        <!-- 文案 -->
        <div class="flex-1 min-w-0">
          <h3 class="text-base font-black text-white flex items-center gap-2">
            数据排行榜
            <span class="px-1.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/20 text-amber-300 border border-amber-500/40 flex-shrink-0">TOP</span>
          </h3>
          <p class="text-xs text-dark-400 mt-0.5 truncate">得分 · 篮板 · 助攻 · 抢断 · 盖帽</p>
        </div>
        <!-- 箭头 -->
        <div class="flex-shrink-0">
          <svg class="w-5 h-5 text-amber-500/70 group-hover:text-amber-400 group-hover:translate-x-1.5 transition-all duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M9 5l7 7-7 7"/>
          </svg>
        </div>
      </div>
    </router-link>

    <!-- 进行中的赛事（最重要，放最前面） -->
    <div v-if="activeGames.length > 0" class="mb-6 animate-fade-in-up" style="animation-delay: 200ms">
      <div class="flex items-center justify-between mb-3">
        <h2 class="section-title">
          <span class="inline-block w-2 h-2 rounded-full bg-success animate-pulse mr-1"></span>
          正在进行
        </h2>
        <router-link to="/games" class="text-sm text-primary-400 hover:text-primary-300 transition-colors">全部 →</router-link>
      </div>
      <div class="space-y-3">
        <GameCard v-for="g in activeGames" :key="g.id" :game="g" />
      </div>
    </div>

    <!-- 比赛预告（缩小显示） -->
    <div v-if="upcomingGames.length > 0" class="mb-6 animate-fade-in-up" style="animation-delay: 300ms">
      <div class="flex items-center justify-between mb-3">
        <h2 class="section-title">
          <span class="inline-block w-2 h-2 rounded-full bg-accent-400 mr-1"></span>
          比赛预告
        </h2>
        <router-link to="/games" class="text-sm text-primary-400 hover:text-primary-300 transition-colors">全部 →</router-link>
      </div>

      <!-- 简化显示，最多3条 -->
      <div class="space-y-2">
        <router-link v-for="(game, idx) in upcomingGames.slice(0, 3)" :key="game.id"
          :to="`/games/${game.id}`"
          class="glass-card-light flex items-center gap-3 group p-4
                 hover-glow-orange transition-all duration-300"
        >
          <!-- 时间 -->
          <div class="flex-shrink-0 text-center w-14">
            <p class="text-xl font-black text-accent-400">{{ fmtUpcomingDay(game.scheduled_at) }}</p>
            <p class="text-[10px] text-dark-500 font-medium">{{ fmtUpcomingMonth(game.scheduled_at) }}</p>
          </div>
          <!-- 对阵 -->
          <div class="flex-1 min-w-0">
            <div v-if="game.home_team && game.away_team" class="flex items-center gap-3">
              <span class="font-semibold text-sm truncate flex-1" :style="{ color: game.home_team.color }">
                {{ game.home_team.short_name || game.home_team.name }}
              </span>
              <span class="text-dark-600 font-bold text-xs px-2 py-0.5 rounded-md bg-dark-800/50 border border-dark-700/50">VS</span>
              <span class="font-semibold text-sm truncate flex-1 text-right" :style="{ color: game.away_team.color }">
                {{ game.away_team.short_name || game.away_team.name }}
              </span>
            </div>
            <div v-else class="text-sm font-medium text-dark-200 truncate">{{ game.title }}</div>
            <div class="flex items-center gap-2 mt-1.5">
              <span class="badge text-xs badge-gray">{{ fmtUpcomingTime(game.scheduled_at) }}</span>
              <span class="badge text-xs" :class="game.game_type === 'entertainment' ? 'badge-orange' : 'badge-blue'">
                {{ game.game_type === 'entertainment' ? '娱乐制' : '正式制' }}
              </span>
              <span v-if="game.venue" class="text-xs text-dark-500 truncate">{{ game.venue }}</span>
            </div>
          </div>
          <!-- 箭头 -->
          <svg class="w-4 h-4 text-dark-600 group-hover:text-accent-400 flex-shrink-0 transition-all duration-300 group-hover:translate-x-1"
            fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </router-link>
      </div>

      <!-- 更多预告 -->
      <div v-if="upcomingGames.length > 3" class="mt-3 text-center">
        <router-link to="/games" class="text-xs text-dark-500 hover:text-primary-400 transition-colors">
          还有 {{ upcomingGames.length - 3 }} 场赛事 →
        </router-link>
      </div>
    </div>

    <!-- 统计概览 - 紧凑版 -->
    <div class="grid grid-cols-4 gap-2 mb-5 animate-fade-in-up" style="animation-delay: 400ms">
      <div v-for="(stat, idx) in overviewStats" :key="stat.label"
        class="text-center p-2.5 rounded-xl bg-dark-800/50 border border-dark-700/30"
      >
        <div class="text-lg mb-0.5">{{ stat.icon }}</div>
        <div class="text-base font-bold text-white">{{ stat.value }}</div>
        <div class="text-[10px] text-dark-500">{{ stat.label }}</div>
      </div>
    </div>

    <!-- 最近结束赛事 -->
    <div v-if="recentGames.length > 0" class="mb-6 animate-fade-in-up" style="animation-delay: 500ms">
      <div class="flex items-center justify-between mb-3">
        <h2 class="section-title">最近赛事</h2>
        <router-link to="/games" class="text-sm text-primary-400 hover:text-primary-300 transition-colors">全部 →</router-link>
      </div>
      <div class="space-y-3">
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
import heroBg from '@/assets/images/hero-bg.jpg'

const auth = useAuthStore()
const games = ref([])
const stats = ref({ totalGames: 0, totalPlayers: 0, totalTeams: 0 })
const featuredTournament = ref(null)

const T_STATUS = {
  draft: { label: '待抽签', class: 'bg-dark-700 text-dark-300' },
  group_stage: { label: '小组赛中', class: 'bg-primary-600/25 text-primary-300 border border-primary-500/40' },
  playoffs: { label: '淘汰赛', class: 'bg-accent-600/25 text-accent-300 border border-accent-500/40' },
  finished: { label: '已落幕', class: 'bg-success/15 text-success border border-success/30' }
}
const tStatusText = t => t.group_count === 1 && t.status === 'group_stage'
  ? '循环赛中' : (T_STATUS[t.status]?.label || t.status)
const tStatusClass = s => T_STATUS[s]?.class || ''

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

  // 最新锦标赛（优先未结束的，含球队数）
  const { data: tData } = await supabase
    .from('tournaments')
    .select('id, name, status, group_count, start_date, tournament_teams(count)')
    .order('created_at', { ascending: false })
    .limit(4)
  if (tData?.length) {
    const live = tData.find(x => x.status !== 'finished') || tData[0]
    featuredTournament.value = {
      ...live,
      teamCount: live.tournament_teams?.[0]?.count ?? 0
    }
    // 抽签阶段：补充抽签进度
    if (live.status === 'draft') {
      const { count } = await supabase.from('tournament_teams')
        .select('*', { count: 'exact', head: true })
        .eq('tournament_id', live.id)
        .not('group_name', 'is', null)
      featuredTournament.value.drawnCount = count ?? 0
    }
  }

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
