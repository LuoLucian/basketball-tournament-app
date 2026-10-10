<template>
  <div class="page-container max-w-2xl mx-auto">
    <div class="flex items-center gap-3 mb-6">
      <router-link to="/tournaments" class="text-dark-500 hover:text-white transition-colors p-1">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </router-link>
      <h1 class="text-xl font-bold text-white">创建锦标赛</h1>
    </div>

    <form @submit.prevent="handleCreate" class="space-y-5">
      <!-- 基本信息 -->
      <div class="card card-body space-y-4 animate-fade-in">
        <h2 class="section-title mb-1">基本信息</h2>
        <div class="form-group">
          <label class="label">锦标赛名称 <span class="text-danger">*</span></label>
          <input v-model="form.name" type="text" class="input" placeholder="例如：2026德泰杯篮球锦标赛" required />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div class="form-group">
            <label class="label">开始日期</label>
            <input v-model="form.startDate" type="date" class="input" />
          </div>
          <div class="form-group">
            <label class="label">场地</label>
            <input v-model="form.venue" type="text" class="input" placeholder="例如：德泰科技园篮球场" />
          </div>
        </div>
      </div>

      <!-- 赛制 -->
      <div class="card card-body space-y-4 animate-fade-in" style="animation-delay: 60ms">
        <h2 class="section-title mb-1">赛制</h2>

        <div>
          <label class="label">赛制</label>
          <div class="grid gap-2">
            <button v-for="opt in groupOptions" :key="opt.label" type="button"
              @click="setGroupOption(opt)"
              class="px-4 py-3 rounded-xl text-left border transition-all"
              :class="form.groupCount === opt.groupCount && form.advance === opt.advance
                ? 'border-primary-500 bg-primary-600/10 text-white'
                : 'border-dark-700 bg-dark-800 text-dark-400 hover:border-dark-600'">
              <span class="block font-semibold text-sm">{{ opt.label }}</span>
              <span class="block text-xs mt-0.5 text-dark-500">{{ opt.desc }}</span>
            </button>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">节数</label>
            <div class="flex gap-2">
              <button v-for="q in [2, 4]" :key="q" type="button" @click="form.quarters = q"
                class="flex-1 py-2 rounded-xl text-sm font-semibold transition-all"
                :class="form.quarters === q ? 'bg-primary-600 text-white' : 'bg-dark-800 text-dark-400 border border-dark-700'">
                {{ q }} 节
              </button>
            </div>
          </div>
          <div>
            <label class="label">每节时长</label>
            <div class="flex gap-2">
              <button v-for="m in [8, 10, 12]" :key="m" type="button" @click="form.quarterMinutes = m"
                class="flex-1 py-2 rounded-xl text-sm font-semibold transition-all"
                :class="form.quarterMinutes === m ? 'bg-primary-600 text-white' : 'bg-dark-800 text-dark-400 border border-dark-700'">
                {{ m }} 分钟
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 参赛球队 -->
      <div class="card card-body space-y-4 animate-fade-in" style="animation-delay: 120ms">
        <div class="flex items-center justify-between">
          <h2 class="section-title">参赛球队</h2>
          <span class="text-sm" :class="selectedIds.length >= 2 ? 'text-success' : 'text-danger'">
            已选 {{ selectedIds.length }} 支
          </span>
        </div>

        <div v-if="loadingTeams" class="space-y-2">
          <div v-for="i in 5" :key="i" class="skeleton h-12 rounded-xl"></div>
        </div>
        <div v-else-if="!teams.length" class="text-center py-8 text-dark-500 text-sm">
          暂无可选球队，请先在「球队管理」创建球队
        </div>
        <div v-else class="space-y-2 max-h-80 overflow-y-auto pr-1">
          <label v-for="t in teams" :key="t.id"
            class="flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-all"
            :class="selectedIds.includes(t.id)
              ? 'border-primary-500 bg-primary-600/10'
              : 'border-dark-700 bg-dark-800 hover:border-dark-600'">
            <input type="checkbox" :value="t.id" v-model="selectedIds" class="accent-primary-600 w-4 h-4" />
            <span class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ background: t.color || '#1565c0' }"></span>
            <span class="font-medium text-white text-sm">{{ t.name }}</span>
            <svg v-if="selectedIds.includes(t.id)" class="w-4 h-4 text-primary-400 ml-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </label>
        </div>
        <p v-if="selectedIds.length && selectedIds.length < minTeams" class="text-xs text-warning">
          提示：当前赛制建议至少 {{ minTeams }} 支球队
        </p>
      </div>

      <div v-if="msg" class="text-sm px-3 py-2 rounded-xl"
        :class="msgType === 'success' ? 'bg-success/10 text-success border border-success/20' : 'bg-danger/10 text-danger-light border border-danger/20'">
        {{ msg }}
      </div>

      <button type="submit" class="btn-primary w-full" :disabled="creating">
        {{ creating ? '创建中...' : '创建锦标赛' }}
      </button>
    </form>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/utils/supabase'

const router = useRouter()
const teams = ref([])
const selectedIds = ref([])
const loadingTeams = ref(true)
const creating = ref(false)
const msg = ref('')
const msgType = ref('error')

const minTeams = computed(() => {
  if (form.groupCount === 1) return form.advance === 4 ? 4 : 3
  return form.groupCount * 2  // 每组至少 2 队才有第一阶段比赛
})

const form = reactive({
  name: '',
  startDate: '',
  venue: '德泰科技园篮球场',
  groupCount: 2,
  advance: 2,
  quarters: 4,
  quarterMinutes: 12
})

const groupOptions = [
  { groupCount: 2, advance: 2, label: '小组赛 · 2组各前2出线', desc: '半决赛（交叉）→ 季军赛 → 决赛，建议 ≥5 队' },
  { groupCount: 1, advance: 4, label: '循环赛 · 全员单循环取前4', desc: '半决赛（1v4、2v3）→ 季军赛 → 决赛，适合 4-7 队' },
  { groupCount: 1, advance: 2, label: '循环赛 · 全员单循环取前2', desc: '积分前 2 名直接打决赛，适合 3-6 队' },
  { groupCount: 2, advance: 1, label: '小组赛 · 2组头名争冠', desc: '各组第 1 直接进决赛，建议 ≥4 队' },
  { groupCount: 4, advance: 2, label: '小组赛 · 4组各前2出线', desc: '四分之一决赛 → 半决赛 → 季军赛 → 决赛，需 ≥8 队' }
]

function setGroupOption(opt) {
  form.groupCount = opt.groupCount
  form.advance = opt.advance
}

async function loadTeams() {
  try {
    const { data, error } = await supabase
      .from('teams')
      .select('id, name, color')
      .eq('is_active', true)
      .order('name')
    if (error) throw error
    teams.value = data || []
  } catch (e) {
    msg.value = '球队列表加载失败：' + e.message
  } finally {
    loadingTeams.value = false
  }
}

async function handleCreate() {
  msg.value = ''
  if (!form.name.trim()) { msg.value = '请输入锦标赛名称'; return }
  if (selectedIds.value.length < 2) { msg.value = '请至少选择 2 支球队'; return }
  if (selectedIds.value.length < form.groupCount) { msg.value = `球队数量不能少于小组数（${form.groupCount} 组）`; return }

  creating.value = true
  try {
    const { data, error } = await supabase.rpc('create_tournament', {
      p_name: form.name.trim(),
      p_venue: form.venue.trim() || null,
      p_start_date: form.startDate || null,
      p_group_count: form.groupCount,
      p_advance_per_group: form.advance,
      p_quarters: form.quarters,
      p_quarter_seconds: form.quarterMinutes * 60,
      p_team_ids: selectedIds.value
    })
    if (error) throw error
    router.push(`/tournaments/${data.tournament_id}`)
  } catch (e) {
    msg.value = '❌ ' + (e.message || '创建失败')
    msgType.value = 'error'
    creating.value = false
  }
}

onMounted(loadTeams)
</script>
