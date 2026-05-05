<template>
  <div class="min-h-screen bg-dark-900">
    <!-- 加载中 -->
    <div v-if="loading" class="flex items-center justify-center h-screen">
      <div class="text-center text-white">
        <div class="w-10 h-10 mx-auto mb-3 rounded-full border-2 border-primary-500 border-t-transparent animate-spin"></div>
        <p class="text-dark-400 text-sm">加载比赛数据...</p>
      </div>
    </div>

    <template v-else-if="gameStore.currentGame">
      <!-- 顶栏 -->
      <header class="glass-nav px-4 py-3 flex items-center gap-3 sticky top-0 z-20">
        <router-link :to="`/games/${gameId}`" class="text-dark-400 hover:text-white transition-colors">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
          </svg>
        </router-link>
        <div class="flex-1">
          <h1 class="text-white font-semibold text-sm truncate">{{ gameStore.currentGame.title }}</h1>
          <div class="flex items-center gap-2 mt-0.5">
            <span class="text-xs" :class="gameStore.currentGame.game_type === 'entertainment' ? 'text-accent-400' : 'text-primary-400'">
              {{ gameStore.currentGame.game_type === 'entertainment' ? '🎮 娱乐制' : '🏆 正式制' }}
            </span>
            <span class="flex items-center gap-1 text-xs" :class="gameStore.isConnected ? 'text-success' : 'text-danger-light'">
              <span class="w-1.5 h-1.5 rounded-full" :class="gameStore.isConnected ? 'bg-success animate-pulse' : 'bg-danger-light'"></span>
              {{ gameStore.isConnected ? '已同步' : '离线' }}
            </span>
          </div>
        </div>
      </header>

      <!-- 计分板 -->
      <div class="relative px-4 py-5 bg-gradient-to-b from-dark-850 via-dark-900 to-dark-900 overflow-hidden">
        <!-- 背景光效 -->
        <div class="absolute top-0 left-1/4 w-32 h-32 bg-primary-600/5 rounded-full blur-3xl"></div>
        <div class="absolute top-0 right-1/4 w-32 h-32 bg-accent-500/5 rounded-full blur-3xl"></div>

        <div class="relative z-10 flex items-center justify-between">
          <!-- 主队 -->
          <div class="flex-1 text-center">
            <div class="text-xs text-dark-400 mb-1.5 truncate px-2 font-medium">
              {{ gameStore.currentGame.home_team?.short_name || gameStore.currentGame.home_team?.name || '主队' }}
            </div>
            <div class="text-5xl sm:text-6xl font-black tabular-nums transition-all duration-300"
              :style="{ color: gameStore.currentGame.home_team?.color || '#fff', textShadow: `0 0 30px ${gameStore.currentGame.home_team?.color || '#fff'}33` }">
              {{ gameStore.currentGame.home_score }}
            </div>
          </div>

          <!-- 中间信息 -->
          <div class="flex flex-col items-center px-4">
            <div class="text-dark-600 text-lg font-light tracking-widest">VS</div>
            <div v-if="gameStore.currentGame.game_type === 'entertainment'" class="text-xs text-dark-500 text-center mt-1">
              目标 <span class="text-accent-400 font-bold">{{ gameStore.currentGame.target_score }}</span> 分
            </div>
            <div v-else class="text-sm text-white font-semibold mt-1">
              Q{{ gameStore.currentGame.current_quarter }}
              <span class="text-xs text-dark-400 ml-1">{{ fmtClock(gameStore.currentGame.quarter_clock || 0) }}</span>
            </div>
          </div>

          <!-- 客队 -->
          <div class="flex-1 text-center">
            <div class="text-xs text-dark-400 mb-1.5 truncate px-2 font-medium">
              {{ gameStore.currentGame.away_team?.short_name || gameStore.currentGame.away_team?.name || '客队' }}
            </div>
            <div class="text-5xl sm:text-6xl font-black tabular-nums transition-all duration-300"
              :style="{ color: gameStore.currentGame.away_team?.color || '#fff', textShadow: `0 0 30px ${gameStore.currentGame.away_team?.color || '#fff'}33` }">
              {{ gameStore.currentGame.away_score }}
            </div>
          </div>
        </div>
      </div>

      <!-- 操控按钮区 -->
      <div class="px-3 py-2 flex items-center gap-2 border-b border-dark-700/30 bg-dark-850/50">
        <!-- 开始 -->
        <button v-if="gameStore.currentGame.status === 'pending'" @click="startGame" :disabled="starting || !canManageGame"
          class="px-3 py-1 rounded-md text-[11px] font-bold transition-all active:scale-95"
          :class="starting ? 'bg-green-800 text-green-300 cursor-wait' : 'bg-green-600 text-white'">
          {{ starting ? '开始中...' : '开始' }}
        </button>

        <!-- 结束 -->
        <button v-if="gameStore.currentGame.status === 'active'" @click="endGame" :disabled="ending || !canManageGame"
          class="px-3 py-1 rounded-md text-[11px] font-bold transition-all active:scale-95"
          :class="ending ? 'bg-red-800 text-red-300 cursor-wait' : 'bg-red-600 text-white'">
          {{ ending ? '结束中...' : '结束' }}
        </button>

        <!-- 暂停/继续 -->
        <button v-if="gameStore.currentGame.status === 'active'" @click="togglePause"
          class="px-3 py-1 rounded-md text-[11px] font-bold transition-all active:scale-95"
          :class="isPaused ? 'bg-yellow-600 text-white' : 'bg-dark-700 text-dark-300 hover:bg-dark-600'">
          {{ isPaused ? '▶ 继续' : '⏸ 暂停' }}
        </button>

        <!-- 本节结束（仅正式制） -->
        <button v-if="gameStore.currentGame.status === 'active' && gameStore.currentGame.game_type !== 'entertainment'" @click="endQuarter"
          :disabled="!canManageGame || isPaused"
          class="px-3 py-1 rounded-md text-[11px] font-bold transition-all active:scale-95"
          :class="isPaused ? 'bg-dark-800 text-dark-600 cursor-not-allowed' : 'bg-dark-700 text-dark-300 hover:bg-dark-600'">
          本节结束
        </button>

        <div class="flex-1"></div>

        <!-- 状态 -->
        <div v-if="isPaused" class="flex items-center gap-1 text-yellow-400 text-[10px] flex-shrink-0">
          <span class="w-1 h-1 rounded-full bg-yellow-400"></span>
          已暂停
        </div>
        <div v-else-if="gameStore.currentGame.status === 'active'" class="flex items-center gap-1 text-green-400 text-[10px] flex-shrink-0">
          <span class="w-1 h-1 rounded-full bg-green-400 animate-pulse"></span>
          LIVE
        </div>
        <div v-if="gameStore.currentGame.status === 'finished'" class="text-primary-400 text-[10px] flex-shrink-0">
          已结束
        </div>
      </div>

      <!-- 主内容：两队面板 -->
      <div class="flex gap-0 overflow-x-auto pb-20 md:pb-4" style="min-height: calc(100vh - 280px)">
        <!-- 主队面板 -->
        <TeamPanel
          ref="homePanelRef"
          :team="gameStore.currentGame.home_team"
          :lineup="gameStore.homeLineup"
          :game-id="gameId"
          :team-id="gameStore.currentGame.home_team_id"
          :game-type="gameStore.currentGame.game_type"
          :game-status="gameStore.currentGame.status"
          :readonly="!canRecord"
          :lineup-readonly="!canManageLineup"
          :last-undo-action="lastUndoAction"
          @record="handleRecord"
          @lineup-change="handleLineupChange"
          @undo="undoAction"
          class="flex-1 min-w-0"
        />

        <!-- 分隔线 -->
        <div class="w-px bg-dark-700/50 flex-shrink-0"></div>

        <!-- 客队面板 -->
        <TeamPanel
          ref="awayPanelRef"
          :team="gameStore.currentGame.away_team"
          :lineup="gameStore.awayLineup"
          :game-id="gameId"
          :team-id="gameStore.currentGame.away_team_id"
          :game-type="gameStore.currentGame.game_type"
          :game-status="gameStore.currentGame.status"
          :readonly="!canRecord"
          :lineup-readonly="!canManageLineup"
          :last-undo-action="lastUndoAction"
          @record="handleRecord"
          @lineup-change="handleLineupChange"
          @undo="undoAction"
          class="flex-1 min-w-0"
        />
      </div>
    </template>

    <!-- 错误状态 -->
    <div v-else class="flex items-center justify-center h-screen text-white">
      <div class="text-center">
        <p class="text-dark-400 mb-4">赛事数据加载失败</p>
        <router-link to="/games" class="btn-primary btn">返回赛事列表</router-link>
      </div>
    </div>

    <!-- 录入反馈 Toast -->
    <Transition name="toast">
      <div v-if="toastMsg"
        class="fixed bottom-20 left-1/2 -translate-x-1/2 z-50
               bg-dark-800 text-white text-sm px-5 py-2.5 rounded-full
               shadow-lg border border-dark-600/50 backdrop-blur-xl">
        {{ toastMsg }}
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useGameStore } from '@/stores/game'
import { useAuthStore } from '@/stores/auth'
import { fmtClock } from '@/utils/helpers'
import { supabase } from '@/utils/supabase'
import TeamPanel from '@/components/game/TeamPanel.vue'

const route = useRoute()
const gameStore = useGameStore()
const auth = useAuthStore()
const gameId = route.params.id

const loading = ref(true)
const toastMsg = ref('')
const starting = ref(false)
const ending = ref(false)
let toastTimer

const homePanelRef = ref(null)
const awayPanelRef = ref(null)

// ── 权限逻辑 ──
const isTeamAdmin = computed(() => {
  if (!gameStore.currentGame) return false
  const uid = auth.user?.id
  if (!uid) return false
  return gameStore.currentGame.home_team?.owner_id === uid
    || gameStore.currentGame.away_team?.owner_id === uid
})

const isPaused = ref(false)

const canRecord = computed(() => {
  if (isPaused.value) return false
  if (!gameStore.currentGame) return false
  if (['finished', 'cancelled'].includes(gameStore.currentGame.status)) return false
  const uid = auth.user?.id
  if (!uid) return false
  const isAssigned = assignedRecorders.value.some(r => r.recorder_id === uid)
  return auth.isAdmin || auth.role === 'recorder' || isTeamAdmin.value || isAssigned
})

const canManageGame = computed(() => {
  if (!gameStore.currentGame) return false
  if (['finished', 'cancelled'].includes(gameStore.currentGame.status)) return false
  const uid = auth.user?.id
  if (!uid) return false
  const isAssigned = assignedRecorders.value.some(r => r.recorder_id === uid)
  return auth.isAdmin || auth.role === 'recorder' || isTeamAdmin.value || isAssigned
})

// 阵容调整权限（不受暂停影响）
const canManageLineup = computed(() => {
  if (!gameStore.currentGame) return false
  if (['finished', 'cancelled'].includes(gameStore.currentGame.status)) return false
  const uid = auth.user?.id
  if (!uid) return false
  const isAssigned = assignedRecorders.value.some(r => r.recorder_id === uid)
  return auth.isAdmin || auth.role === 'recorder' || isTeamAdmin.value || isAssigned
})

const assignedRecorders = ref([])

onMounted(async () => {
  // 确保清空上一场比赛的操作栈
  gameStore.actionStack = []
  try {
    await gameStore.loadGame(gameId)
    gameStore.subscribeRealtime(gameId)
    // 查询指派记录员
    const { data: recData } = await supabase
      .from('game_recorders')
      .select('recorder_id')
      .eq('game_id', gameId)
    assignedRecorders.value = recData || []
  } catch (e) {
    console.error('加载比赛失败:', e)
  } finally {
    loading.value = false
  }
})

onUnmounted(() => {
  gameStore.unsubscribeRealtime()
})

async function handleRecord({ playerId, teamId, actionType, playerName }) {
  try {
    await gameStore.recordAction(playerId, teamId, actionType, 1, playerName)
    showToast(actionLabel(actionType))
    // 刷新两个面板的实时数据
    homePanelRef.value?.refreshStats()
    awayPanelRef.value?.refreshStats()
  } catch (e) {
    showToast('❌ ' + (e.message || '录入失败'))
  }
}

// 阵容变化回调（拖拽换人后由 TeamPanel 内部处理数据库，这里只同步 slot_no）
async function handleLineupChange(newLineup) {
  // swap_player RPC 已经处理了数据库写入，不需要再 update slot_no
  // 也不需要 loadLineup，避免覆盖 TeamPanel 的乐观更新
}

async function startGame() {
  if (!confirm('确认开始比赛？')) return
  starting.value = true
  try {
    const { error } = await supabase.rpc('update_game_status', {
      p_game_id: gameId,
      p_status: 'active',
      p_started_at: new Date().toISOString()
    })
    if (error) throw error
    showToast('比赛已开始')
    // 只更新比赛状态，不重新 loadLineup（保留比赛前已调整的阵容）
    const { data: gameData } = await supabase
      .from('games')
      .select('*, home_team:home_team_id(*), away_team:away_team_id(*)')
      .eq('id', gameId)
      .single()
    if (gameData) gameStore.currentGame = gameData
  } catch (e) {
    showToast('开始失败：' + (e.message || '未知错误'))
  } finally {
    starting.value = false
  }
}

async function endGame() {
  if (!confirm('确认结束比赛？')) return
  ending.value = true
  try {
    const { error } = await supabase.rpc('update_game_status', {
      p_game_id: gameId,
      p_status: 'finished',
      p_finished_at: new Date().toISOString()
    })
    if (error) throw error
    showToast('比赛已结束')
    await gameStore.loadGame(gameId)
    await supabase.rpc('snapshot_game_players', { p_game_id: gameId })
    await calcMvp()
  } catch (e) {
    showToast('结束失败：' + (e.message || '未知错误'))
  } finally {
    ending.value = false
  }
}

function togglePause() {
  isPaused.value = !isPaused.value
  showToast(isPaused.value ? '⏸ 比赛已暂停' : '▶ 比赛继续')
}

function endQuarter() {
  if (!confirm('确认结束本节？将暂停录入。')) return
  isPaused.value = true
}

async function calcMvp() {
  const { data: stats } = await supabase.from('game_stats').select('*').eq('game_id', gameId)
  if (!stats?.length) return
  const g = gameStore.currentGame
  // 判断胜方（平局时 null，全员可参选）
  let winnerTeamId = null
  if (g.home_score > g.away_score) winnerTeamId = g.home_team_id
  else if (g.away_score > g.home_score) winnerTeamId = g.away_team_id
  // 只从胜方选 MVP（平局则全员参选）
  const candidates = winnerTeamId ? stats.filter(s => s.team_id === winnerTeamId) : stats
  const scored = candidates.map(s => ({
    player_id: s.player_id,
    mvp_score: s.pts * 1.2 + s.reb * 1.1 + s.ast * 1.5 + s.stl * 2 + s.blk * 2 - s.tov * 1.5 - s.pf * 0.8
  }))
  if (!scored.length) return
  const winner = scored.reduce((a, b) => a.mvp_score > b.mvp_score ? a : b)
  // 通过 RPC 写入（SECURITY DEFINER 绕过 RLS）
  const { error } = await supabase.rpc('upsert_game_mvp', {
    p_game_id: gameId,
    p_players: scored.map(s => ({
      player_id: s.player_id,
      mvp_score: Number(s.mvp_score.toFixed(2))
    })),
    p_winner_id: winner.player_id
  })
  if (error) console.error('[calcMvp] RPC 写入失败:', error)
}

function showToast(msg) {
  toastMsg.value = msg
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastMsg.value = '' }, 1500)
}

const lastUndoAction = computed(() => gameStore.actionStack)

async function undoAction(action) {
  try {
    await gameStore.undoAction(action)
    const desc = action ? `↩ 已撤销：${action.player_name || ''} ${actionLabel(action.actionType || action.action_type || '')}` : '↩ 已撤销'
    showToast(desc)
    // 刷新两个面板的实时数据
    homePanelRef.value?.refreshStats()
    awayPanelRef.value?.refreshStats()
  } catch (e) {
    showToast('❌ 撤销失败')
  }
}

function actionLabel(type) {
  const map = {
    pts_1: '+1分', pts_2: '+2分', pts_3: '+3分',
    reb: '篮板+1', ast: '助攻+1', stl: '抢断+1', blk: '盖帽+1',
    tov: '失误+1', pf: '犯规+1', fga_miss: '两分不中', fg3a_miss: '三分不中', fta_miss: '罚球不中'
  }
  return map[type] || '已录入'
}
</script>

<style scoped>
.toast-enter-active, .toast-leave-active { transition: all 0.2s ease; }
.toast-enter-from, .toast-leave-to { opacity: 0; transform: translateX(-50%) translateY(10px); }
</style>
