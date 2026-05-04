<template>
  <div class="page-container">
    <div class="flex items-center justify-between mb-5">
      <h1 class="page-title">排行榜</h1>
      <!-- 赛制切换 -->
      <div class="flex gap-1 bg-dark-800 p-1 rounded-xl border border-dark-700/50">
        <button v-for="gt in gameTypeOptions" :key="gt.value"
          @click="activeGameType = gt.value"
          class="px-3 py-1.5 rounded-lg text-sm font-semibold transition-all duration-200"
          :class="activeGameType === gt.value ? 'bg-dark-700 text-white shadow-sm' : 'text-dark-500 hover:text-dark-300'"
        >{{ gt.label }}</button>
      </div>
    </div>

    <!-- 统计类型 Tab -->
    <div class="flex gap-2 overflow-x-auto mb-5 pb-1 scrollbar-none">
      <button v-for="cat in categories" :key="cat.key"
        @click="activeCategory = cat.key"
        class="flex-shrink-0 px-4 py-1.5 rounded-xl text-sm font-semibold transition-all duration-200"
        :class="activeCategory === cat.key
          ? 'bg-primary-600 text-white shadow-neon-blue'
          : 'bg-dark-800 text-dark-400 border border-dark-700 hover:text-white hover:border-dark-600'"
      >{{ cat.label }}</button>
    </div>

    <!-- 排行榜 -->
    <div class="card">
      <div class="card-header">
        <h2 class="font-semibold text-white">
          {{ categories.find(c => c.key === activeCategory)?.label }} 排行
        </h2>
        <span class="text-xs text-dark-500">{{ activeGameType === 'entertainment' ? '娱乐制' : '正式制' }}</span>
      </div>

      <!-- 加载骨架 -->
      <div v-if="loading" class="space-y-2 p-4">
        <div v-for="i in 8" :key="i" class="skeleton h-14 rounded-xl"></div>
      </div>

      <div v-else class="divide-y divide-dark-700/30">
        <div v-for="(player, index) in sortedLeaderboard" :key="player.player_id"
          class="flex items-center gap-3 px-4 py-3 hover:bg-dark-800/50 transition-colors"
          :class="index < 3 ? 'bg-dark-800/20' : ''"
        >
          <!-- 排名 -->
          <div class="w-8 text-center flex-shrink-0">
            <div v-if="index === 0" class="w-7 h-7 mx-auto rounded-full bg-gradient-to-br from-yellow-300 to-yellow-600 flex items-center justify-center text-xs font-bold text-dark-900 shadow-neon-orange">1</div>
            <div v-else-if="index === 1" class="w-7 h-7 mx-auto rounded-full bg-gradient-to-br from-gray-300 to-gray-500 flex items-center justify-center text-xs font-bold text-dark-900">2</div>
            <div v-else-if="index === 2" class="w-7 h-7 mx-auto rounded-full bg-gradient-to-br from-orange-400 to-orange-700 flex items-center justify-center text-xs font-bold text-dark-900">3</div>
            <span v-else class="text-sm font-semibold text-dark-500">{{ index + 1 }}</span>
          </div>

          <!-- 球员 -->
          <router-link :to="`/players/${player.player_id}`"
            class="flex items-center gap-2.5 flex-1 min-w-0"
          >
            <div class="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 border-2"
              :class="index === 0 ? 'bg-yellow-500/20 border-yellow-500/40 text-yellow-400' :
                      index === 1 ? 'bg-gray-400/20 border-gray-400/40 text-gray-300' :
                      index === 2 ? 'bg-orange-500/20 border-orange-500/40 text-orange-400' :
                      'bg-dark-800 border-dark-600 text-dark-300'"
            >
              {{ getInitials(player.player_name) }}
            </div>
            <div class="min-w-0">
              <p class="font-semibold text-white text-sm truncate">{{ player.player_name }}</p>
              <p class="text-xs text-dark-500">{{ player.games_played }} 场</p>
            </div>
          </router-link>

          <!-- 数值 -->
          <div class="text-right flex-shrink-0">
            <p class="text-lg font-bold" :class="index === 0 ? 'text-gradient-gold text-glow-orange' : 'text-primary-400'">
              {{ fmt(player[activeCategory]) }}
            </p>
            <p class="text-xs text-dark-500">均 {{ avgFmt(player[activeCategory], player.games_played) }}</p>
          </div>
        </div>

        <!-- 空状态 -->
        <div v-if="sortedLeaderboard.length === 0" class="empty-state py-12">
          <svg class="w-16 h-16 text-dark-600 mb-3" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M16 48 L32 16 L48 48 Z" opacity="0.3"/>
            <circle cx="32" cy="40" r="8" opacity="0.2"/>
            <text x="32" y="58" text-anchor="middle" fill="currentColor" stroke="none" font-size="10" opacity="0.4">NO DATA</text>
          </svg>
          <p class="text-dark-500 text-sm">暂无统计数据</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/utils/supabase'
import { getInitials, calcMvpScore } from '@/utils/helpers'

const activeGameType = ref('entertainment')
const activeCategory = ref('pts')
const leaderboard = ref([])
const loading = ref(true)

const gameTypeOptions = [
  { value: 'entertainment', label: '娱乐' },
  { value: 'official', label: '正式' }
]

const categories = [
  { key: 'pts',  label: '得分' },
  { key: 'reb',  label: '篮板' },
  { key: 'ast',  label: '助攻' },
  { key: 'stl',  label: '抢断' },
  { key: 'blk',  label: '盖帽' },
  { key: 'mvp_score', label: 'MVP分' }
]

const sortedLeaderboard = computed(() => {
  return [...leaderboard.value].sort((a, b) => (b[activeCategory.value] || 0) - (a[activeCategory.value] || 0))
})

function fmt(val) {
  return val != null ? Number(val).toFixed(activeCategory.value === 'mvp_score' ? 1 : 0) : '0'
}
function avgFmt(val, games) {
  if (!games) return '0'
  return (Number(val || 0) / games).toFixed(1)
}

async function loadLeaderboard() {
  loading.value = true
  const { data } = await supabase
    .from('game_stats')
    .select(`
      player_id,
      team_id,
      player:player_id(name),
      game:game_id(id, home_score, away_score, home_team_id, away_team_id),
      pts, reb, ast, stl, blk, tov, pf,
      fgm, fga, fg3m, fg3a
    `)
    .eq('game_type', activeGameType.value)

  if (!data) { loading.value = false; return }

  const map = {}
  for (const row of data) {
    const pid = row.player_id
    if (!map[pid]) {
      map[pid] = {
        player_id: pid,
        player_name: row.player?.name || '-',
        games_played: 0,
        pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
        fgm: 0, fga: 0, fg3m: 0, fg3a: 0
      }
    }
    const p = map[pid]
    p.games_played++
    for (const k of ['pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'pf', 'fgm', 'fga', 'fg3m', 'fg3a']) {
      p[k] += (row[k] || 0)
    }
  }

  // 计算 MVP 分：只累加赢球场次
  leaderboard.value = Object.values(map).map(p => {
    // 重新遍历计算 MVP 分（只算赢球场次）
    let mvpTotal = 0
    for (const row of data) {
      if (row.player_id !== p.player_id) continue
      const g = row.game
      if (!g) continue
      // 判断该球员所在队伍是否赢了
      const isHome = row.team_id === g.home_team_id
      const isWin = (isHome && g.home_score > g.away_score)
        || (!isHome && g.away_score > g.home_score)
      if (!isWin) continue
      // 赢球场次才计入 MVP 分
      const stat = {
        pts: row.pts || 0,
        reb: row.reb || 0,
        ast: row.ast || 0,
        stl: row.stl || 0,
        blk: row.blk || 0,
        tov: row.tov || 0,
        pf: row.pf || 0,
      }
      mvpTotal += parseFloat(calcMvpScore(stat))
    }
    return { ...p, mvp_score: mvpTotal }
  })
  loading.value = false
}

onMounted(loadLeaderboard)
watch(activeGameType, loadLeaderboard)
</script>
