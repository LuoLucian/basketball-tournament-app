<template>
  <div class="page-container">
    <!-- 头部 -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-5">
      <div>
        <h1 class="page-title">锦标赛</h1>
        <p class="text-sm text-dark-500 mt-1">小组赛 + 半决赛 + 决赛的完整赛事</p>
      </div>
      <div class="flex items-center gap-2 flex-wrap">
        <router-link to="/regulation"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold
                 bg-gradient-to-r from-amber-600/25 to-orange-500/15 text-amber-300
                 border border-amber-500/40 hover:from-amber-600/40 hover:to-orange-500/25
                 hover:border-amber-400/60 transition-all duration-200 whitespace-nowrap">
          📜 赛事规程
        </router-link>
        <router-link v-if="auth.isAdmin" to="/tournaments/create" class="btn-primary whitespace-nowrap">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          创建锦标赛
        </router-link>
      </div>
    </div>

    <!-- 加载中 -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 3" :key="i" class="skeleton h-24 rounded-2xl"></div>
    </div>

    <!-- 错误 -->
    <div v-else-if="loadError" class="text-center py-20">
      <div class="text-4xl mb-4">⚠️</div>
      <p class="text-dark-400 mb-2">{{ loadError }}</p>
      <button @click="load" class="mt-4 btn-primary btn-sm">重新加载</button>
    </div>

    <!-- 空状态 -->
    <div v-else-if="!tournaments.length" class="text-center py-20">
      <div class="text-5xl mb-4">🏆</div>
      <p class="text-dark-400 mb-2">还没有锦标赛</p>
      <p class="text-dark-600 text-sm mb-6">创建一场完整赛事：选球队 → 抽签分组 → 小组赛 → 半决赛 → 决赛</p>
      <router-link v-if="auth.isAdmin" to="/tournaments/create" class="btn-primary">创建第一场锦标赛</router-link>
      <router-link v-else to="/games" class="btn-secondary">返回赛事大厅</router-link>
    </div>

    <!-- 列表 -->
    <div v-else class="grid gap-4">
      <router-link v-for="t in tournaments" :key="t.id" :to="`/tournaments/${t.id}`"
        class="card card-body hover:border-primary-600/40 transition-all group">
        <div class="flex items-center justify-between gap-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <h2 class="font-bold text-white text-lg group-hover:text-primary-400 transition-colors truncate">{{ t.name }}</h2>
              <span class="badge" :class="statusClass(t.status)">{{ statusLabel(t) }}</span>
            </div>
            <p class="text-sm text-dark-500 mt-1.5 flex items-center gap-3 flex-wrap">
              <span>📅 {{ t.start_date || '日期待定' }}</span>
              <span v-if="t.venue">📍 {{ t.venue }}</span>
              <span>👥 {{ t.tournament_teams?.[0]?.count ?? 0 }} 支球队</span>
              <span>🏀 {{ formatAdvance(t) }}</span>
            </p>
          </div>
          <svg class="w-5 h-5 text-dark-600 group-hover:text-primary-400 flex-shrink-0 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </div>
      </router-link>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/utils/supabase'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const tournaments = ref([])
const loading = ref(true)
const loadError = ref('')

const STATUS = {
  draft: { label: '待抽签', class: 'bg-dark-700 text-dark-300' },
  group_stage: { label: '小组赛', class: 'bg-primary-600/20 text-primary-400 border border-primary-600/30' },
  playoffs: { label: '淘汰赛', class: 'bg-accent-600/20 text-accent-400 border border-accent-600/30' },
  finished: { label: '已结束', class: 'bg-success/10 text-success border border-success/20' }
}
const statusLabel = t => {
  if (t.status === 'group_stage' && t.group_count === 1) return '循环赛'
  return STATUS[t.status]?.label || t.status
}
const statusClass = s => STATUS[s]?.class || ''
function formatAdvance(t) {
  if (t.group_count === 1) {
    return t.advance_per_group === 4
      ? '循环赛 · 前4名进淘汰赛'
      : '循环赛 · 前2名争冠'
  }
  if (t.group_count === 4) return '4小组 · 各组前2进八强'
  return t.advance_per_group === 1
    ? '2小组 · 头名争冠'
    : '2小组 · 各组前2进四强'
}

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const { data, error } = await supabase
      .from('tournaments')
      .select('*, tournament_teams(count)')
      .order('created_at', { ascending: false })
    if (error) throw error
    tournaments.value = data || []
  } catch (e) {
    loadError.value = e.message || '加载失败'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>
