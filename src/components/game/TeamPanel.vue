<template>
  <div class="flex flex-col h-full bg-dark-900">
    <!-- 队名栏 -->
    <div class="px-3 py-2 border-b border-dark-700/50 flex items-center justify-between"
         :style="{ borderTop: `2px solid ${team?.color || '#3b82f6'}` }">
      <h3 class="font-semibold text-sm truncate" :style="{ color: team?.color || '#94a3b8' }">
        {{ team?.name || '队伍' }}
      </h3>
      <span class="text-[10px] px-2 py-0.5 rounded-full font-medium"
            :class="gameStatus === 'active' ? 'bg-green-500/15 text-green-400' : 'bg-dark-800 text-dark-500'">
        {{ gameStatus === 'active' ? '比赛中' : '未开始' }}
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
                           hover:border-danger/30 active:scale-95 transition-all">
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
          <div class="w-6 h-6 rounded-md flex items-center justify-center text-[10px] font-bold text-white"
               :style="{ backgroundColor: team?.color || '#334155' }">
            {{ selectedPlayer.name?.charAt(0) }}
          </div>
          <span class="text-[12px] text-white font-semibold flex-1 truncate">{{ selectedPlayer.name }}</span>
          <button @click="selectedPlayer = null"
                  class="text-dark-500 hover:text-white p-1 rounded-md hover:bg-dark-700 transition-all">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <!-- 得分行 -->
        <div class="grid grid-cols-3 gap-1.5 mb-1.5">
          <button v-for="btn in scoreButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-2 rounded-lg text-[12px] font-bold text-white transition-all active:scale-95"
                  :class="btn.cls">
            {{ btn.label }}
          </button>
        </div>
        <!-- 数据行 -->
        <div class="grid grid-cols-4 gap-1">
          <button v-for="btn in statButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-1.5 rounded-lg text-[10px] font-medium border border-dark-700 bg-dark-800 text-dark-300
                         hover:bg-dark-700 hover:text-white active:scale-95 transition-all">
            {{ btn.label }}
          </button>
        </div>
        <!-- 不中行 -->
        <div class="grid grid-cols-3 gap-1.5 mt-1.5">
          <button v-for="btn in missButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-1.5 rounded-lg text-[10px] font-medium border border-dark-700/30 bg-dark-800/50 text-dark-500
                         hover:text-dark-300 hover:bg-dark-800 active:scale-95 transition-all">
            {{ btn.label }}
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
                         hover:border-primary-500/30 active:scale-95 transition-all flex-shrink-0">
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
import { ref, watch, onMounted } from 'vue'
import { supabase } from '@/utils/supabase'

const props = defineProps({
  team: Object,
  lineup: { type: Array, default: () => [] },
  gameId: String,
  teamId: String,
  gameType: String,
  gameStatus: String
})

const emit = defineEmits(['record', 'lineupChange'])

const courtPlayers = ref([])
const benchPlayers = ref([])
const selectedPlayer = ref(null)
const allTeamMembers = ref([])
const loaded = ref(false)

async function loadData() {
  if (!props.teamId || !props.gameId) return

  const { data: teamPlayerData } = await supabase
    .from('team_players')
    .select('player_id, jersey_no, players!inner(id, name, position, avatar_url)')
    .eq('team_id', props.teamId)
    .eq('is_active', true)
    .order('jersey_no')

  if (teamPlayerData) {
    allTeamMembers.value = teamPlayerData.map(m => ({
      id: m.player_id,
      jersey_no: m.jersey_no,
      name: m.players?.name || '',
      position: m.players?.position || '',
      avatar_url: m.players?.avatar_url || null
    }))
  }

  const courtIds = new Set(props.lineup.map(l => l.player_id))

  courtPlayers.value = props.lineup.map(l => ({
    id: l.player_id,
    name: l.player?.name || '',
    jersey_no: l.player?.jersey_no || '',
    position: l.player?.position || '',
    avatar_url: l.player?.avatar_url || null,
    _lineupId: l.id
  }))

  benchPlayers.value = allTeamMembers.value.filter(m => !courtIds.has(m.id))
  loaded.value = true
}

watch(() => props.lineup, () => {
  if (loaded.value) return
  loadData()
}, { immediate: true })

onMounted(() => {
  if (!loaded.value) loadData()
})

function selectPlayer(player) {
  selectedPlayer.value = selectedPlayer.value?.id === player.id ? null : player
}

function record(actionType) {
  if (!selectedPlayer.value) return
  emit('record', {
    playerId: selectedPlayer.value.id,
    teamId: props.teamId,
    actionType
  })
}

// 点击换人
async function moveToCourt(player) {
  if (courtPlayers.value.length >= 5) return
  const slotNo = courtPlayers.value.length + 1
  const ok = await addPlayerToLineup(player, slotNo)
  if (ok) {
    benchPlayers.value = benchPlayers.value.filter(p => p.id !== player.id)
    courtPlayers.value.push(player)
  }
}

async function moveToBench(player) {
  const ok = await removePlayerFromLineup(player)
  if (ok) {
    courtPlayers.value = courtPlayers.value.filter(p => p.id !== player.id)
    benchPlayers.value.push(player)
    // 如果正在录入该球员，取消选中
    if (selectedPlayer.value?.id === player.id) {
      selectedPlayer.value = null
    }
  }
}

// ── 数据库（通过 RPC 绕过 RLS）──

async function addPlayerToLineup(player, slotNo) {
  if (!props.gameId || !props.teamId) return false
  try {
    const { data, error } = await supabase.rpc('swap_player', {
      p_game_id: props.gameId,
      p_team_id: props.teamId,
      p_player_id: player.id,
      p_slot_no: slotNo,
      p_mode: 'add'
    })
    if (error) throw error
    const idx = courtPlayers.value.findIndex(p => p.id === player.id)
    if (idx >= 0 && data) {
      courtPlayers.value[idx]._lineupId = data.lineup_id
    }
    emit('lineupChange', courtPlayers.value)
    return true
  } catch (e) {
    console.error('添加球员失败:', e)
    return false
  }
}

async function removePlayerFromLineup(player) {
  if (!props.gameId || !props.teamId) return false
  try {
    const { error } = await supabase.rpc('swap_player', {
      p_game_id: props.gameId,
      p_team_id: props.teamId,
      p_player_id: player.id,
      p_mode: 'remove'
    })
    if (error) throw error
    emit('lineupChange', courtPlayers.value)
    return true
  } catch (e) {
    console.error('移除球员失败:', e)
    return false
  }
}

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
  { type: 'pf',  label: '犯规+1' },
  { type: 'oreb', label: '进攻篮板+1' },
  { type: 'dreb', label: '防守篮板+1' }
]

const missButtons = [
  { type: 'fga_miss',  label: '两分不中' },
  { type: 'fg3a_miss', label: '三分不中' },
  { type: 'fta_miss',  label: '罚球不中' }
]
</script>

<style scoped>
.slide-up-enter-active, .slide-up-leave-active { transition: all 0.15s ease; }
.slide-up-enter-from, .slide-up-leave-to { opacity: 0; transform: translateY(4px); }
</style>
