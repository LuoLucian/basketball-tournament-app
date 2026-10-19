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
            <!-- 待同步提示 -->
            <div v-if="gameStore.pendingCount > 0" class="flex items-center gap-1 mt-1">
              <span class="w-1.5 h-1.5 rounded-full bg-yellow-400 animate-pulse"></span>
              <span class="text-[10px] text-yellow-400">{{ gameStore.pendingCount }}条待同步</span>
            </div>
            <div v-if="gameStore.currentGame.game_type === 'entertainment'" class="text-xs text-dark-500 text-center mt-1">
              目标 <span class="text-accent-400 font-bold">{{ gameStore.currentGame.target_score }}</span> 分
              <span class="text-dark-600 mx-0.5">·</span>第 <span class="text-white font-bold">{{ virtualQuarter }}</span> 节
            </div>
            <div v-else class="flex items-baseline gap-2 mt-1">
              <span class="text-sm sm:text-base font-bold text-white">
                {{ quarterLabel(gameStore.currentGame.current_quarter, gameStore.currentGame.quarters) }}
              </span>
              <span class="text-2xl sm:text-3xl font-black tabular-nums leading-none"
                :class="remainingSecs <= 60 && clockRunning ? 'text-danger-light animate-pulse' : 'text-dark-400'">
                {{ fmtClock(remainingSecs) }}
              </span>
            </div>

            <!-- 下一次球权提示（裁判换节/争球时参考） -->
            <button v-if="canManageGame" @click="togglePossession"
              class="mt-2 px-3 py-1 rounded-full border text-[10px] sm:text-xs font-bold transition-all active:scale-95 flex items-center gap-1.5 whitespace-nowrap"
              :class="[
                gameStore.currentGame.possession_home == null ? 'border-dark-600 border-dashed text-dark-400' : 'border',
                quarterBreak && gameStore.currentGame.possession_home != null ? 'animate-pulse' : ''
              ]"
              :style="possessionStyle" title="点击切换球权方向">
              <span v-if="gameStore.currentGame.possession_home == null">⚖ 设置球权方向</span>
              <template v-else>
                <span class="text-sm leading-none">{{ possessionHome ? '◀' : '▶' }}</span>
                <span>{{ possessionLabel }}：{{ possessionTeamName }}</span>
              </template>
            </button>
            <div v-else-if="gameStore.currentGame.possession_home != null"
              class="mt-2 px-3 py-1 rounded-full border text-[10px] sm:text-xs font-bold flex items-center gap-1.5 whitespace-nowrap border"
              :style="possessionStyle">
              <span class="text-sm leading-none">{{ possessionHome ? '◀' : '▶' }}</span>
              <span>下次球权：{{ possessionTeamName }}</span>
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

      <!-- 计时控制条（正式制：进攻时间 + 时间回表）；未开赛时仅记录员可见开关，用于赛前设定 -->
      <div v-if="showClockBar"
        class="px-2 sm:px-3 py-2 flex flex-wrap items-center gap-2 border-b border-dark-700/30 bg-dark-900/70">
        <!-- 24 秒功能开关：关闭后本页与大屏都不显示进攻时间 -->
        <button @click="toggleShotClockEnabled" :disabled="!canManageGame"
          class="h-9 px-2.5 rounded-lg text-xs font-bold border transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0 flex items-center gap-1.5"
          :class="shotClockEnabled
            ? 'border-primary-500/50 bg-primary-600/15 text-primary-300 hover:bg-primary-600/25'
            : 'border-dark-700 bg-dark-800 text-dark-500 hover:bg-dark-700'">
          <span class="relative w-7 h-4 rounded-full transition-colors flex-shrink-0"
            :class="shotClockEnabled ? 'bg-primary-500' : 'bg-dark-600'">
            <span class="absolute top-0.5 w-3 h-3 rounded-full bg-white transition-all duration-200"
              :class="shotClockEnabled ? 'left-3.5' : 'left-0.5'"></span>
          </span>
          <span class="whitespace-nowrap">进攻计时</span>
        </button>

        <template v-if="shotClockEnabled && gameStore.currentGame.status !== 'pending'">
          <!-- 进攻时间显示 -->
          <div class="flex items-center gap-2 h-9 px-3 rounded-lg bg-dark-850 border border-dark-700/60 flex-shrink-0">
            <span class="text-[10px] font-bold tracking-widest text-dark-500">进攻</span>
            <span class="w-[2.2em] text-center font-black tabular-nums leading-none text-xl sm:text-2xl"
              :class="shotClockDanger ? 'text-red-400 animate-pulse' : 'text-white'">{{ shotClockSecs }}</span>
            <span v-if="!shotClockRunning" class="text-[9px] font-bold px-1.5 py-0.5 rounded bg-dark-700 text-dark-400">停</span>
          </div>
          <button @click="setShotClock(24)" :disabled="!canManageGame"
            class="h-9 px-3 rounded-lg text-xs font-bold border border-dark-700 bg-dark-800 text-white hover:bg-dark-700 transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0">
            24秒
          </button>
          <button @click="setShotClock(14)" :disabled="!canManageGame"
            class="h-9 px-3 rounded-lg text-xs font-bold border border-dark-700 bg-dark-800 text-white hover:bg-dark-700 transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0">
            14秒
          </button>
          <button @click="toggleShotClock" :disabled="!canManageGame"
            class="h-9 px-3 rounded-lg text-xs font-bold border bg-dark-800 transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0"
            :class="shotClockRunning ? 'border-amber-500/40 text-amber-300 hover:bg-dark-700' : 'border-green-500/40 text-green-300 hover:bg-dark-700'">
            {{ shotClockRunning ? '⏸ 暂停进攻' : '▶ 启动进攻' }}
          </button>
        </template>

        <div class="flex-1"></div>

        <!-- 时间回表 -->
        <div v-if="gameStore.currentGame.status !== 'pending'"
          class="flex items-center gap-1.5 h-9 px-2.5 rounded-lg bg-dark-850 border border-dark-700/60 flex-shrink-0">
          <span class="text-[10px] font-bold tracking-widest text-dark-500">回表</span>
          <input v-model="backMin" type="number" min="0" max="59" inputmode="numeric"
            class="w-10 h-6 px-1 rounded bg-dark-900 border border-dark-700 text-center text-xs text-white tabular-nums focus:border-primary-500 outline-none" />
          <span class="text-dark-500 text-xs">:</span>
          <input v-model="backSec" type="number" min="0" max="59" inputmode="numeric"
            class="w-10 h-6 px-1 rounded bg-dark-900 border border-dark-700 text-center text-xs text-white tabular-nums focus:border-primary-500 outline-none" />
          <button @click="applyBack" :disabled="!canManageGame"
            class="h-6 px-2.5 rounded text-[11px] font-bold bg-primary-600 text-white hover:bg-primary-500 transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed">
            设定
          </button>
        </div>

        <!-- 加时：在剩余基础上增加 N 秒（N 由记录员输入） -->
        <div v-if="gameStore.currentGame.status !== 'pending'"
          class="flex items-center gap-1.5 h-9 px-2.5 rounded-lg bg-dark-850 border border-dark-700/60 flex-shrink-0">
          <span class="text-[10px] font-bold tracking-widest text-dark-500">加时</span>
          <input v-model="addSecs" type="number" min="0" max="600" inputmode="numeric"
            class="w-12 h-6 px-1 rounded bg-dark-900 border border-dark-700 text-center text-xs text-white tabular-nums focus:border-primary-500 outline-none" />
          <button @click="addGameClock(addSecs)" :disabled="!canManageGame"
            class="h-6 px-2.5 rounded text-[11px] font-bold bg-primary-600 text-white hover:bg-primary-500 transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed">
            ＋{{ addSecs === '' ? 0 : addSecs }}秒
          </button>
        </div>
      </div>

      <!-- 操控按钮区（功能键统一样式：同高 / 同圆角 / 同字号 / 中性深底 + 语义色） -->
      <div class="px-2 sm:px-3 py-2 flex flex-wrap items-center gap-2 border-b border-dark-700/30 bg-dark-850/50">
        <!-- 开始 -->
        <button v-if="gameStore.currentGame.status === 'pending'" @click="startGame" :disabled="starting || !canManageGame"
          class="h-9 px-3 rounded-lg text-xs font-bold text-white transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed"
          :class="starting ? 'bg-green-800 text-green-300' : 'bg-green-600 hover:bg-green-500'">
          {{ starting ? '开始中' : '开始' }}
        </button>

        <!-- 结束 -->
        <button v-if="gameStore.currentGame.status === 'active'" @click="endGame" :disabled="ending || !canManageGame"
          class="h-9 px-3 rounded-lg text-xs font-bold text-white transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed"
          :class="ending ? 'bg-red-800 text-red-300' : 'bg-red-600 hover:bg-red-500'">
          {{ ending ? '结束中' : '结束' }}
        </button>

        <!-- 暂停/继续（正式制节间休息时显示"开始第X节"）——唯一主控高亮 -->
        <button v-if="gameStore.currentGame.status === 'active'" @click="togglePause"
          class="h-9 px-4 rounded-lg text-xs sm:text-sm font-black transition-all active:scale-95 whitespace-nowrap"
          :class="isPaused
            ? 'bg-green-500 text-white shadow-[0_0_14px_rgba(34,197,94,0.4)]'
            : 'bg-amber-400 text-black shadow-[0_0_14px_rgba(251,191,36,0.35)]'">
          {{ isPaused ? (quarterBreak ? `▶开始${quarterLabel(gameStore.currentGame.current_quarter, gameStore.currentGame.quarters)}` : '▶继续') : '⏸ 暂停' }}
        </button>

        <!-- 本节结束（仅正式制） -->
        <button v-if="gameStore.currentGame.status === 'active' && gameStore.currentGame.game_type !== 'entertainment'" @click="endQuarter()"
          :disabled="!canManageGame || isPaused"
          class="h-9 px-3 rounded-lg text-xs font-bold border border-dark-700 transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed"
          :class="isPaused ? 'bg-dark-800 text-dark-600' : 'bg-dark-800 text-dark-300 hover:bg-dark-700 hover:text-white'">
          本节结束
        </button>

        <!-- 强制同步 -->
        <button @click="handleForceSync" :disabled="syncing"
          class="h-9 px-3 rounded-lg text-xs font-bold border border-dark-700 transition-all active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed"
          :class="syncing ? 'bg-dark-800 text-dark-600' : 'bg-dark-800 text-dark-300 hover:bg-dark-700 hover:text-white'">
          {{ syncing ? '同步中' : '⬆ 同步' }}
        </button>

        <div class="flex-1"></div>

        <!-- 录队切换 -->
        <div class="flex items-center gap-1">
          <button v-for="opt in recordModeOptions" :key="opt.value"
            @click="recordMode = opt.value"
            class="h-9 px-3 rounded-lg text-[11px] font-bold border transition-all whitespace-nowrap"
            :class="recordMode === opt.value
              ? 'bg-primary-600 border-primary-500 text-white'
              : 'bg-dark-800 border-dark-700 text-dark-300 hover:text-white'">
            {{ opt.label }}
          </button>
        </div>

        <!-- 状态 -->
        <div v-if="isPaused" class="flex items-center gap-1 text-amber-400 text-[10px] flex-shrink-0">
          <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
          <span>已暂停</span>
        </div>
        <div v-else-if="gameStore.currentGame.status === 'active'" class="flex items-center gap-1 text-green-400 text-[10px] flex-shrink-0">
          <span class="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse"></span>
          LIVE
        </div>
        <div v-if="gameStore.currentGame.status === 'finished'" class="text-primary-400 text-[10px] flex-shrink-0">
          已结束
        </div>
      </div>

      <!-- 主内容：两队面板 -->
      <div class="flex gap-0 overflow-hidden" style="height: calc(100vh - 336px);">
        <!-- 主队面板 -->
        <TeamPanel
          v-show="recordMode === 'both' || recordMode === 'home'"
          ref="homePanelRef"
          :team="gameStore.currentGame.home_team"
          :lineup="gameStore.homeLineup"
          :game-id="gameId"
          :team-id="gameStore.currentGame.home_team_id"
          :game-type="gameStore.currentGame.game_type"
          :game-status="gameStore.currentGame.status"
          :team-fouls="teamFouls.home"
          :timeouts-remaining="homeTimeoutsRemaining"
          :readonly="!canRecord"
          :lineup-readonly="!canManageLineup"
          :last-undo-action="lastUndoAction"
          :record-only="recordMode !== 'both'"
          @record="handleRecord"
          @lineup-change="handleLineupChange"
          @undo="undoAction"
          @timeout="handleTimeout"
          class="flex-1 min-w-0"
        />

        <!-- 分隔线 -->
        <div v-if="recordMode === 'both'" class="w-px bg-dark-700/50 flex-shrink-0"></div>

        <!-- 客队面板 -->
        <TeamPanel
          v-show="recordMode === 'both' || recordMode === 'away'"
          ref="awayPanelRef"
          :team="gameStore.currentGame.away_team"
          :lineup="gameStore.awayLineup"
          :game-id="gameId"
          :team-id="gameStore.currentGame.away_team_id"
          :game-type="gameStore.currentGame.game_type"
          :game-status="gameStore.currentGame.status"
          :team-fouls="teamFouls.away"
          :timeouts-remaining="awayTimeoutsRemaining"
          :readonly="!canRecord"
          :lineup-readonly="!canManageLineup"
          :last-undo-action="lastUndoAction"
          :record-only="recordMode !== 'both'"
          @record="handleRecord"
          @lineup-change="handleLineupChange"
          @undo="undoAction"
          @timeout="handleTimeout"
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
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useGameStore } from '@/stores/game'
import { useAuthStore } from '@/stores/auth'
import { fmtClock, quarterLabel } from '@/utils/helpers'
import { supabase } from '@/utils/supabase'
import { useTeamFouls } from '@/composables/useTeamFouls'
import { timeoutsRemaining, timeoutMax, timeoutKey } from '@/composables/useTimeouts'
import TeamPanel from '@/components/game/TeamPanel.vue'

const route = useRoute()
const gameStore = useGameStore()
const auth = useAuthStore()
const gameId = route.params.id

const loading = ref(true)
const toastMsg = ref('')
const starting = ref(false)
const ending = ref(false)
const recordMode = ref('both')
const recordModeOptions = [
  { value: 'both', label: '两队' },
  { value: 'home', label: '仅主队' },
  { value: 'away', label: '仅客队' }
]
let toastTimer

const homePanelRef = ref(null)
const awayPanelRef = ref(null)
const syncing = ref(false)

// ── 进攻时间（24 秒）与时间回表 ──
const backMin = ref('')
const backSec = ref('')
// 加时秒数：在剩余时间基础上增加 N 秒（N 由记录员自行输入）
const addSecs = ref(10)

// ── 队伍犯规（本节）── 组合式函数与详情页共用，含娱乐赛虚拟节逻辑
const { teamFouls, virtualQuarter, loadTeamFouls } = useTeamFouls(
  () => gameStore.currentGame,
  gameId,
  () => gameStore.pendingActions
)

// ── 暂停次数（FIBA：上半场 2 次 / 下半场 3 次，按半场独立计算）──
const homeTimeoutsRemaining = computed(() => timeoutsRemaining(gameStore.currentGame, 'home'))
const awayTimeoutsRemaining = computed(() => timeoutsRemaining(gameStore.currentGame, 'away'))

// 记录/撤销一次暂停：先乐观更新本地，失败回滚；成功由 realtime 覆盖为服务端值
// 记录暂停（非撤销）时同步停表——正规比赛中请求暂停即停表
async function handleTimeout({ teamId, delta }) {
  const g = gameStore.currentGame
  if (!g || !teamId || !canManageGame.value) return
  const side = teamId === g.home_team_id ? 'home' : 'away'
  const key = timeoutKey(g, side)
  const max = timeoutMax(g.current_quarter, g.quarters)
  const prev = Number(g[key]) || 0
  const next = Math.max(0, Math.min(max, prev + delta))
  if (next === prev) return
  gameStore.currentGame = { ...g, [key]: next }
  try {
    const { error } = await supabase.rpc('record_timeout', {
      p_game_id: gameId, p_team_id: teamId, p_delta: delta
    })
    if (error) throw error
  } catch (e) {
    gameStore.currentGame = { ...gameStore.currentGame, [key]: prev }
    showToast('❌ 暂停记录失败')
    return
  }
  if (delta > 0 && g.status === 'active') {
    if (!g.is_paused) {
      try { await setPaused(true, 'team') } catch (e) { /* 停表失败不影响暂停计数 */ }
      showToast('⏸ 已记录暂停，比赛已停表')
    } else {
      // 已在暂停中记录队伍暂停：把标记切为 team，大屏随即进入轮播
      try { await supabase.rpc('set_pause_kind', { p_game_id: gameId, p_kind: 'team' }) } catch (e) {}
      showToast('⏸ 已记录暂停')
    }
  } else {
    showToast(delta > 0 ? '⏸ 已记录暂停' : '↩ 已撤销暂停')
  }
}

// ── 下一次球权（裁判换节/争球提示，realtime 自动同步）──
const possessionHome = computed(() => gameStore.currentGame?.possession_home === true)
const possessionTeamName = computed(() => {
  const g = gameStore.currentGame
  if (!g) return ''
  const t = possessionHome.value ? g.home_team : g.away_team
  return t?.short_name || t?.name || (possessionHome.value ? '主队' : '客队')
})
const possessionLabel = computed(() =>
  quarterBreak.value ? `第${gameStore.currentGame?.current_quarter || 1}节球权` : '下次球权'
)
const possessionStyle = computed(() => {
  const g = gameStore.currentGame
  if (!g || g.possession_home == null) return {}
  const color = possessionHome.value
    ? (g.home_team?.color || '#ffffff')
    : (g.away_team?.color || '#ffffff')
  return { color, borderColor: color + '99', backgroundColor: color + '1a' }
})

async function togglePossession() {
  const g = gameStore.currentGame
  if (!g || !canManageGame.value) return
  const cur = g.possession_home
  const next = cur == null ? true : !cur
  gameStore.currentGame = { ...g, possession_home: next }
  try {
    const { error } = await supabase.rpc('set_possession', { p_game_id: gameId, p_home: next })
    if (error) throw error
    showToast(`${next ? '◀' : '▶'} 下次球权：${possessionTeamName.value}`)
  } catch (e) {
    gameStore.currentGame = { ...gameStore.currentGame, possession_home: cur }
    showToast('❌ 球权设置失败')
  }
}

async function handleForceSync() {
  if (syncing.value) return
  syncing.value = true
  try {
    const result = await gameStore.forceSyncToServer()
    showToast(result.message)
    loadTeamFouls()
  } catch (e) {
    showToast('同步失败：' + e.message)
  } finally {
    syncing.value = false
  }
}

// ── 权限逻辑 ──
const isTeamAdmin = computed(() => {
  if (!gameStore.currentGame) return false
  const uid = auth.user?.id
  if (!uid) return false
  return gameStore.currentGame.home_team?.owner_id === uid
    || gameStore.currentGame.away_team?.owner_id === uid
})

const isPaused = ref(false)

// ── 正式制倒计时 ──
const isOfficial = computed(() => gameStore.currentGame?.game_type === 'official')
// 计时控制条：正式制且未取消；未开赛时仅对可管理人员显示（用于赛前设定 24 秒开关）
const showClockBar = computed(() => {
  const g = gameStore.currentGame
  if (!g || !isOfficial.value || g.status === 'cancelled') return false
  if (g.status === 'pending') return canManageGame.value
  return true
})
const clockRunning = computed(() =>
  isOfficial.value && gameStore.currentGame?.status === 'active' && !isPaused.value
)
const nowTs = ref(Date.now())
const quarterBreak = ref(false)   // 节间休息标记（切节后由 RPC 置为暂停）
const endingQuarter = ref(false)
let clockTimer = null
let autoEndFired = false         // 归零自动切节防重

// 剩余秒数：以数据库 quarter_clock 为基准，用 clock_updated_at 推算已流逝时间（暂停期间不走秒）
const remainingSecs = computed(() => {
  const g = gameStore.currentGame
  if (!g || !isOfficial.value) return 0
  const base = g.quarter_clock ?? 0
  if (!clockRunning.value) return base
  if (!g.clock_updated_at) return base
  const anchor = new Date(g.clock_updated_at).getTime()
  if (!anchor || Number.isNaN(anchor)) return base
  // elapsed 钳制为非负：数据库时钟与本地偏差会让差值为负，floor 后变 -1 导致显示多 1 秒
  const elapsed = Math.max(0, Math.floor((nowTs.value - anchor) / 1000))
  return Math.max(0, base - elapsed)
})

// ── 进攻时间（24 秒）── 与比赛时钟联动：比赛时钟停表（暂停/节间/未开赛/已结束）时必停，
// 比赛进行中记录员可通过「暂停进攻 / 启动进攻」单独控制走表
const shotClockRunning = computed(() =>
  clockRunning.value && !!gameStore.currentGame?.shot_clock_running
)
const shotClockSecs = computed(() => {
  const g = gameStore.currentGame
  if (!g || !isOfficial.value) return 0
  const base = g.shot_clock ?? 24
  if (!shotClockRunning.value) return Math.max(0, base)
  if (!g.shot_clock_updated_at) return Math.max(0, base)
  const anchor = new Date(g.shot_clock_updated_at).getTime()
  if (!anchor || Number.isNaN(anchor)) return Math.max(0, base)
  const elapsed = Math.max(0, Math.floor((nowTs.value - anchor) / 1000))
  return Math.max(0, base - elapsed)
})
const shotClockDanger = computed(() => shotClockRunning.value && shotClockSecs.value <= 5)

// 24 秒功能开关（默认开启；字段缺失时按开启处理，兼容尚未执行 SQL 的旧库）
const shotClockEnabled = computed(() => gameStore.currentGame?.shot_clock_enabled !== false)

// 倒计时归零 → 自动结束本节（切到下一节或全场结束）
watch(remainingSecs, (v) => {
  if (v === 0 && clockRunning.value && !autoEndFired && !endingQuarter.value) {
    autoEndFired = true
    endQuarter(true)
  }
})
// 切节 / 恢复后允许再次自动切节
watch(() => gameStore.currentGame?.current_quarter, () => { autoEndFired = false })

// 监听 gameStore 中 is_paused 字段的实时变化（其他设备暂停/继续时同步）
watch(() => gameStore.currentGame?.is_paused, (val) => {
  if (val !== undefined) isPaused.value = !!val
})

const canRecord = computed(() => {
  if (isPaused.value) return false
  if (!gameStore.currentGame) return false
  if (['finished', 'cancelled'].includes(gameStore.currentGame.status)) return false
  const uid = auth.user?.id
  if (!uid) return false
  // 管理员、记录员角色、球队管理员都可以录入
  return auth.isAdmin || auth.role === 'recorder' || isTeamAdmin.value
})

const canManageGame = computed(() => {
  if (!gameStore.currentGame) return false
  if (['finished', 'cancelled'].includes(gameStore.currentGame.status)) return false
  const uid = auth.user?.id
  if (!uid) return false
  return auth.isAdmin || auth.role === 'recorder' || isTeamAdmin.value
})

// 阵容调整权限（不受暂停影响）
const canManageLineup = computed(() => {
  if (!gameStore.currentGame) return false
  if (['finished', 'cancelled'].includes(gameStore.currentGame.status)) return false
  const uid = auth.user?.id
  if (!uid) return false
  return auth.isAdmin || auth.role === 'recorder' || isTeamAdmin.value
})

onMounted(async () => {
  // 确保清空上一场比赛的操作栈
  gameStore.actionStack = []
  clockTimer = setInterval(() => { nowTs.value = Date.now() }, 1000)
  try {
    await gameStore.loadGame(gameId)
    // 从数据库同步暂停状态
    isPaused.value = !!gameStore.currentGame?.is_paused
    gameStore.subscribeRealtime(gameId)
    gameStore.startPeriodicSync()
    loadTeamFouls()
  } catch (e) {
    console.error('加载比赛失败:', e)
  } finally {
    loading.value = false
  }
})

// 比分 / 节次变化时刷新队伍犯规（娱乐赛虚拟节随领先方得分切换；其他设备录入也走这里）
let foulsTimer = null
watch(() => [gameStore.currentGame?.home_score, gameStore.currentGame?.away_score, gameStore.currentGame?.current_quarter], () => {
  clearTimeout(foulsTimer)
  foulsTimer = setTimeout(loadTeamFouls, 400)
})

onUnmounted(() => {
  if (clockTimer) { clearInterval(clockTimer); clockTimer = null }
  gameStore.unsubscribeRealtime()
  gameStore.stopPeriodicSync()
})

// 录分：本地状态在 recordAction 内同步更新（乐观更新），不等待网络往返
// 网络写入在后台进行，失败自动进入离线队列，按钮点击始终秒响应
function handleRecord({ playerId, teamId, actionType, playerName }) {
  gameStore.recordAction(playerId, teamId, actionType, 1, playerName).catch(e => {
    console.warn('[handleRecord] 后台同步失败（已入队）:', e?.message)
  })
  showToast(actionLabel(actionType))
  // 刷新两个面板的实时数据（读的是本地 store，立即生效）
  homePanelRef.value?.refreshStats()
  awayPanelRef.value?.refreshStats()
  loadTeamFouls()
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
    // 先建球员快照（含 12 人名单校验：超员队未选名单会在此拦截，比赛不会开始）
    const { error: snapErr } = await supabase.rpc('snapshot_game_players', { p_game_id: gameId })
    if (snapErr) throw new Error(snapErr.message)
    const { error } = await supabase.rpc('update_game_status', {
      p_game_id: gameId,
      p_status: 'active',
      p_started_at: new Date().toISOString()
    })
    if (error) throw error
    showToast('比赛已开始')
    // 直接更新本地状态，不重新 loadGame（保留赛前阵容）
    if (gameStore.currentGame) {
      gameStore.currentGame.status = 'active'
      gameStore.currentGame.started_at = new Date().toISOString()
      gameStore.currentGame.clock_updated_at = new Date().toISOString()
      // 开始比赛：进攻时间复位为 24，随比赛时钟一起走表（关闭 24 秒功能时不动）
      if (shotClockEnabled.value) {
        gameStore.currentGame.shot_clock = 24
        gameStore.currentGame.shot_clock_running = true
        gameStore.currentGame.shot_clock_updated_at = new Date().toISOString()
      }
    }
    // 全员快照已在开赛前完成（含名单过滤），此处仅兜底补全
    supabase.rpc('snapshot_game_players', { p_game_id: gameId })
      .then(({ error: snapErr }) => {
        if (snapErr) console.warn('[snapshot] 全员快照失败:', snapErr.message)
      })
    // 进攻时间显式写库（24 秒 + 走表），保证大屏等其他端与记录页口径一致
    if (shotClockEnabled.value) {
      supabase.rpc('set_shot_clock', { p_game_id: gameId, p_seconds: 24, p_running: true })
        .then(({ error: scErr }) => {
          if (scErr) console.warn('[shot_clock] 进攻时间初始化失败:', scErr.message)
        })
    }
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

async function setPaused(newVal, kind = 'clock') {
  // 必须在翻转 isPaused 之前取值：翻转后 remainingSecs 会切回旧基准值，导致显示闪跳
  const frozenSecs = remainingSecs.value
  const params = {
    p_game_id: gameId,
    p_status: gameStore.currentGame.status,
    p_is_paused: newVal
  }
  // 正式制暂停时固化当前剩余秒数，恢复后从暂停点继续走秒
  if (newVal && isOfficial.value) params.p_clock_remaining = frozenSecs
  const { error } = await supabase.rpc('update_game_status', params)
  if (error) throw error
  // 暂停类型标记：'team' 队伍暂停（大屏轮播）/ 'clock' 总暂停停表（大屏停留比分页）；恢复时清空
  try {
    await supabase.rpc('set_pause_kind', { p_game_id: gameId, p_kind: newVal ? kind : null })
  } catch (e) { /* 标记失败不影响停表；需先在 Supabase 执行 add_pause_kind.sql */ }
  isPaused.value = newVal
  gameStore.currentGame.is_paused = newVal
  if (isOfficial.value) {
    // 暂停：写入冻结秒数；恢复：重置基准时间，避免用暂停期间的旧锚点倒扣
    if (newVal) gameStore.currentGame.quarter_clock = frozenSecs
    gameStore.currentGame.clock_updated_at = new Date().toISOString()
    // 进攻时间随比赛时钟联动：暂停冻结当前剩余值，恢复从冻结值继续走表（与 update_game_status 一致）
    // 关闭 24 秒功能时不参与联动，避免重新开启时出现残值
    if (shotClockEnabled.value) {
      const g = gameStore.currentGame
      if (newVal) g.shot_clock = shotClockSecs.value
      g.shot_clock_running = !newVal
      g.shot_clock_updated_at = new Date().toISOString()
    }
  }
  if (!newVal) quarterBreak.value = false  // 恢复 = 开始下一节 / 继续比赛
}

// ── 进攻时间操作（24 / 14 / 暂停启动）──
// secs 为 null 表示不改变数值（仅切换走表状态），与 set_shot_clock 语义一致
async function applyShotClock(secs, running) {
  const g = gameStore.currentGame
  if (!g || !canManageGame.value) return null
  const prev = { shot_clock: g.shot_clock, shot_clock_running: g.shot_clock_running, shot_clock_updated_at: g.shot_clock_updated_at }
  const nextValue = secs != null ? secs : shotClockSecs.value
  gameStore.currentGame = {
    ...g,
    shot_clock: nextValue,
    shot_clock_running: running,
    shot_clock_updated_at: new Date().toISOString()
  }
  try {
    const { error } = await supabase.rpc('set_shot_clock', { p_game_id: gameId, p_seconds: secs, p_running: running })
    if (error) throw error
  } catch (e) {
    gameStore.currentGame = { ...gameStore.currentGame, ...prev }
    showToast('❌ 进攻时间操作失败')
    return null
  }
  return nextValue
}

// 重置进攻时间（24 / 14）：保持当前走表状态（比赛停表或已单独暂停进攻时保持停表）
async function setShotClock(secs) {
  const v = await applyShotClock(secs, shotClockRunning.value)
  if (v != null) showToast(`⏱ 进攻时间重置为 ${v} 秒`)
}

// 单独启停进攻时间：比赛进行中才可操作；比赛时钟停表时进攻时间必停
async function toggleShotClock() {
  if (!clockRunning.value) {
    showToast('比赛时钟未走表，进攻时间已同步停止')
    return
  }
  const running = shotClockRunning.value
  const v = await applyShotClock(null, !running)
  if (v != null) showToast(running ? '⏸ 进攻时间已暂停' : '▶ 进攻时间已启动')
}

// ── 24 秒功能开关 ──
// 关闭：本页隐藏进攻时间操作区，大屏同步隐藏（通过 games 表实时同步）
// 开启：复位为 24 秒；比赛进行中则随比赛时钟一起走表
async function toggleShotClockEnabled() {
  const g = gameStore.currentGame
  if (!g || !canManageGame.value) return
  const next = !shotClockEnabled.value
  const prev = g.shot_clock_enabled
  const prevClock = { shot_clock: g.shot_clock, shot_clock_running: g.shot_clock_running, shot_clock_updated_at: g.shot_clock_updated_at }
  // 乐观更新：开关立即响应
  gameStore.currentGame = {
    ...g,
    shot_clock_enabled: next,
    shot_clock_running: false,
    shot_clock_updated_at: new Date().toISOString()
  }
  try {
    const { error } = await supabase.rpc('set_shot_clock_enabled', { p_game_id: gameId, p_enabled: next })
    if (error) throw error
  } catch (e) {
    gameStore.currentGame = { ...gameStore.currentGame, shot_clock_enabled: prev, ...prevClock }
    const msg = String(e?.message || '')
    showToast(msg.includes('function') || msg.includes('does not exist')
      ? '❌ 请先在 Supabase 执行 add_shot_clock_toggle.sql'
      : '❌ 切换失败：' + (msg || '未知错误'))
    return
  }
  if (next) {
    // 重新开启：统一复位为 24 秒（比赛进行中随比赛时钟走表，未走表则停表等待）
    await applyShotClock(24, clockRunning.value)
    showToast(clockRunning.value ? '🕐 进攻计时已开启（24 秒）' : '🕐 进攻计时已开启（停表，开赛后自动走表）')
  } else {
    showToast('🚫 进攻计时已关闭（大屏同步隐藏）')
  }
}

// ── 时间回表：把比赛剩余时间设定为指定秒数（突发状况校正）──
async function setGameClockBack(totalSecs) {
  const g = gameStore.currentGame
  if (!g || !canManageGame.value) return
  const secs = Math.max(0, Math.round(totalSecs))
  if (!Number.isFinite(secs)) return
  const prev = { quarter_clock: g.quarter_clock, clock_updated_at: g.clock_updated_at }
  gameStore.currentGame = { ...g, quarter_clock: secs, clock_updated_at: new Date().toISOString() }
  try {
    const { error } = await supabase.rpc('set_quarter_clock', { p_game_id: gameId, p_seconds: secs })
    if (error) throw error
  } catch (e) {
    gameStore.currentGame = { ...gameStore.currentGame, ...prev }
    showToast('❌ 回表失败')
    return
  }
  showToast(`⏱ 已回表至 ${fmtClock(secs)}`)
}

// 加时：在当前剩余时间基础上增加 N 秒
function addGameClock(delta) {
  const d = Math.round(Number(delta))
  if (!Number.isFinite(d) || d <= 0) {
    showToast('请输入要增加的秒数')
    return
  }
  setGameClockBack(remainingSecs.value + d)
}

// 设定回表：按输入的 分/秒 覆盖剩余时间
function applyBack() {
  const m = parseInt(backMin.value, 10)
  const s = parseInt(backSec.value, 10)
  if ((backMin.value === '' && backSec.value === '') || (Number.isNaN(m) && Number.isNaN(s))) {
    showToast('请输入要回表到的分/秒')
    return
  }
  setGameClockBack((Number.isNaN(m) ? 0 : m) * 60 + (Number.isNaN(s) ? 0 : s))
}

async function togglePause() {
  const newVal = !isPaused.value
  try {
    await setPaused(newVal)
    showToast(isPaused.value ? '⏸ 比赛已暂停' : '▶ 比赛继续')
  } catch (e) {
    showToast('❌ 操作失败')
  }
}

async function endQuarter(auto = false) {
  if (endingQuarter.value) return
  if (!auto && !confirm('确认结束本节？将进入节间休息。')) return
  endingQuarter.value = true
  try {
    const fromQ = gameStore.currentGame?.current_quarter || 1
    const { data, error } = await supabase.rpc('end_quarter', {
      p_game_id: gameId,
      p_from_quarter: fromQ
    })
    if (error) throw error
    // 乐观锁冲突：其他设备已切节，同步状态即可
    if (data?.stale) {
      showToast(`其他设备已切换至第${data.quarter}节`)
      await gameStore.loadGame(gameId)
      return
    }
    if (data?.finished) {
      showToast('🏆 全场比赛结束')
      await gameStore.loadGame(gameId)
      await supabase.rpc('snapshot_game_players', { p_game_id: gameId })
      await calcMvp()
    } else {
      // 进入下一节（常规节或加时），节间休息（RPC 已置 is_paused=TRUE，realtime 会同步到其他设备）
      const isOt = !!data.overtime
      const g = gameStore.currentGame
      const quarters = g?.quarters || 4
      quarterBreak.value = true
      isPaused.value = true
      if (g) {
        g.current_quarter = data.quarter
        g.quarter_clock = isOt ? (g.overtime_seconds ?? 300) : (g.quarter_seconds || 600)
        g.is_paused = true
        g.clock_updated_at = new Date().toISOString()
        // 进攻时间复位（新一节/加时从 24 秒起，节间休息停表）
        g.shot_clock = 24
        g.shot_clock_running = false
        g.shot_clock_updated_at = new Date().toISOString()
      }
      showToast(isOt
        ? `🔥 常规时间战平，进入${quarterLabel(data.quarter, quarters)}（${Math.round((g?.overtime_seconds ?? 300) / 60)} 分钟）`
        : `⏱ ${quarterLabel(fromQ, quarters)}结束，休息后开始${quarterLabel(data.quarter, quarters)}`)
    }
  } catch (e) {
    showToast('❌ 切节失败：' + (e.message || '未知错误'))
  } finally {
    endingQuarter.value = false
  }
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

// 撤销：本地回滚在 store 内同步完成，网络反向写入后台执行（失败自动入队）
function undoAction(action) {
  gameStore.undoAction(action).catch(e => {
    console.warn('[undoAction] 后台同步失败（已入队）:', e?.message)
  })
  const desc = action ? `↩ 已撤销：${action.player_name || ''} ${actionLabel(action.actionType || action.action_type || '')}` : '↩ 已撤销'
  showToast(desc)
  // 刷新两个面板的实时数据（读的是本地 store，立即生效）
  homePanelRef.value?.refreshStats()
  awayPanelRef.value?.refreshStats()
  loadTeamFouls()
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
