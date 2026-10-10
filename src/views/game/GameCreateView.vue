<template>
  <div class="page-container max-w-2xl mx-auto">
    <div class="flex items-center gap-3 mb-6">
      <router-link to="/games" class="text-dark-500 hover:text-white transition-colors p-1">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </router-link>
      <h1 class="text-xl font-bold text-white">创建赛事</h1>
    </div>

    <!-- 赛事类型选择 -->
    <div class="grid grid-cols-2 gap-3 mb-5">
      <div class="px-4 py-3 rounded-xl border border-primary-500 bg-primary-600/10">
        <div class="flex items-center gap-2">
          <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <span class="font-semibold text-white text-sm">单场赛事</span>
          <span class="ml-auto text-xs text-primary-400 font-semibold">当前</span>
        </div>
        <p class="text-xs text-dark-500 mt-1">两支队伍一场对决</p>
      </div>
      <button type="button" @click="router.push('/tournaments/create')"
        class="px-4 py-3 rounded-xl border border-dark-700 bg-dark-800 text-left hover:border-accent-500/50 hover:bg-dark-750 transition-all group">
        <div class="flex items-center gap-2">
          <svg class="w-4 h-4 text-accent-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 21h8m-4-4v4M7 4h10v4a5 5 0 01-10 0V4z"/>
          </svg>
          <span class="font-semibold text-white text-sm group-hover:text-accent-400 transition-colors">创建锦标赛</span>
          <svg class="w-3.5 h-3.5 text-dark-500 ml-auto group-hover:text-accent-400 group-hover:translate-x-0.5 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </div>
        <p class="text-xs text-dark-500 mt-1">多队分组/循环赛 + 淘汰赛，决出冠亚季军</p>
      </button>
    </div>

    <!-- 步骤进度条 -->
    <div class="flex items-center gap-2 mb-6">
      <div v-for="(step, idx) in steps" :key="idx"
        class="flex-1 flex items-center gap-2"
      >
        <div class="flex items-center gap-2 flex-1"
          :class="idx <= currentStep ? 'opacity-100' : 'opacity-40'"
        >
          <div class="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 transition-all duration-300"
            :class="idx < currentStep ? 'bg-success text-white' : idx === currentStep ? 'bg-primary-600 text-white shadow-neon-blue' : 'bg-dark-700 text-dark-400'"
          >
            <span v-if="idx < currentStep">✓</span>
            <span v-else>{{ idx + 1 }}</span>
          </div>
          <span class="text-xs font-medium hidden sm:inline"
            :class="idx <= currentStep ? 'text-white' : 'text-dark-500'"
          >{{ step }}</span>
        </div>
        <div v-if="idx < steps.length - 1"
          class="h-px flex-1 transition-colors duration-300"
          :class="idx < currentStep ? 'bg-success' : 'bg-dark-700'"
        ></div>
      </div>
    </div>

    <form @submit.prevent="handleCreate" class="space-y-5">
      <!-- 基本信息 -->
      <div class="card card-body space-y-4 animate-fade-in">
        <h2 class="font-semibold text-white flex items-center gap-2">
          <span class="w-6 h-6 bg-primary-600 text-white rounded-full flex items-center justify-center text-xs font-bold">1</span>
          基本信息
        </h2>

        <div class="form-group">
          <label class="label">赛事名称 <span class="text-danger">*</span></label>
          <input v-model="form.title" type="text" class="input" placeholder="例如：2024年Q4联赛第1轮" required />
        </div>

        <div class="form-group">
          <label class="label">比赛日期</label>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs text-dark-400 mb-1.5">日期</label>
              <input v-model="form.date" type="date" required
                class="w-full bg-dark-800 border border-dark-700 rounded-xl px-3 py-2.5 text-sm text-white
                       focus:border-primary-500 focus:ring-1 focus:ring-primary-500/20 outline-none transition-all" />
            </div>
            <div>
              <label class="block text-xs text-dark-400 mb-1.5">时间</label>
              <input v-model="form.time" type="time" required
                class="w-full bg-dark-800 border border-dark-700 rounded-xl px-3 py-2.5 text-sm text-white
                       focus:border-primary-500 focus:ring-1 focus:ring-primary-500/20 outline-none transition-all" />
            </div>
          </div>
        </div>

        <div class="form-group">
          <label class="label">比赛场地</label>
          <input v-model="form.venue" type="text" class="input" placeholder="例如：德泰科技园篮球场" />
        </div>
      </div>

      <!-- 对阵球队 -->
      <div class="card card-body space-y-4 animate-fade-in" style="animation-delay: 80ms">
        <h2 class="font-semibold text-white flex items-center gap-2">
          <span class="w-6 h-6 bg-primary-600 text-white rounded-full flex items-center justify-center text-xs font-bold">2</span>
          对阵球队
        </h2>
        <div class="grid sm:grid-cols-2 gap-4">
          <div class="form-group">
            <label class="label">主队</label>
            <select v-model="form.homeTeamId" class="input" required>
              <option value="">请选择</option>
              <option v-for="t in teams" :key="t.id" :value="t.id">{{ t.name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label class="label">客队</label>
            <select v-model="form.awayTeamId" class="input" required>
              <option value="">请选择</option>
              <option v-for="t in teams" :key="t.id" :value="t.id" :disabled="t.id === form.homeTeamId">{{ t.name }}</option>
            </select>
          </div>
        </div>
      </div>

      <!-- 赛制选择 -->
      <div class="card card-body animate-fade-in" style="animation-delay: 160ms">
        <h2 class="font-semibold text-white flex items-center gap-2 mb-4">
          <span class="w-6 h-6 bg-primary-600 text-white rounded-full flex items-center justify-center text-xs font-bold">3</span>
          赛制 <span class="text-danger">*</span>
        </h2>
        <div class="flex gap-2 bg-dark-800 rounded-xl p-1">
          <button v-for="gt in gameTypes" :key="gt.value"
            @click="form.gameType = gt.value"
            class="flex-1 py-2 rounded-lg text-xs font-medium transition-all duration-200"
            :class="form.gameType === gt.value
              ? 'bg-primary-600/20 text-primary-300 border border-primary-500/30 shadow-sm'
              : 'text-dark-500 hover:text-dark-300 border border-transparent'">
            {{ gt.icon }} {{ gt.label }}
          </button>
        </div>

        <!-- 娱乐制参数 -->
        <div v-if="form.gameType === 'entertainment'" class="mt-4 form-group">
          <label class="label">目标分数</label>
          <div class="flex items-center gap-2">
            <input v-model.number="form.targetScore" type="number" class="input w-28" min="20" max="300" />
            <span class="text-sm text-dark-500">分（先到获胜）</span>
          </div>
        </div>

        <!-- 正式制参数 -->
        <div v-if="form.gameType === 'official'" class="mt-4 grid sm:grid-cols-2 gap-4">
          <div class="form-group">
            <label class="label">节数</label>
            <select v-model.number="form.quarters" class="input">
              <option :value="2">2节</option>
              <option :value="4">4节（标准）</option>
            </select>
          </div>
          <div class="form-group">
            <label class="label">每节时长</label>
            <select v-model.number="form.quarterSeconds" class="input">
              <option :value="480">8分钟</option>
              <option :value="600">10分钟（标准）</option>
              <option :value="720">12分钟</option>
            </select>
          </div>
        </div>
      </div>

      <!-- 错误提示 -->
      <div v-if="error" class="flex items-center gap-2 p-3 bg-danger/10 border border-danger/20 rounded-xl text-sm text-danger-light">
        <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>
        {{ error }}
      </div>

      <button type="submit" class="btn-primary w-full btn-lg" :disabled="loading">
        <svg v-if="loading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
        </svg>
        {{ loading ? '创建中...' : '创建赛事' }}
      </button>
    </form>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'

const auth = useAuthStore()
const router = useRouter()

const teams = ref([])
const loading = ref(false)
const error = ref('')

const steps = ['基本信息', '对阵', '赛制']
const currentStep = computed(() => {
  if (form.homeTeamId && form.awayTeamId) return 2
  if (form.title) return 1
  return 0
})

const form = reactive({
  title: '',
  gameType: 'entertainment',
  targetScore: 120,
  quarters: 4,
  quarterSeconds: 600,
  homeTeamId: '',
  awayTeamId: '',
  date: '',
  time: '',
  venue: '德泰科技园篮球场'
})

const gameTypes = [
  { value: 'entertainment', icon: '🎮', label: '娱乐制', desc: '先到目标分数获胜，适合友谊赛' },
  { value: 'official', icon: '🏆', label: '正式制', desc: '按节计时，适合正式联赛' }
]

onMounted(async () => {
  const { data: teamsData } = await supabase.from('teams').select('id, name').eq('is_active', true).order('name')
  if (teamsData) teams.value = teamsData
})

async function handleCreate() {
  if (!form.title.trim()) { error.value = '请填写赛事名称'; return }
  if (!form.homeTeamId || !form.awayTeamId) { error.value = '请选择对阵球队'; return }
  if (form.homeTeamId === form.awayTeamId) { error.value = '主队和客队不能相同'; return }
  error.value = ''
  loading.value = true
  try {
    const { data: gameResult, error: gameError } = await supabase.rpc('add_game', {
      p_title: form.title.trim(),
      p_game_type: form.gameType,
      p_home_team_id: form.homeTeamId || null,
      p_away_team_id: form.awayTeamId || null,
      p_target_score: form.gameType === 'entertainment' ? form.targetScore : null,
      p_quarters: form.gameType === 'official' ? form.quarters : null,
      p_quarter_seconds: form.gameType === 'official' ? form.quarterSeconds : null,
      p_quarter_clock: form.gameType === 'official' ? form.quarterSeconds : null,
      p_venue: form.venue || null,
      p_scheduled_at: (form.date && form.time) ? (form.date + 'T' + form.time + ':00') : null,
      p_notes: null
    })
    if (gameError) throw gameError

    const gameId = gameResult.game_id

    router.push(`/games/${gameId}`)
  } catch (e) {
    error.value = e.message || '创建失败'
  } finally {
    loading.value = false
  }
}
</script>
