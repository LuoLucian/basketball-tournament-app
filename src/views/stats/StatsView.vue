<template>
  <div class="page-container">
    <h1 class="text-xl font-bold text-white mb-5">数据统计</h1>

    <!-- 数据概览环形图 -->
    <div class="grid sm:grid-cols-3 gap-4 mb-6">
      <div class="stat-card">
        <div class="w-16 h-16 mx-auto mb-3 rounded-full relative"
          :style="{ background: `conic-gradient(#3b82f6 0% ${gamePct}%, #1e293b ${gamePct}% 100%)` }">
          <div class="absolute inset-1 rounded-full bg-dark-850 flex items-center justify-center">
            <span class="text-sm font-bold text-primary-400">{{ totalGames }}</span>
          </div>
        </div>
        <p class="text-sm font-semibold text-white">总赛事</p>
        <p class="text-xs text-dark-500">全部赛制</p>
      </div>
      <div class="stat-card">
        <div class="w-16 h-16 mx-auto mb-3 rounded-full relative"
          :style="{ background: `conic-gradient(#f97316 0% ${activePct}%, #1e293b ${activePct}% 100%)` }">
          <div class="absolute inset-1 rounded-full bg-dark-850 flex items-center justify-center">
            <span class="text-sm font-bold text-accent-400">{{ activeGames }}</span>
          </div>
        </div>
        <p class="text-sm font-semibold text-white">进行中</p>
        <p class="text-xs text-dark-500">实时更新</p>
      </div>
      <div class="stat-card">
        <div class="w-16 h-16 mx-auto mb-3 rounded-full relative"
          :style="{ background: `conic-gradient(#22c55e 0% ${playerPct}%, #1e293b ${playerPct}% 100%)` }">
          <div class="absolute inset-1 rounded-full bg-dark-850 flex items-center justify-center">
            <span class="text-sm font-bold text-success">{{ totalPlayers }}</span>
          </div>
        </div>
        <p class="text-sm font-semibold text-white">球员总数</p>
        <p class="text-xs text-dark-500">活跃球员</p>
      </div>
    </div>

    <!-- 快捷入口 -->
    <div class="grid sm:grid-cols-2 gap-4">
      <router-link to="/stats/leaderboard"
        class="glow-card flex items-center gap-4 group">
        <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-yellow-500/20 to-orange-500/20
                    flex items-center justify-center text-2xl border border-yellow-500/20
                    group-hover:scale-110 transition-transform duration-300">🏆</div>
        <div class="flex-1">
          <p class="font-semibold text-white group-hover:text-yellow-400 transition-colors">排行榜</p>
          <p class="text-xs text-dark-500 mt-0.5">得分/篮板/助攻/MVP 综合排行</p>
        </div>
        <svg class="w-4 h-4 text-dark-600 group-hover:text-yellow-400 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </router-link>
      <router-link to="/games"
        class="glow-card flex items-center gap-4 group">
        <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-primary-500/20 to-blue-500/20
                    flex items-center justify-center text-2xl border border-primary-500/20
                    group-hover:scale-110 transition-transform duration-300">📋</div>
        <div class="flex-1">
          <p class="font-semibold text-white group-hover:text-primary-400 transition-colors">赛事记录</p>
          <p class="text-xs text-dark-500 mt-0.5">查看所有比赛详情与数据</p>
        </div>
        <svg class="w-4 h-4 text-dark-600 group-hover:text-primary-400 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </router-link>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/utils/supabase'

const totalGames = ref(0)
const activeGames = ref(0)
const totalPlayers = ref(0)

const gamePct = ref(100)
const activePct = ref(0)
const playerPct = ref(100)

onMounted(async () => {
  const [{ count: gc }, { count: ac }, { count: pc }] = await Promise.all([
    supabase.from('games').select('*', { count: 'exact', head: true }),
    supabase.from('games').select('*', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('players').select('*', { count: 'exact', head: true }).eq('is_active', true)
  ])
  totalGames.value = gc || 0
  activeGames.value = ac || 0
  totalPlayers.value = pc || 0
  gamePct.value = Math.min(100, totalGames.value * 10)
  activePct.value = totalGames.value ? Math.round((activeGames.value / totalGames.value) * 100) : 0
  playerPct.value = Math.min(100, totalPlayers.value * 5)
})
</script>
