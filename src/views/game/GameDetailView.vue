<template>
  <div class="page-container">
    <!-- 返回 -->
    <div class="flex items-center gap-3 mb-5">
      <router-link to="/games" class="text-dark-500 hover:text-white transition-colors p-1">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </router-link>
      <div class="flex-1 min-w-0">
        <h1 class="text-lg font-bold text-white truncate">{{ game?.title || '赛事详情' }}</h1>
        <p v-if="game?.scheduled_at" class="text-xs text-dark-500 mt-0.5">{{ fmtDateTime(game.scheduled_at) }}{{ game?.venue ? ' · ' + game.venue : '' }}</p>
      </div>
      <router-link v-if="canRecord" :to="`/games/${gameId}/record`"
        class="btn-accent btn-sm flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
        </svg>
        进入录入
      </router-link>
      <button v-if="auth.isSuperAdmin"
        @click="showDeleteConfirm = true"
        class="btn-ghost btn-sm text-dark-500 hover:text-danger hover:bg-danger/10 hover:border-danger/20 flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
        </svg>
        删除赛事
      </button>
    </div>

    <div v-if="loading" class="space-y-3">
      <div class="skeleton h-44 rounded-2xl"></div>
      <div class="skeleton h-60 rounded-2xl"></div>
    </div>

    <div v-else-if="loadError" class="text-center py-20">
      <div class="text-4xl mb-4">⚠️</div>
      <p class="text-dark-400 mb-2">{{ loadError }}</p>
      <p class="text-dark-600 text-xs mb-6">赛事ID: {{ gameId }}</p>
      <router-link to="/games" class="btn-primary btn-sm">返回赛事列表</router-link>
    </div>

    <template v-else-if="game">
      <!-- 比分板 - 霓虹暗色 -->
      <div class="relative rounded-2xl p-6 mb-5 overflow-hidden
                  bg-gradient-to-br from-dark-800 via-dark-850 to-dark-900
                  border border-dark-700/50">
        <!-- 装饰光效 -->
        <div class="absolute -top-20 -left-20 w-40 h-40 bg-primary-600/10 rounded-full blur-3xl"></div>
        <div class="absolute -bottom-20 -right-20 w-40 h-40 bg-accent-500/10 rounded-full blur-3xl"></div>

        <div class="relative z-10">
          <div class="flex items-center justify-between mb-4">
            <span class="badge"
              :class="game.status === 'active' ? 'badge-green' : 'badge-gray'">
              {{ GAME_STATUS_LABELS[game.status]?.text }}
            </span>
            <span class="text-xs text-dark-500">{{ game.game_type === 'entertainment' ? `目标 ${game.target_score} 分` : `第 ${game.current_quarter} 节` }}</span>
          </div>

          <div class="flex items-center justify-between">
            <div class="text-center flex-1">
              <p class="text-sm font-medium mb-1 truncate" :style="{ color: game.home_team?.color || '#94a3b8' }">
                {{ game.home_team?.name || '主队' }}
              </p>
              <p class="text-6xl font-black score-text" :style="{ color: game.home_team?.color || '#fff', textShadow: `0 0 30px ${game.home_team?.color || '#fff'}33` }">
                {{ game.home_score }}
              </p>
            </div>
            <div class="px-6 text-center">
              <p class="text-3xl text-dark-600 font-light">VS</p>
            </div>
            <div class="text-center flex-1">
              <p class="text-sm font-medium mb-1 truncate" :style="{ color: game.away_team?.color || '#94a3b8' }">
                {{ game.away_team?.name || '客队' }}
              </p>
              <p class="text-6xl font-black score-text" :style="{ color: game.away_team?.color || '#fff', textShadow: `0 0 30px ${game.away_team?.color || '#fff'}33` }">
                {{ game.away_score }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- 数据统计 -->
      <div class="card mb-4">
        <div class="card-header">
          <h2 class="font-semibold text-white">球员数据</h2>
          <div class="flex gap-1">
            <button v-for="tab in ['全队', game.home_team?.name, game.away_team?.name].filter(Boolean)" :key="tab"
              @click="activeTeamTab = tab"
              class="px-3 py-1 rounded-lg text-xs font-semibold transition-all duration-200"
              :class="activeTeamTab === tab ? 'bg-primary-600/20 text-primary-400' : 'text-dark-500 hover:text-white hover:bg-dark-800'"
            >{{ tab }}</button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
              <thead>
              <tr class="border-b border-dark-700/50">
                <th class="text-left px-4 py-3 text-xs font-semibold text-dark-500 uppercase tracking-wide sticky left-0 bg-dark-850 z-10">球员</th>
                <th class="px-2 py-3 text-center text-xs font-semibold text-dark-500">号码</th>
                <th class="px-3 py-3 text-center text-xs font-semibold text-dark-500">得分</th>
                <th class="px-3 py-3 text-center text-xs font-semibold text-dark-500">篮板</th>
                <th class="px-3 py-3 text-center text-xs font-semibold text-dark-500">助攻</th>
                <th class="px-3 py-3 text-center text-xs font-semibold text-dark-500">抢断</th>
                <th class="px-3 py-3 text-center text-xs font-semibold text-dark-500">盖帽</th>
                <th class="px-3 py-3 text-center text-xs font-semibold text-dark-500">失误</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-dark-700/30">
              <tr v-for="stat in displayStats" :key="stat.player_id"
                class="hover:bg-dark-800/50 transition-colors"
              >
                <td class="px-4 py-3 sticky left-0 bg-dark-850 z-10">
                  <div class="flex items-center gap-2.5">
                    <!-- 全队模式下显示队伍颜色标记 -->
                    <div v-if="activeTeamTab === '全队'" class="w-1 h-8 rounded-full flex-shrink-0"
                      :style="{ backgroundColor: stat.team?.color || '#666' }"
                      :title="stat.team?.name || ''"></div>
                    <div class="w-7 h-7 rounded-full bg-primary-600/20 text-primary-400 flex items-center justify-center text-xs font-bold flex-shrink-0">
                      {{ getInitials(stat.player?.name) }}
                    </div>
                    <div class="min-w-0">
                      <span class="font-medium text-white whitespace-nowrap">{{ stat.player?.name }}</span>
                      <span v-if="activeTeamTab === '全队' && stat.team?.name"
                        class="block text-[10px] text-dark-500 whitespace-nowrap">{{ stat.team.name }}</span>
                    </div>
                  </div>
                </td>
                <td class="px-2 py-3 text-center font-bold" :style="{ color: stat.team?.color || '#94a3b8' }">
                  #{{ stat.player?.jersey_no || '-' }}
                </td>
                <td class="px-3 py-3 text-center font-bold text-gradient-orange">{{ stat.pts }}</td>
                <td class="px-3 py-3 text-center text-dark-300">{{ stat.reb }}</td>
                <td class="px-3 py-3 text-center text-dark-300">{{ stat.ast }}</td>
                <td class="px-3 py-3 text-center text-dark-300">{{ stat.stl }}</td>
                <td class="px-3 py-3 text-center text-dark-300">{{ stat.blk }}</td>
                <td class="px-3 py-3 text-center text-dark-500">{{ stat.tov }}</td>
              </tr>
              <tr v-if="displayStats.length === 0">
                <td colspan="8" class="text-center py-10 text-dark-500 text-sm">暂无数据</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- MVP - 霓虹奖杯 -->
      <div v-if="mvpWinner" class="relative rounded-2xl p-5 overflow-hidden
                  bg-gradient-to-r from-yellow-900/20 via-dark-850 to-dark-850
                  border border-yellow-600/20">
        <div class="absolute left-4 top-4 w-16 h-16 bg-yellow-500/10 rounded-full blur-xl"></div>
        <div class="relative z-10 flex items-center gap-4">
          <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-yellow-400 to-orange-500
                      flex items-center justify-center text-2xl shadow-neon-orange">
            🏆
          </div>
          <div>
            <p class="text-xs text-yellow-500/80 font-semibold uppercase tracking-wide mb-0.5">本场 MVP</p>
            <p class="font-bold text-white text-lg">{{ mvpWinner.player?.name }}</p>
            <p class="text-xs text-dark-400">综合评分 <span class="text-yellow-400 font-bold">{{ mvpWinner.mvp_score }}</span></p>
          </div>
        </div>
      </div>
    </template>

    <!-- 删除确认弹窗 -->
    <Transition name="fade">
      <div v-if="showDeleteConfirm" class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="showDeleteConfirm = false">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>
        <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass animate-scale-in">
          <div class="text-center">
            <div class="w-14 h-14 rounded-full bg-danger/10 border border-danger/20 flex items-center justify-center mx-auto mb-4">
              <svg class="w-7 h-7 text-danger" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-white mb-2">删除赛事</h3>
            <p class="text-sm text-dark-400 mb-1">确定要删除 <span class="text-white font-medium">"{{ game?.title }}"</span> 吗？</p>
            <p class="text-xs text-dark-500 mb-5">所有比赛数据、统计、MVP记录将被永久删除</p>
            <div class="flex gap-3">
              <button @click="showDeleteConfirm = false" class="btn-secondary flex-1">取消</button>
              <button @click="confirmDelete" :disabled="deleting" class="flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold
                bg-danger/20 border border-danger/30 text-danger hover:bg-danger/30
                transition-all duration-200 disabled:opacity-50">
                {{ deleting ? '删除中...' : '确认删除' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { GAME_STATUS_LABELS, getInitials, fmtDateTime } from '@/utils/helpers'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const gameId = route.params.id

const game = ref(null)
const stats = ref([])
const mvp = ref([])
const loading = ref(true)
const loadError = ref('')
const activeTeamTab = ref('全队')

const canRecord = computed(() => {
  if (!game.value) return false
  if (['finished', 'cancelled'].includes(game.value.status)) return false
  return auth.isAdmin || auth.role === 'recorder'
})

const displayStats = computed(() => {
  if (activeTeamTab.value === '全队') return stats.value
  const team = activeTeamTab.value === game.value?.home_team?.name ? game.value?.home_team_id : game.value?.away_team_id
  return stats.value.filter(s => s.team_id === team)
})

const mvpWinner = computed(() => mvp.value.find(m => m.is_winner))

// 删除功能
const showDeleteConfirm = ref(false)
const deleting = ref(false)

async function confirmDelete() {
  deleting.value = true
  try {
    const { error } = await supabase.rpc('delete_game', {
      p_game_id: gameId,
      p_user_id: auth.user?.id || null
    })
    if (error) throw error
    router.push('/games')
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  try {
    // 主查询：赛事详情（必须成功）
    const { data: gameData, error: gErr } = await supabase
      .from('games')
      .select('*, home_team:home_team_id(*), away_team:away_team_id(*)')
      .eq('id', gameId)
      .single()
    console.log('[GameDetail] games query:', { gameData, gErr })
    if (gErr) {
      loadError.value = '赛事查询失败：' + gErr.message + ' (code: ' + gErr.code + ')'
      loading.value = false
      return
    }
    if (!gameData) {
      loadError.value = '找不到该赛事，ID: ' + gameId
      loading.value = false
      return
    }
    game.value = gameData
    activeTeamTab.value = '全队'
    loading.value = false

    // 并行加载统计和 MVP（允许失败）
    const [statsRes, mvpRes] = await Promise.allSettled([
      supabase.from('game_stats')
        .select(`*, player:player_id(id, name, jersey_no), team:team_id(id, name, color)`)
        .eq('game_id', gameId)
        .order('pts', { ascending: false }),
      supabase.from('team_players')
        .select('team_id, player_id, jersey_no')
        .in('team_id', [gameData.home_team_id, gameData.away_team_id])
        .eq('is_active', true)
    ])

    // 构建 team_id + player_id -> jersey_no 映射
    const jerseyMap = {}
    if (mvpRes.status === 'fulfilled' && mvpRes.value.data) {
      for (const tp of mvpRes.value.data) {
        jerseyMap[`${tp.team_id}_${tp.player_id}`] = tp.jersey_no
      }
    }
    // 获取 MVP
    const mvpQuery = await supabase.from('game_mvp')
      .select('*, player:player_id(id, name)')
      .eq('game_id', gameId)

    if (statsRes.status === 'fulfilled' && statsRes.value.data) {
      stats.value = statsRes.value.data.map(s => ({
        ...s,
        player: {
          ...s.player,
          jersey_no: jerseyMap[`${s.team_id}_${s.player_id}`] || s.player?.jersey_no
        }
      }))
    }
    if (mvpQuery.data) {
      mvp.value = mvpQuery.data
    }
  } catch (e) {
    console.error('[GameDetail] 加载异常:', e)
    loadError.value = '加载异常：' + (e.message || '未知错误')
    loading.value = false
  }
})
</script>

<style scoped>
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>
