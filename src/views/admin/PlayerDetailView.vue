<template>
  <div class="page-container max-w-2xl mx-auto">
    <div v-if="loading" class="space-y-3">
      <div class="skeleton h-40 rounded-2xl"></div>
      <div class="skeleton h-60 rounded-2xl"></div>
      <div class="skeleton h-20 rounded-2xl"></div>
    </div>
    <template v-else-if="player">
      <!-- 返回按钮 -->
      <button @click="goBack"
        class="flex items-center gap-1.5 text-dark-400 hover:text-white mb-4
               text-sm transition-colors group">
        <svg class="w-4 h-4 transition-transform group-hover:-translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
        {{ backLabel }}
      </button>

      <!-- 球员头部 -->
      <div class="relative rounded-2xl p-6 mb-5 overflow-hidden
                  bg-gradient-to-br from-primary-700/30 via-dark-850 to-dark-900
                  border border-primary-600/20">
        <div class="absolute -top-10 -right-10 w-32 h-32 bg-primary-500/10 rounded-full blur-2xl"></div>
        <div class="absolute -bottom-10 -left-10 w-24 h-24 bg-accent-500/5 rounded-full blur-2xl"></div>
        <div class="relative z-10 flex items-center gap-5">
          <div class="w-20 h-20 rounded-full bg-primary-600/20 border-2 border-primary-500/40
                      text-primary-400 flex items-center justify-center text-3xl font-bold flex-shrink-0 overflow-hidden">
            <img v-if="player.avatar_url" :src="player.avatar_url" class="w-full h-full object-cover" />
            <span v-else>{{ getInitials(player.name) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <h1 class="text-2xl font-black text-white truncate text-gradient-accent">{{ player.name }}</h1>
                <div v-if="player.position" class="flex flex-wrap gap-1 mt-1">
                  <span v-for="pos in player.position.split(',')" :key="pos"
                    class="text-xs px-2 py-0.5 rounded-full bg-primary-600/20 text-primary-300 border border-primary-500/20">
                    {{ POSITION_LABELS[pos] || pos }}
                  </span>
                </div>
                <p v-else class="text-dark-500 text-sm mt-1">位置未指定</p>
                <div class="flex flex-wrap gap-3 mt-2 text-xs text-dark-400">
                  <span v-if="player.height">{{ player.height }}cm</span>
                  <span v-if="player.height && player.weight" class="text-dark-700">|</span>
                  <span v-if="player.weight">{{ player.weight }}kg</span>
                </div>
              </div>
              <!-- 管理员操作 -->
              <div v-if="auth.isAdmin" class="flex gap-2 flex-shrink-0">
                <button @click="goEdit"
                  class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all duration-200
                         bg-dark-800 border-dark-700 text-dark-400 hover:text-primary-400 hover:border-primary-500/30">
                  编辑
                </button>
                <button @click="showDeleteConfirm = true"
                  class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all duration-200
                         bg-dark-800 border-dark-700 text-dark-400 hover:text-danger hover:border-danger/30">
                  删除
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 六维能力雷达图 -->
      <div class="card p-5 mb-5">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-semibold text-white flex items-center gap-2">
            <svg class="w-4 h-4 text-accent-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
            </svg>
            能力六维图
          </h2>
          <div class="flex gap-1 bg-dark-800 p-1 rounded-lg border border-dark-700/50">
            <button v-for="gt in gameTypeOptions" :key="gt.value"
              @click="activeGameType = gt.value"
              class="px-3 py-1 rounded-md text-xs font-medium transition-all duration-200"
              :class="activeGameType === gt.value ? 'bg-dark-700 text-white shadow-sm' : 'text-dark-500 hover:text-dark-300'"
            >{{ gt.label }}</button>
          </div>
        </div>

        <!-- 雷达图（始终显示） -->
        <div class="flex justify-center">
          <svg :viewBox="`0 0 ${chartSize} ${chartSize}`" class="w-full max-w-sm" style="filter: drop-shadow(0 0 20px rgba(59,130,246,0.15))">
            <defs>
              <radialGradient id="radarGlow" cx="50%" cy="50%" r="50%">
                <stop offset="0%" stop-color="rgba(59,130,246,0.08)" />
                <stop offset="100%" stop-color="rgba(59,130,246,0)" />
              </radialGradient>
              <linearGradient id="radarFill" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="rgba(59,130,246,0.35)" />
                <stop offset="100%" stop-color="rgba(249,115,22,0.25)" />
              </linearGradient>
              <linearGradient id="radarFillEmpty" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="rgba(59,130,246,0.06)" />
                <stop offset="100%" stop-color="rgba(249,115,22,0.04)" />
              </linearGradient>
              <filter id="glow">
                <feGaussianBlur stdDeviation="3" result="blur" />
                <feMerge>
                  <feMergeNode in="blur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
            </defs>

            <!-- 背景辉光 -->
            <circle :cx="center" :cy="center" :r="radius + 10" fill="url(#radarGlow)" />

            <!-- 网格线（3层） -->
            <g v-for="level in 3" :key="level">
              <polygon
                :points="gridPoints(level / 3)"
                fill="none"
                :stroke="level === 3 ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.04)'"
                stroke-width="1"
              />
            </g>

            <!-- 轴线 -->
            <line v-for="(_, i) in radarLabels" :key="'axis-' + i"
              :x1="center" :y1="center"
              :x2="axisEndpoint(i).x" :y2="axisEndpoint(i).y"
              stroke="rgba(255,255,255,0.06)" stroke-width="1"
            />

            <!-- 数据区域 -->
            <polygon
              :points="dataPoints"
              :fill="hasStats ? 'url(#radarFill)' : 'url(#radarFillEmpty)'"
              :stroke="hasStats ? 'rgba(59,130,246,0.8)' : 'rgba(59,130,246,0.2)'"
              stroke-width="2"
              :filter="hasStats ? 'url(#glow)' : ''"
              :class="hasStats ? 'radar-area' : 'radar-area-empty'"
            />

            <!-- 数据点 -->
            <g v-for="(pt, i) in dataPointCoords" :key="'dot-' + i">
              <circle :cx="pt.x" :cy="pt.y" r="6" :fill="hasStats ? 'rgba(59,130,246,0.2)' : 'rgba(59,130,246,0.08)'" />
              <circle :cx="pt.x" :cy="pt.y" r="3.5"
                :fill="hasStats ? '#3b82f6' : 'rgba(59,130,246,0.3)'"
                :stroke="hasStats ? '#fff' : 'rgba(59,130,246,0.4)'"
                stroke-width="1.5"
                :class="hasStats ? 'radar-dot' : ''"
                :style="{ animationDelay: `${i * 0.1}s` }" />
            </g>

            <!-- 标签 -->
            <g v-for="(label, i) in radarLabels" :key="'label-' + i">
              <text
                :x="labelPosition(i).x"
                :y="labelPosition(i).y"
                text-anchor="middle"
                :dominant-baseline="labelPosition(i).baseline"
                class="text-xs font-medium"
                :fill="hasStats ? '#e5e7eb' : '#6b7280'"
              >{{ label }}</text>
              <text
                :x="labelPosition(i).x"
                :y="labelPosition(i).y + 14"
                text-anchor="middle"
                class="text-xs font-bold"
                :fill="hasStats ? '#3b82f6' : '#374151'"
              >{{ radarValues[i] }}</text>
            </g>

            <!-- 无数据时的中心提示 -->
            <text v-if="!hasStats"
              :x="center" :y="center + 4"
              text-anchor="middle"
              class="text-xs"
              fill="rgba(107,114,128,0.6)"
            >暂无数据</text>
          </svg>
        </div>

        <!-- 无数据提示（放在图下方） -->
        <p v-if="!hasStats" class="text-center text-xs text-dark-500 -mt-3">
          {{ activeGameType === 'entertainment' ? '娱乐制' : '正式制' }}暂无比赛数据，录入后自动展示
        </p>
      </div>

      <!-- 统计汇总 -->
      <div class="grid grid-cols-3 sm:grid-cols-6 gap-3 mb-5">
        <div v-for="(s, idx) in summaryStats" :key="s.label"
          class="stat-card animate-fade-in"
          :style="{ animationDelay: `${idx * 60}ms` }"
        >
          <p class="text-xl font-bold text-gradient-accent">{{ s.value }}</p>
          <p class="text-xs text-dark-500 mt-0.5">{{ s.label }}</p>
        </div>
      </div>

      <!-- 场次记录 -->
      <div class="card">
        <div class="card-header">
          <h2 class="font-semibold text-white">场次记录</h2>
          <span class="text-xs text-dark-500">{{ filteredStats.length }} 场</span>
        </div>
        <div class="divide-y divide-dark-700/30">
          <div v-for="stat in filteredStats" :key="stat.game_id"
            class="flex items-center gap-3 px-4 py-3 hover:bg-dark-800/50 transition-colors"
          >
            <router-link :to="`/games/${stat.game_id}`" class="flex-1 min-w-0">
              <p class="text-sm font-medium text-white truncate">{{ stat.game?.title }}</p>
              <p class="text-xs text-dark-500">{{ fmtDate(stat.game?.started_at) }}</p>
            </router-link>
            <div class="grid grid-cols-4 gap-3 text-center text-xs flex-shrink-0">
              <div><p class="font-bold text-accent-400">{{ stat.pts }}</p><p class="text-dark-500">分</p></div>
              <div><p class="font-bold text-dark-200">{{ stat.reb }}</p><p class="text-dark-500">板</p></div>
              <div><p class="font-bold text-dark-200">{{ stat.ast }}</p><p class="text-dark-500">助</p></div>
              <div><p class="font-bold text-dark-200">{{ stat.stl }}</p><p class="text-dark-500">断</p></div>
            </div>
          </div>
          <div v-if="filteredStats.length === 0" class="text-center py-10 text-dark-500 text-sm">
            暂无比赛记录
          </div>
        </div>
      </div>

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
              <h3 class="text-lg font-semibold text-white mb-2">删除球员档案</h3>
              <p class="text-sm text-dark-400 mb-1">确定要删除 <span class="text-white font-medium">"{{ player?.name }}"</span> 吗？</p>
              <p class="text-xs text-dark-500 mb-5">该球员将被标记为已删除，相关比赛数据保留</p>
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
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { getInitials, POSITION_LABELS, fmtDate, calcMvpScore } from '@/utils/helpers'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const playerId = route.params.id

const player = ref(null)
const allStats = ref([])
const loading = ref(true)
const activeGameType = ref('entertainment')

// 返回逻辑：从球队页过来返回球队，否则返回球员名册
const backLabel = computed(() => route.query.from === 'teams' ? '返回球队' : '返回球员名册')

function goBack() {
  if (route.query.from === 'teams') {
    router.push('/teams')
  } else {
    router.push('/players')
  }
}

// 删除状态
const showDeleteConfirm = ref(false)
const deleting = ref(false)

// 雷达图配置
const chartSize = 320
const center = chartSize / 2
const radius = 110
const radarLabels = ['得分', '篮板', '助攻', '抢断', '盖帽', '三分']
const radarKeys = ['pts', 'reb', 'ast', 'stl', 'blk', 'fg3m']

const gameTypeOptions = [
  { value: 'entertainment', label: '娱乐制' },
  { value: 'official', label: '正式制' }
]

const filteredStats = computed(() =>
  allStats.value.filter(s => s.game_type === activeGameType.value)
)

const hasStats = computed(() => filteredStats.value.length > 0)

// 归一化到 0-100 的雷达值
const radarValues = computed(() => {
  const stats = filteredStats.value
  if (!stats.length) return [0, 0, 0, 0, 0, 0]
  const games = stats.length

  // 场均数据
  const avg = {}
  radarKeys.forEach(k => {
    avg[k] = stats.reduce((sum, s) => sum + (s[k] || 0), 0) / games
  })

  // 基于篮球经验的最大值参考
  const maxRefs = { pts: 30, reb: 15, ast: 10, stl: 5, blk: 5, fg3m: 5 }

  return radarKeys.map(k => {
    const v = Math.round((avg[k] / maxRefs[k]) * 100)
    return Math.min(v, 100)
  })
})

// 角度计算（6边，从顶部开始，顺时针）
function angleForIndex(i) {
  return (Math.PI * 2 * i / 6) - Math.PI / 2
}

function axisEndpoint(i) {
  const a = angleForIndex(i)
  return { x: center + radius * Math.cos(a), y: center + radius * Math.sin(a) }
}

function gridPoints(fraction) {
  const r = radius * fraction
  return Array.from({ length: 6 }, (_, i) => {
    const a = angleForIndex(i)
    return `${center + r * Math.cos(a)},${center + r * Math.sin(a)}`
  }).join(' ')
}

const dataPoints = computed(() => {
  return radarValues.value.map((v, i) => {
    const r = (v / 100) * radius
    const a = angleForIndex(i)
    return `${center + r * Math.cos(a)},${center + r * Math.sin(a)}`
  }).join(' ')
})

const dataPointCoords = computed(() => {
  return radarValues.value.map((v, i) => {
    const r = (v / 100) * radius
    const a = angleForIndex(i)
    return { x: center + r * Math.cos(a), y: center + r * Math.sin(a) }
  })
})

function labelPosition(i) {
  const r = radius + 28
  const a = angleForIndex(i)
  const x = center + r * Math.cos(a)
  const y = center + r * Math.sin(a)
  let baseline = 'middle'
  if (i === 0) baseline = 'auto'
  else if (i === 3) baseline = 'hanging'
  return { x, y, baseline }
}

const summaryStats = computed(() => {
  const stats = filteredStats.value
  if (!stats.length) return [
    { label: '场次', value: 0 }, { label: '总得分', value: 0 },
    { label: '总篮板', value: 0 }, { label: '总助攻', value: 0 },
    { label: '总抢断', value: 0 }, { label: 'MVP分', value: '0.0' }
  ]
  const sum = (key) => stats.reduce((acc, s) => acc + (s[key] || 0), 0)
  const totals = { pts: sum('pts'), reb: sum('reb'), ast: sum('ast'), stl: sum('stl') }
  return [
    { label: '场次', value: stats.length },
    { label: '总得分', value: totals.pts },
    { label: '总篮板', value: totals.reb },
    { label: '总助攻', value: totals.ast },
    { label: '总抢断', value: totals.stl },
    { label: 'MVP分', value: calcMvpScore(totals) }
  ]
})

onMounted(async () => {
  const [{ data: pData }, { data: sData }] = await Promise.all([
    supabase.from('players').select('*').eq('id', playerId).single(),
    supabase.from('game_stats')
      .select(`*, game:game_id(id, title, started_at, game_type)`)
      .eq('player_id', playerId)
      .order('created_at', { ascending: false })
  ])
  if (pData) player.value = pData
  if (sData) allStats.value = sData
  loading.value = false
})

async function confirmDelete() {
  deleting.value = true
  try {
    const { error } = await supabase.rpc('delete_player', {
      p_player_id: playerId
    })
    if (error) throw error
    router.push('/players')
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  } finally {
    deleting.value = false
  }
}

function goEdit() {
  router.push({ name: 'Players', query: { editId: playerId } })
}
</script>

<style scoped>
/* 雷达图动画 */
.radar-area {
  animation: radarFadeIn 0.8s ease-out;
}
.radar-area-empty {
  animation: radarPulse 3s ease-in-out infinite;
}
@keyframes radarFadeIn {
  from { opacity: 0; transform: scale(0.7); transform-origin: center; }
  to { opacity: 1; transform: scale(1); }
}
@keyframes radarPulse {
  0%, 100% { opacity: 0.4; }
  50% { opacity: 0.8; }
}
.radar-dot {
  animation: dotPulse 2s ease-in-out infinite;
}
@keyframes dotPulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>
