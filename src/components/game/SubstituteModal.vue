<template>
  <Teleport to="body">
    <Transition name="modal">
      <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4" @click.self="$emit('close')">
        <!-- 背景遮罩 -->
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="$emit('close')"></div>

        <!-- 弹窗 - 暗色 -->
        <div class="relative w-full sm:max-w-md bg-dark-850 sm:rounded-2xl rounded-t-2xl max-h-[80vh] flex flex-col border border-dark-700/50 shadow-glass">
          <!-- 标题 -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-dark-700/50">
            <div>
              <h3 class="font-semibold text-white">换人</h3>
              <p class="text-sm text-dark-400 mt-0.5">
                换下：<span class="text-danger-light font-medium">{{ outPlayer?.name }}</span>
              </p>
            </div>
            <button @click="$emit('close')" class="p-2 rounded-xl hover:bg-dark-800 transition-colors">
              <svg class="w-5 h-5 text-dark-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- 搜索 -->
          <div class="px-4 py-3 border-b border-dark-700/50">
            <input v-model="search" type="text" class="input" placeholder="搜索球员姓名或球衣号..." />
          </div>

          <!-- 候补球员列表 -->
          <div class="flex-1 overflow-y-auto">
            <div v-if="loading" class="flex items-center justify-center py-12">
              <svg class="w-6 h-6 animate-spin text-primary-500" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
              </svg>
            </div>
            <div v-else-if="filteredPlayers.length === 0" class="text-center py-8 text-dark-500 text-sm">
              没有可换入的球员
            </div>
            <div v-else class="divide-y divide-dark-700/30">
              <button v-for="player in filteredPlayers" :key="player.id"
                @click="selectIn(player)"
                class="w-full flex items-center gap-3 px-4 py-3 transition-colors text-left"
                :class="selectedIn?.id === player.id
                  ? 'bg-primary-600/10 border-l-2 border-primary-500'
                  : 'hover:bg-dark-800 border-l-2 border-transparent'"
              >
                <div class="w-9 h-9 rounded-full bg-primary-600/20 border border-primary-600/30
                            text-primary-400 flex items-center justify-center text-sm font-semibold flex-shrink-0">
                  {{ getInitials(player.name) }}
                </div>
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-white text-sm">{{ player.name }}</p>
                  <p class="text-xs text-dark-500">#{{ player.jersey_no || '-' }} · {{ POSITION_LABELS[player.position] || '-' }}</p>
                </div>
                <svg v-if="selectedIn?.id === player.id" class="w-5 h-5 text-primary-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- 确认按钮 -->
          <div class="px-4 py-4 border-t border-dark-700/50">
            <button @click="confirm" :disabled="!selectedIn"
              class="btn-primary w-full btn-lg"
            >
              确认换人：{{ selectedIn?.name || '请选择球员' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/utils/supabase'
import { getInitials, POSITION_LABELS } from '@/utils/helpers'

const props = defineProps({
  gameId: String,
  teamId: String,
  outPlayer: Object,
  slotNo: Number
})
const emit = defineEmits(['close', 'confirm'])

const search = ref('')
const players = ref([])
const selectedIn = ref(null)
const loading = ref(true)

const filteredPlayers = computed(() => {
  const q = search.value.trim().toLowerCase()
  return players.value.filter(p =>
    p.id !== props.outPlayer?.id &&
    (!q || p.name.toLowerCase().includes(q) || String(p.jersey_no).includes(q))
  )
})

onMounted(async () => {
  const { data } = await supabase
    .from('team_players')
    .select('player:player_id(id, name, jersey_no, position, avatar_url)')
    .eq('team_id', props.teamId)
    .eq('is_active', true)
  if (data) {
    players.value = data.map(tp => tp.player).filter(Boolean)
  }
  loading.value = false
})

function selectIn(player) {
  selectedIn.value = selectedIn.value?.id === player.id ? null : player
}

function confirm() {
  if (!selectedIn.value) return
  emit('confirm', { inPlayerId: selectedIn.value.id })
}
</script>

<style scoped>
.modal-enter-active { transition: all 0.2s ease; }
.modal-leave-active { transition: all 0.15s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-from > div:last-child { transform: translateY(20px); }
</style>
