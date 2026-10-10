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

    <!-- 位置筛选 -->
    <div class="flex gap-1.5 overflow-x-auto mb-4 pb-1 scrollbar-none">
      <button v-for="pos in positionOptions" :key="pos.value"
        @click="activePosition = pos.value"
        class="flex-shrink-0 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all duration-200 border"
        :class="activePosition === pos.value
          ? 'bg-primary-600/20 text-primary-400 border-primary-500/50'
          : 'bg-dark-800 text-dark-400 border-dark-700 hover:text-white hover:border-dark-600'"
      >{{ pos.label }}</button>
    </div>

    <!-- 排序模式切换：累计 / 场均 -->
    <div class="flex gap-1 bg-dark-800 p-1 rounded-xl border border-dark-700/50 mb-4 w-fit">
      <button v-for="m in sortModes" :key="m.value"
        @click="activeSortMode = m.value"
        class="px-4 py-1.5 rounded-lg text-sm font-semibold transition-all duration-200"
        :class="activeSortMode === m.value
          ? m.value === 'total' ? 'bg-accent-500/20 text-accent-400 shadow-sm' : 'bg-primary-600/20 text-primary-300 shadow-sm'
          : 'text-dark-500 hover:text-dark-300'"
      >{{ m.label }}</button>
    </div>

    <!-- 统计类型 Tab -->
    <div class="flex gap-2 overflow-x-auto mb-5 pb-1 scrollbar-none">
      <button v-for="cat in currentCategories" :key="cat.key"
        @click="activeCategory = cat.key"
        class="flex-shrink-0 px-4 py-1.5 rounded-xl text-sm font-semibold transition-all duration-200"
        :class="activeCategory === cat.key
          ? activeSortMode === 'total' ? 'bg-accent-500 text-white shadow-neon-orange' : 'bg-primary-600 text-white shadow-neon-blue'
          : 'bg-dark-800 text-dark-400 border border-dark-700 hover:text-white hover:border-dark-600'"
      >{{ cat.label }}</button>
    </div>

    <!-- 排行榜 -->
    <div class="card">
      <div class="card-header">
        <h2 class="font-semibold text-white">
          {{ currentCategories.find(c => c.key === activeCategory)?.label }}
          <span class="text-xs font-normal text-dark-500 ml-1">{{ activeSortMode === 'total' ? '累计' : '场均' }}</span>
          <span v-if="activePosition !== 'ALL'" class="text-xs font-normal text-primary-400 ml-1">{{ activePosition }}</span>
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
          <router-link :to="{ 
            path: `/players/${player.player_id}`, 
            query: { 
              from: 'leaderboard',
              gameType: activeGameType.value,
              sortMode: activeSortMode.value,
              category: activeCategory.value,
              position: activePosition.value
            } 
          }"
            class="flex items-center gap-2.5 flex-1 min-w-0"
          >
            <div class="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 border-2 overflow-hidden"
              :class="index === 0 ? 'bg-yellow-500/20 border-yellow-500/40 text-yellow-400' :
                      index === 1 ? 'bg-gray-400/20 border-gray-400/40 text-gray-300' :
                      index === 2 ? 'bg-orange-500/20 border-orange-500/40 text-orange-400' :
                      'bg-dark-800 border-dark-600 text-dark-300'"
            >
              <img v-if="player.avatar_url" :src="player.avatar_url" class="w-full h-full object-cover" alt="">
              <span v-else>{{ getInitials(player.player_name) }}</span>
            </div>
            <div class="min-w-0">
              <p class="font-semibold text-white text-sm truncate">{{ player.player_name }}</p>
              <p class="text-xs text-dark-500">
                {{ player.games_played }} 场
                <span v-if="activePosition !== 'ALL'" class="text-primary-400 ml-1">{{ activePosition }}</span>
              </p>
            </div>
          </router-link>

          <!-- 数值 -->
          <div class="text-right flex-shrink-0">
            <p class="text-lg font-bold" :class="index === 0 ? 'text-gradient-gold text-glow-orange' : 'text-primary-400'">
              <template v-if="activeSortMode === 'total'">
                {{ totalFmt(player[activeCategory]) }}
              </template>
              <template v-else-if="activeCategory === 'fg_pct' || activeCategory === 'fg3_pct'">
                {{ pctFmt(player[activeCategory]) }}
              </template>
              <template v-else>
                {{ avgFmt(player[activeCategory], player.games_played) }}
              </template>
            </p>
            <p class="text-xs text-dark-500">
              <template v-if="activeSortMode === 'total'">累计</template>
              <template v-else-if="activeCategory === 'fg_pct' || activeCategory === 'fg3_pct'">总命中率</template>
              <template v-else>场均</template>
            </p>
          </div>
        </div>

        <!-- 空状态 -->
        <div v-if="sortedLeaderboard.length === 0" class="empty-state py-12">
          <svg class="w-16 h-16 text-dark-600 mb-3" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M16 48 L32 16 L48 48 Z" opacity="0.3"/>
            <circle cx="32" cy="40" r="8" opacity="0.2"/>
            <text x="32" y="58" text-anchor="middle" fill="currentColor" stroke="none" font-size="10" opacity="0.4">NO DATA</text>
          </svg>
          <p class="text-dark-500 text-sm">暂无{{ activePosition !== 'ALL' ? activePosition + '位置' : '' }}统计数据</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/utils/supabase'
import { getInitials, calcMvpScore } from '@/utils/helpers'

const route = useRoute()
const router = useRouter()

// 从 URL query 参数恢复状态，或使用默认值
const activeGameType = ref(route.query.gameType || 'entertainment')
const activeSortMode = ref(route.query.sortMode || 'total') // 'total' | 'avg'
const activeCategory = ref(route.query.category || 'pts')
const activePosition = ref(route.query.position || 'ALL')
const leaderboard = ref([])
const loading = ref(true)

// 状态变化时更新 URL
function updateQueryParams() {
  router.replace({
    path: route.path,
    query: {
      gameType: activeGameType.value,
      sortMode: activeSortMode.value,
      category: activeCategory.value,
      position: activePosition.value
    }
  })
}

const gameTypeOptions = [
  { value: 'entertainment', label: '娱乐' },
  { value: 'official', label: '正式' }
]

const positionOptions = [
  { value: 'ALL', label: '全部' },
  { value: 'PG', label: '控卫 PG' },
  { value: 'SG', label: '分卫 SG' },
  { value: 'SF', label: '小前 SF' },
  { value: 'PF', label: '大前 PF' },
  { value: 'C', label: '中锋 C' },
  { value: 'FLEX', label: '全能 FLEX' }
]

const sortModes = [
  { value: 'total', label: '累计' },
  { value: 'avg', label: '场均' }
]

// 累计模式有6个维度
const totalCategories = [
  { key: 'pts', label: '得分' },
  { key: 'reb', label: '篮板' },
  { key: 'ast', label: '助攻' },
  { key: 'stl', label: '抢断' },
  { key: 'blk', label: '盖帽' },
  { key: 'pf', label: '犯规' }
]

// 场均模式有全部维度
const avgCategories = [
  { key: 'pts',  label: '得分' },
  { key: 'reb',  label: '篮板' },
  { key: 'ast',  label: '助攻' },
  { key: 'stl',  label: '抢断' },
  { key: 'blk',  label: '盖帽' },
  { key: 'pf',   label: '犯规' },
  { key: 'fg_pct', label: '二分%' },
  { key: 'fg3_pct', label: '三分%' },
  { key: 'mvp_score', label: 'MVP分' }
]

const currentCategories = computed(() => {
  return activeSortMode.value === 'total' ? totalCategories : avgCategories
})

// 切换模式时，如果当前分类不在新列表中，自动切换到第一个
watch(activeSortMode, () => {
  const cats = currentCategories.value
  if (!cats.find(c => c.key === activeCategory.value)) {
    activeCategory.value = cats[0].key
  }
})

const sortedLeaderboard = computed(() => {
  return [...leaderboard.value].sort((a, b) => {
    const cat = activeCategory.value
    // 命中率按整体百分比排序
    if (cat === 'fg_pct' || cat === 'fg3_pct') {
      const aVal = a[cat] ?? -1
      const bVal = b[cat] ?? -1
      return bVal - aVal
    }
    // 累计模式：按总数据排序
    if (activeSortMode.value === 'total') {
      return (b[cat] || 0) - (a[cat] || 0)
    }
    // 场均模式：按场均排序
    const aAvg = a.games_played ? (a[cat] || 0) / a.games_played : -1
    const bAvg = b.games_played ? (b[cat] || 0) / b.games_played : -1
    return bAvg - aAvg
  })
})

function totalFmt(val) {
  if (val == null) return '0'
  return Number(val).toFixed(0)
}

function avgFmt(val, games) {
  if (!games) return '0'
  return (Number(val || 0) / games).toFixed(1)
}

function pctFmt(val) {
  if (val == null) return '-'
  return Number(val).toFixed(1) + '%'
}

// 该赛制暂无比赛数据时：展示全部现役球员，数据全部为 0
async function loadEmptyLeaderboard() {
  let playersData = null
  try {
    const res = await supabase
      .from('players')
      .select('id, name, avatar_url, position')
      .eq('is_active', true)
      .order('name')
    playersData = res.data
  } catch (e) { /* 忽略，退回空状态 */ }
  const pool = playersData || []
  const filtered = activePosition.value === 'ALL'
    ? pool
    : pool.filter(p => p.position === activePosition.value)
  leaderboard.value = filtered.map(p => ({
    player_id: p.id,
    player_name: p.name || '-',
    avatar_url: p.avatar_url || null,
    player_position: activePosition.value === 'ALL' ? 'ALL' : p.position,
    games_played: 0,
    pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
    fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0,
    fg_pct: null, fg3_pct: null, mvp_score: 0
  }))
  loading.value = false
}

async function loadLeaderboard() {
  loading.value = true
  // 始终加载所有数据，在前端分组
  const { data } = await supabase
    .from('game_stats')
    .select('player_id, team_id, game_id, player_name, player_avatar_url, player_position, pts, reb, ast, stl, blk, tov, pf, fg2m, fg2a, fg3m, fg3a')
    .eq('game_type', activeGameType.value)

  if (!data || data.length === 0) { await loadEmptyLeaderboard(); return }

  // 批量获取比赛信息（用于MVP计算）
  const gameIds = [...new Set(data.map(r => r.game_id))]
  const { data: gamesData } = await supabase
    .from('games')
    .select('id, home_score, away_score, home_team_id, away_team_id')
    .in('id', gameIds)
  const gameMap = {}
  if (gamesData) for (const g of gamesData) gameMap[g.id] = g

  // 批量获取球员头像（从 players 表，确保比赛一创建就有头像）
  const playerIds = [...new Set(data.map(r => r.player_id))]
  const { data: playersData } = await supabase
    .from('players')
    .select('id, avatar_url')
    .in('id', playerIds)
  const playerAvatarMap = {}
  if (playersData) for (const p of playersData) playerAvatarMap[p.id] = p.avatar_url

  if (activePosition.value === 'ALL') {
    // "全部"模式：按 player_id 合并所有位置的数据
    const map = {}
    for (const row of data) {
      const pid = row.player_id
      if (!map[pid]) {
        map[pid] = {
          player_id: pid,
          player_name: row.player_name || '-',
          avatar_url: playerAvatarMap[pid] || row.player_avatar_url || null,
          player_position: 'ALL',
          games_played: 0,
          pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
          fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0
        }
      }
      const p = map[pid]
      p.games_played++
      for (const k of ['pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'pf', 'fg2m', 'fg2a', 'fg3m', 'fg3a']) {
        p[k] += (row[k] || 0)
      }
    }
    leaderboard.value = Object.values(map).map(p => {
      const totalFG = p.fg2m + p.fg3m
      const totalFGA = p.fg2a + p.fg3a
      const fgPct = totalFGA >= 5 ? (totalFG / totalFGA * 100) : null
      const total3 = p.fg3m + p.fg3a
      const fg3Pct = total3 >= 5 ? (p.fg3m / total3 * 100) : null
      let mvpTotal = 0
      for (const row of data) {
        if (row.player_id !== p.player_id) continue
        const g = gameMap[row.game_id]
        if (!g) continue
        const isHome = row.team_id === g.home_team_id
        const isWin = (isHome && g.home_score > g.away_score) || (!isHome && g.away_score > g.home_score)
        if (!isWin) continue
        mvpTotal += parseFloat(calcMvpScore({
          pts: row.pts || 0, reb: row.reb || 0, ast: row.ast || 0,
          stl: row.stl || 0, blk: row.blk || 0, tov: row.tov || 0, pf: row.pf || 0,
        }))
      }
      return { ...p, mvp_score: mvpTotal, fg_pct: fgPct, fg3_pct: fg3Pct }
    })
  } else {
    // 选具体位置：只统计该位置的记录，按 player_id 分组
    const filtered = data.filter(r => r.player_position === activePosition.value)

    if (filtered.length === 0) { await loadEmptyLeaderboard(); return }
    
    const map = {}
    for (const row of filtered) {
      const pid = row.player_id
      if (!map[pid]) {
        map[pid] = {
          player_id: pid,
          player_name: row.player_name || '-',
          avatar_url: playerAvatarMap[pid] || row.player_avatar_url || null,
          player_position: activePosition.value,
          games_played: 0,
          pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
          fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0
        }
      }
      const p = map[pid]
      p.games_played++
      for (const k of ['pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'pf', 'fg2m', 'fg2a', 'fg3m', 'fg3a']) {
        p[k] += (row[k] || 0)
      }
    }
    leaderboard.value = Object.values(map).map(p => {
      const totalFG = p.fg2m + p.fg3m
      const totalFGA = p.fg2a + p.fg3a
      const fgPct = totalFGA >= 5 ? (totalFG / totalFGA * 100) : null
      const total3 = p.fg3m + p.fg3a
      const fg3Pct = total3 >= 5 ? (p.fg3m / total3 * 100) : null
      let mvpTotal = 0
      for (const row of filtered) {
        if (row.player_id !== p.player_id) continue
        const g = gameMap[row.game_id]
        if (!g) continue
        const isHome = row.team_id === g.home_team_id
        const isWin = (isHome && g.home_score > g.away_score) || (!isHome && g.away_score > g.home_score)
        if (!isWin) continue
        mvpTotal += parseFloat(calcMvpScore({
          pts: row.pts || 0, reb: row.reb || 0, ast: row.ast || 0,
          stl: row.stl || 0, blk: row.blk || 0, tov: row.tov || 0, pf: row.pf || 0,
        }))
      }
      return { ...p, mvp_score: mvpTotal, fg_pct: fgPct, fg3_pct: fg3Pct }
    })
  }
  loading.value = false
}

onMounted(loadLeaderboard)
watch(activeGameType, () => { updateQueryParams(); loadLeaderboard() })
watch(activePosition, () => { updateQueryParams(); loadLeaderboard() })
watch(activeSortMode, updateQueryParams)
watch(activeCategory, updateQueryParams)
</script>
