<template>
  <div class="flex flex-col h-full bg-dark-900">
    <!-- 队名栏 -->
    <div class="px-3 py-2 border-b border-dark-700/50 flex items-center justify-between"
         :style="{ borderTop: `2px solid ${team?.color || '#3b82f6'}` }">
      <h3 class="font-semibold text-sm truncate" :style="{ color: team?.color || '#94a3b8' }">
        {{ team?.name || '队伍' }}
      </h3>
        <span class="text-[10px] px-2 py-0.5 rounded-full font-medium" :class="statusLabelColor">
          {{ statusLabel }}
        </span>
    </div>

    <!-- 上场阵容区 -->
    <div class="px-2 pt-2 pb-1">
      <div class="flex items-center justify-between px-1 mb-1.5">
        <p class="text-[11px] text-dark-400 font-semibold uppercase tracking-wider">
          上场阵容 · {{ courtPlayers.length }}/5
        </p>
      </div>
      <div class="space-y-1.5">
        <!-- 上场球员卡片 -->
        <div v-for="(player, index) in courtPlayers" :key="'c-'+player.id"
             class="flex items-center gap-2 rounded-xl px-2.5 py-2 border transition-all cursor-pointer select-none"
             :class="selectedPlayer?.id === player.id
               ? 'bg-primary-600/15 border-primary-500/60 shadow-[0_0_12px_rgba(59,130,246,0.15)]'
               : 'bg-dark-800 border-dark-700/50 hover:border-dark-600'"
             @click="selectPlayer(player)">
          <!-- 头像 -->
          <div class="w-8 h-8 rounded-lg flex-shrink-0 flex items-center justify-center text-xs font-bold text-white overflow-hidden"
               :style="{ backgroundColor: team?.color || '#334155' }">
            <img v-if="player.avatar_url" :src="player.avatar_url" class="w-full h-full object-cover" alt="">
            <span v-else>{{ player.name?.charAt(0) || '?' }}</span>
          </div>
          <!-- 信息 -->
          <div class="flex-1 min-w-0">
            <p class="text-[12px] text-white font-medium truncate leading-tight">
              <span v-if="player.jersey_no" class="text-dark-400 mr-1">#{{ player.jersey_no }}</span>{{ player.name }}
            </p>
            <p v-if="player.position" class="text-[10px] text-dark-500 mt-0.5">{{ player.position }}</p>
          </div>
          <!-- 选中和下场 -->
          <div class="flex items-center gap-1 flex-shrink-0">
            <span v-if="selectedPlayer?.id === player.id"
                  class="w-1.5 h-1.5 rounded-full bg-primary-400 animate-pulse"></span>
            <button @click.stop="moveToBench(player)"
                    class="px-2 py-1 rounded-lg text-[10px] font-medium text-dark-500
                           hover:text-danger hover:bg-danger/10 border border-transparent
                           hover:border-danger/30 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                    :disabled="!canChangeLineup">
              下场
            </button>
          </div>
        </div>

        <!-- 空位提示 -->
        <div v-for="i in (5 - courtPlayers.length)" :key="'e-'+i"
             class="flex items-center gap-2 rounded-xl px-2.5 py-2 border border-dashed border-dark-700/30">
          <div class="w-8 h-8 rounded-lg bg-dark-800 flex items-center justify-center">
            <span class="text-[10px] text-dark-600">{{ courtPlayers.length + i }}</span>
          </div>
          <span class="text-[11px] text-dark-700">空位</span>
        </div>
      </div>
    </div>

    <!-- 录入区（选中球员后展示） -->
    <Transition name="slide-up">
      <div v-if="selectedPlayer" class="px-2 py-2 border-t border-b border-dark-700/30 bg-dark-850/80">
        <div class="flex items-center gap-2 mb-2">
          <div class="w-6 h-6 rounded-md flex items-center justify-center text-[10px] font-bold text-white overflow-hidden"
               :style="{ backgroundColor: team?.color || '#334155' }">
            <img v-if="selectedPlayer.avatar_url" :src="selectedPlayer.avatar_url" class="w-full h-full object-cover" alt="">
            <span v-else>{{ selectedPlayer.name?.charAt(0) }}</span>
          </div>
          <span class="text-[12px] text-white font-semibold flex-1 truncate">{{ selectedPlayer.name }}</span>
          <button @click="selectedPlayer = null"
                  class="text-dark-500 hover:text-white p-1 rounded-md hover:bg-dark-700 transition-all">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- 实时数据面板 -->
        <div v-if="liveStats" class="grid grid-cols-7 gap-1 mb-2 px-1 py-1.5 rounded-lg bg-dark-800/60">
          <div v-for="s in liveStatItems" :key="s.key" class="text-center">
            <p class="text-[9px] text-dark-500 leading-tight">{{ s.label }}</p>
            <p class="text-[13px] font-bold leading-tight mt-0.5 stat-num"
               :class="s.highlight ? 'text-primary-400' : 'text-dark-200'"
               :data-key="s.key">
              {{ liveStats[s.key] || 0 }}
            </p>
          </div>
        </div>

        <!-- 得分行 -->
        <div class="grid grid-cols-3 gap-1.5 mb-1.5">
          <button v-for="btn in scoreButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-2 rounded-lg text-[12px] font-bold text-white transition-all active:scale-95 disabled:opacity-30 disabled:cursor-not-allowed"
                  :class="btn.cls" :disabled="!canRecord">
            {{ btn.label }}
          </button>
        </div>
        <!-- 数据行 -->
        <div class="grid grid-cols-4 gap-1">
          <button v-for="btn in statButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-1.5 rounded-lg text-[10px] font-medium border border-dark-700 bg-dark-800 text-dark-300
                         hover:bg-dark-700 hover:text-white active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                  :disabled="!canRecord">
            {{ btn.label }}
          </button>
        </div>
        <!-- 不中行 -->
        <div class="grid grid-cols-3 gap-1.5 mt-1.5">
          <button v-for="btn in missButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-1.5 rounded-lg text-[10px] font-medium border border-dark-700/30 bg-dark-800/50 text-dark-500
                         hover:text-dark-300 hover:bg-dark-800 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                  :disabled="!canRecord">
            {{ btn.label }}
          </button>
        </div>

        <!-- 撤销按钮 + 上一步操作 -->
        <div v-if="lastUndoAction" class="mt-2 flex items-center justify-between px-1 pt-1.5 border-t border-dark-700/30">
          <div class="text-left min-w-0">
            <p class="text-[9px] text-dark-600">上一步操作</p>
            <p class="text-[11px] text-orange-400 font-medium truncate max-w-[120px]">
              {{ lastUndoAction.player_name }} {{ actionLabel(lastUndoAction.actionType || lastUndoAction.action_type || '') }}
            </p>
          </div>
          <button @click="emit('undo')"
                  class="flex items-center gap-1 px-2.5 py-1 rounded-md text-[10px] font-bold text-white
                         bg-gradient-to-r from-orange-500 to-red-500
                         active:scale-95 transition-all duration-200 flex-shrink-0">
            <span class="text-xs">↩</span>
            <span>撤销</span>
          </button>
        </div>
      </div>
    </Transition>

    <!-- 备战席 -->
    <div class="flex-1 overflow-y-auto min-h-0">
      <div class="flex items-center justify-between px-3 pt-2 pb-1">
        <p class="text-[11px] text-dark-400 font-semibold uppercase tracking-wider">
          备战席 · {{ benchPlayers.length }}
        </p>
      </div>
      <div class="px-2 pb-3 space-y-1.5">
        <div v-for="player in benchPlayers" :key="'b-'+player.id"
             class="flex items-center gap-2 rounded-xl px-2.5 py-2 bg-dark-850 border border-dark-800
                    hover:border-primary-500/30 transition-all cursor-pointer select-none"
             @click="moveToCourt(player)">
          <!-- 头像 -->
          <div class="w-7 h-7 rounded-lg flex-shrink-0 flex items-center justify-center text-[10px] font-bold text-dark-400 bg-dark-800 overflow-hidden">
            <img v-if="player.avatar_url" :src="player.avatar_url" class="w-full h-full object-cover" alt="">
            <span v-else>{{ player.name?.charAt(0) || '?' }}</span>
          </div>
          <!-- 信息 -->
          <div class="flex-1 min-w-0">
            <p class="text-[11px] text-dark-300 truncate">
              <span v-if="player.jersey_no" class="text-dark-500 mr-1">#{{ player.jersey_no }}</span>{{ player.name }}
            </p>
            <p v-if="player.position" class="text-[9px] text-dark-600 mt-0.5">{{ player.position }}</p>
          </div>
          <!-- 上场按钮 -->
          <button @click.stop="moveToCourt(player)"
                  class="px-2 py-1 rounded-lg text-[10px] font-semibold text-primary-500
                         hover:bg-primary-500/10 border border-transparent
                         hover:border-primary-500/30 active:scale-95 transition-all flex-shrink-0 disabled:opacity-30 disabled:cursor-not-allowed"
                  :disabled="!canChangeLineup">
            上场
          </button>
        </div>
        <div v-if="benchPlayers.length === 0" class="px-3 py-6 text-center">
          <p class="text-[11px] text-dark-700">暂无替补球员</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, computed, onMounted } from 'vue'
import { supabase } from '@/utils/supabase'

const props = defineProps({
  team: Object,
  lineup: { type: Array, default: () => [] },
  gameId: String,
  teamId: String,
  gameType: String,
  gameStatus: String,
  readonly: { type: Boolean, default: false },
  lastUndoAction: { type: Object, default: null }
})

const emit = defineEmits(['record', 'lineupChange', 'undo'])

const courtPlayers = ref([])
const benchPlayers = ref([])
const selectedPlayer = ref(null)
const liveStats = ref(null)
const prevStats = ref(null)
const allTeamMembers = ref([])
const membersLoaded = ref(false)

const canRecord = computed(() => props.gameStatus === 'active' && !props.readonly)
const canChangeLineup = computed(() => 
  props.gameStatus !== 'finished' && props.gameStatus !== 'cancelled' && !props.readonly
)
const statusLabel = computed(() => {
  if (props.gameStatus === 'active') return '比赛中'
  if (props.gameStatus === 'finished') return '已结束'
  if (props.gameStatus === 'cancelled') return '已取消'
  return '未开始'
})
const statusLabelColor = computed(() => {
  if (props.gameStatus === 'active') return 'bg-green-500/15 text-green-400'
  return 'bg-dark-800 text-dark-500'
})

// 同步阵容：根据最新的 lineup prop 更新 courtPlayers 和 benchPlayers
function syncLineup(lineup) {
  console.log('[TeamPanel] syncLineup called, lineup count:', lineup.length, 'members loaded:', allTeamMembers.value.length)
  const courtIds = new Set(lineup.map(l => l.player_id))

  courtPlayers.value = lineup.map(l => ({
    id: l.player_id,
    name: l.player?.name || '',
    jersey_no: l.player?.jersey_no || '',
    position: l.player?.position || '',
    avatar_url: l.player?.avatar_url || null,
    _lineupId: l.id
  }))

  benchPlayers.value = allTeamMembers.value.filter(m => !courtIds.has(m.id))
}

// 初始化：加载球队全部成员（只需一次），然后同步阵容
async function loadData() {
  if (!props.teamId || !props.gameId) return

  if (!membersLoaded.value) {
    const { data: teamPlayerData } = await supabase
      .from('team_players')
      .select('player_id, jersey_no, position, players!inner(id, name, position, avatar_url)')
      .eq('team_id', props.teamId)
      .eq('is_active', true)
      .order('jersey_no')

    if (teamPlayerData) {
      allTeamMembers.value = teamPlayerData.map(m => ({
        id: m.player_id,
        jersey_no: m.jersey_no,
        name: m.players?.name || '',
        position: m.position || m.players?.position || '',
        avatar_url: m.players?.avatar_url || null
      }))
    }
    membersLoaded.value = true
  }

  syncLineup(props.lineup)
}

// 监听 lineup prop 变化（来自 gameStore realtime 更新），每次都重新同步阵容
watch(() => props.lineup, (newLineup) => {
  if (membersLoaded.value) {
    // 成员已加载，直接同步阵容
    syncLineup(newLineup)
  } else {
    // 成员还未加载，走完整初始化
    loadData()
  }
}, { immediate: true, deep: true })

onMounted(() => {
  if (!membersLoaded.value) loadData()
})

function selectPlayer(player) {
  selectedPlayer.value = selectedPlayer.value?.id === player.id ? null : player
  if (selectedPlayer.value) {
    prevStats.value = null
    loadPlayerStats()
  } else {
    liveStats.value = null
    prevStats.value = null
  }
}

async function loadPlayerStats() {
  if (!selectedPlayer.value || !props.gameId) return
  try {
    const { data } = await supabase
      .from('game_stats')
      .select('pts, reb, ast, stl, blk, tov, pf, fgm, fga, fg3m, fg3a, ftm, fta, min_played')
      .eq('game_id', props.gameId)
      .eq('player_id', selectedPlayer.value.id)
      .maybeSingle()
    liveStats.value = data || {}
  } catch {
    liveStats.value = {}
  }
}

// 每次录入后刷新选中球员的数据（由父组件调用）
async function refreshStats() {
  if (selectedPlayer.value) {
    await loadPlayerStats()
    triggerStatAnimation()
  }
}

// 检测数值变化，仅高亮变化的项
function triggerStatAnimation() {
  if (!prevStats.value || !liveStats.value) {
    prevStats.value = liveStats.value ? { ...liveStats.value } : null
    return
  }
  const changedKeys = liveStatItems
    .filter(s => (liveStats.value[s.key] || 0) !== (prevStats.value[s.key] || 0))
    .map(s => s.key)
  if (changedKeys.length) {
    requestAnimationFrame(() => {
      const els = document.querySelectorAll('.stat-num')
      els.forEach(el => {
        const key = el.dataset.key
        if (changedKeys.includes(key)) {
          el.classList.remove('flash')
          void el.offsetWidth
          el.classList.add('flash')
        }
      })
    })
  }
  prevStats.value = { ...liveStats.value }
}

const liveStatItems = [
  { key: 'pts', label: '得分', highlight: true },
  { key: 'reb', label: '篮板' },
  { key: 'ast', label: '助攻' },
  { key: 'stl', label: '抢断' },
  { key: 'blk', label: '盖帽' },
  { key: 'pf', label: '犯规' },
  { key: 'tov', label: '失误' }
]

function record(actionType) {
  if (!selectedPlayer.value || !canRecord.value) return
  emit('record', {
    playerId: selectedPlayer.value.id,
    teamId: props.teamId,
    actionType,
    playerName: selectedPlayer.value.name
  })
}

// 点击换人
async function moveToCourt(player) {
  if (!canChangeLineup.value) return
  console.log('[TeamPanel] moveToCourt called', player.name, 'court count:', courtPlayers.value.length)
  if (courtPlayers.value.length >= 5) {
    console.warn('[TeamPanel] court is full, cannot add player')
    return
  }
  const slotNo = courtPlayers.value.length + 1
  const ok = await addPlayerToLineup(player, slotNo)
  console.log('[TeamPanel] addPlayerToLineup result:', ok)
  if (ok) {
    benchPlayers.value = benchPlayers.value.filter(p => p.id !== player.id)
    courtPlayers.value.push(player)
  }
}

async function moveToBench(player) {
  if (!canChangeLineup.value) return
  console.log('[TeamPanel] moveToBench called', player.name)
  const ok = await removePlayerFromLineup(player)
  console.log('[TeamPanel] removePlayerFromLineup result:', ok)
  if (ok) {
    courtPlayers.value = courtPlayers.value.filter(p => p.id !== player.id)
    benchPlayers.value.push(player)
    if (selectedPlayer.value?.id === player.id) {
      selectedPlayer.value = null
    }
  }
}

// ── 数据库（通过 RPC 绕过 RLS）──

async function addPlayerToLineup(player, slotNo) {
  if (!props.gameId || !props.teamId) {
    console.error('[TeamPanel] missing gameId or teamId', props.gameId, props.teamId)
    return false
  }
  try {
    console.log('[TeamPanel] calling swap_player add', { gameId: props.gameId, teamId: props.teamId, playerId: player.id, slotNo })
    const { data, error } = await supabase.rpc('swap_player', {
      p_game_id: props.gameId,
      p_team_id: props.teamId,
      p_player_id: player.id,
      p_slot_no: slotNo,
      p_mode: 'add'
    })
    console.log('[TeamPanel] swap_player add response:', { data, error })
    if (error) throw error
    const idx = courtPlayers.value.findIndex(p => p.id === player.id)
    if (idx >= 0 && data) {
      courtPlayers.value[idx]._lineupId = data.lineup_id
    }
    emit('lineupChange', courtPlayers.value)
    return true
  } catch (e) {
    console.error('[TeamPanel] addPlayerToLineup error:', e)
    return false
  }
}

async function removePlayerFromLineup(player) {
  if (!props.gameId || !props.teamId) {
    console.error('[TeamPanel] missing gameId or teamId', props.gameId, props.teamId)
    return false
  }
  try {
    console.log('[TeamPanel] calling swap_player remove', { gameId: props.gameId, teamId: props.teamId, playerId: player.id })
    const { data, error } = await supabase.rpc('swap_player', {
      p_game_id: props.gameId,
      p_team_id: props.teamId,
      p_player_id: player.id,
      p_mode: 'remove'
    })
    console.log('[TeamPanel] swap_player remove response:', { data, error })
    if (error) throw error
    emit('lineupChange', courtPlayers.value)
    return true
  } catch (e) {
    console.error('[TeamPanel] removePlayerFromLineup error:', e)
    return false
  }
}

defineExpose({ refreshStats })

const scoreButtons = [
  { type: 'pts_1', label: '罚球 +1', cls: 'bg-yellow-600/80' },
  { type: 'pts_2', label: '两分 +2', cls: 'bg-blue-600/80' },
  { type: 'pts_3', label: '三分 +3', cls: 'bg-purple-600/80' }
]

const statButtons = [
  { type: 'reb', label: '篮板+1' },
  { type: 'ast', label: '助攻+1' },
  { type: 'stl', label: '抢断+1' },
  { type: 'blk', label: '盖帽+1' },
  { type: 'tov', label: '失误+1' },
  { type: 'pf',  label: '犯规+1' }
]

const missButtons = [
  { type: 'fga_miss',  label: '两分不中' },
  { type: 'fg3a_miss', label: '三分不中' },
  { type: 'fta_miss',  label: '罚球不中' }
]

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
.slide-up-enter-active, .slide-up-leave-active { transition: all 0.15s ease; }
.slide-up-enter-from, .slide-up-leave-to { opacity: 0; transform: translateY(4px); }

/* 数值变化闪烁动画（简洁） */
.stat-num {
  transition: color 0.2s ease;
}
.stat-num.flash {
  animation: statFlash 0.3s ease;
}
@keyframes statFlash {
  0% { color: #f97316; }
  100% { color: inherit; }
}
</style>
