<template>
  <div class="page-container">
    <!-- 头部 -->
    <div class="flex items-center justify-between mb-5">
      <div>
        <h1 class="page-title">赛事大厅</h1>
        <p class="text-sm text-dark-500 mt-1">共 <span class="text-accent-400 font-semibold">{{ total }}</span> 场赛事</p>
      </div>
      <router-link v-if="auth.isAdmin" to="/games/create" class="btn-primary">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        创建赛事
      </router-link>
    </div>

    <!-- 过滤器 -->
    <div class="flex gap-2 mb-5 overflow-x-auto pb-1 scrollbar-none">
      <button v-for="f in filters" :key="f.value"
        @click="activeFilter = f.value"
        class="flex-shrink-0 px-4 py-1.5 rounded-xl text-sm font-semibold transition-all duration-200"
        :class="activeFilter === f.value
          ? 'bg-primary-600 text-white shadow-neon-blue'
          : 'bg-dark-800 text-dark-400 border border-dark-700 hover:text-white hover:border-dark-600'"
      >
        {{ f.label }}
      </button>
    </div>

    <!-- 赛事列表 -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 4" :key="i" class="skeleton h-20 rounded-2xl"></div>
    </div>
    <!-- 加载失败 -->
    <div v-else-if="loadError" class="text-center py-20">
      <div class="text-4xl mb-4">⚠️</div>
      <p class="text-dark-400 mb-2">{{ loadError }}</p>
      <button @click="loadGames" class="mt-4 btn-primary btn-sm">重新加载</button>
    </div>
    <div v-else-if="filteredGames.length === 0" class="empty-state">
      <svg class="w-20 h-20 text-dark-600 mb-3" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.5">
        <circle cx="32" cy="32" r="20" opacity="0.5"/>
        <line x1="32" y1="12" x2="32" y2="52" opacity="0.3"/>
        <path d="M12 32 Q22 22 32 32 Q42 42 52 32" opacity="0.3" fill="none"/>
        <text x="32" y="36" text-anchor="middle" fill="currentColor" stroke="none" font-size="12" opacity="0.5">NO DATA</text>
      </svg>
      <p class="text-dark-500">暂无赛事</p>
      <router-link v-if="auth.isAdmin" to="/games/create" class="mt-3 text-sm text-primary-400 hover:text-primary-300">
        创建第一场赛事 →
      </router-link>
    </div>
    <div v-else class="space-y-3">
      <div v-for="game in filteredGames" :key="game.id" class="group relative">
        <router-link :to="`/games/${game.id}`"
          class="card card-body flex items-start justify-between gap-3
                 hover:border-primary-600/30 hover:shadow-neon-blue transition-all duration-300"
        >
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-2 flex-wrap">
              <span class="badge" :class="statusClass(game.status)">{{ GAME_STATUS_LABELS[game.status]?.text }}</span>
              <span class="badge badge-gray">{{ game.game_type === 'entertainment' ? '娱乐制' : '正式制' }}</span>
              <span v-if="game.venue" class="text-xs text-dark-500">📍 {{ game.venue }}</span>
            </div>
            <h3 class="font-semibold text-white text-sm mb-2">{{ game.title }}</h3>
            <!-- 双队比分 -->
            <div v-if="game.home_team && game.away_team" class="flex items-center gap-3">
              <div class="flex items-center gap-2">
                <div class="w-2 h-8 rounded-full" :style="{ backgroundColor: game.home_team.color }"></div>
                <span class="text-sm font-semibold" :style="{ color: game.home_team.color }">{{ game.home_team.short_name || game.home_team.name }}</span>
              </div>
              <div class="flex items-center gap-1.5 bg-dark-800 px-3 py-1 rounded-lg">
                <span class="font-bold text-white text-base tabular-nums">{{ game.home_score }}</span>
                <span class="text-dark-600 text-sm">:</span>
                <span class="font-bold text-white text-base tabular-nums">{{ game.away_score }}</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-sm font-semibold" :style="{ color: game.away_team.color }">{{ game.away_team.short_name || game.away_team.name }}</span>
                <div class="w-2 h-8 rounded-full" :style="{ backgroundColor: game.away_team.color }"></div>
              </div>
            </div>
            <p v-if="game.scheduled_at" class="text-xs text-dark-500 mt-1.5">{{ fmtDateTime(game.scheduled_at) }}</p>
          </div>
          <div class="flex flex-col gap-1.5 flex-shrink-0 items-end">
            <router-link v-if="canRecord(game)" :to="`/games/${game.id}/record`"
              class="btn-primary btn-sm" @click.stop
            >录入</router-link>
            <span class="text-dark-600 group-hover:text-primary-400 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
              </svg>
            </span>
          </div>
        </router-link>
        <!-- 删除按钮独立于 router-link，避免事件冲突 -->
        <button v-if="auth.isSuperAdmin"
          @click.stop="confirmDelete(game)"
          class="absolute top-2 right-2 z-10 flex items-center gap-1 px-2 py-1 rounded-lg text-xs text-dark-500
                 hover:text-danger hover:bg-danger/10 border border-transparent hover:border-danger/20 transition-all duration-200"
        >
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
          </svg>
          删除
        </button>
      </div>
    </div>
  </div>

  <!-- 删除确认弹窗 -->
  <Teleport v-if="deleteTarget" to="body">
    <Transition name="fade">
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="deleteTarget = null">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>
        <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass">
          <div class="text-center">
            <div class="w-14 h-14 rounded-full bg-danger/10 border border-danger/20 flex items-center justify-center mx-auto mb-4">
              <svg class="w-7 h-7 text-danger" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-white mb-2">删除赛事</h3>
            <p class="text-sm text-dark-400 mb-1">确定要删除 <span class="text-white font-medium">"{{ deleteTarget?.title }}"</span> 吗？</p>
            <p class="text-xs text-dark-500 mb-5">所有比赛数据、统计、MVP记录将被永久删除</p>
            <div class="flex gap-3">
              <button @click="deleteTarget = null" class="btn-secondary flex-1">取消</button>
              <button @click="doDelete" :disabled="!!deletingId" class="flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold
                bg-danger/20 border border-danger/30 text-danger hover:bg-danger/30
                transition-all duration-200 disabled:opacity-50">
                {{ deletingId ? '删除中...' : '确认删除' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { GAME_STATUS_LABELS, fmtDateTime } from '@/utils/helpers'

const auth = useAuthStore()
const games = ref([])
const loading = ref(true)
const total = ref(0)
const activeFilter = ref('all')
const loadError = ref('')

const filters = [
  { value: 'all', label: '全部' },
  { value: 'active', label: '进行中' },
  { value: 'pending', label: '未开始' },
  { value: 'finished', label: '已结束' },
  { value: 'entertainment', label: '娱乐制' },
  { value: 'official', label: '正式制' }
]

const filteredGames = computed(() => {
  if (activeFilter.value === 'all') return games.value
  if (['entertainment', 'official'].includes(activeFilter.value)) {
    return games.value.filter(g => g.game_type === activeFilter.value)
  }
  return games.value.filter(g => g.status === activeFilter.value)
})

function statusClass(status) {
  const map = {
    active: 'badge-green', pending: 'badge-gray',
    halftime: 'badge-orange', finished: 'badge-blue', cancelled: 'badge-red'
  }
  return map[status] || 'badge-gray'
}

function canRecord(game) {
  if (game.status === 'finished' || game.status === 'cancelled') return false
  return auth.isAdmin || auth.role === 'recorder'
}

const deleteTarget = ref(null)
const deletingId = ref(null)

function confirmDelete(game) {
  deleteTarget.value = game
}

async function doDelete() {
  if (!deleteTarget.value) return
  deletingId.value = deleteTarget.value.id
  try {
    const { error } = await supabase.rpc('delete_game', {
      p_game_id: deleteTarget.value.id,
      p_user_id: auth.user?.id || null
    })
    if (error) throw error
    games.value = games.value.filter(g => g.id !== deleteTarget.value.id)
    total.value--
    deleteTarget.value = null
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  } finally {
    deletingId.value = null
  }
}

async function loadGames() {
  loading.value = true
  loadError.value = ''
  try {
    const { data, count, error } = await supabase
      .from('games')
      .select(`
        id, title, game_type, status, home_score, away_score, scheduled_at, venue,
        home_team:home_team_id(id, name, short_name, color),
        away_team:away_team_id(id, name, short_name, color)
      `, { count: 'exact' })
      .order('created_at', { ascending: false })
    if (error) {
      loadError.value = '加载失败：' + error.message
      console.error('[GamesView] 加载失败:', error)
      return
    }
    if (data) { games.value = data; total.value = count || 0 }
  } catch (e) {
    loadError.value = '网络异常，请检查连接后重试'
    console.error('[GamesView] 加载异常:', e)
  } finally {
    loading.value = false
  }
}

onMounted(loadGames)
</script>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: all 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
