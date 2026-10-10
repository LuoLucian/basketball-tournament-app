<template>
  <div class="page-container max-w-3xl mx-auto">
    <div class="flex items-center justify-between mb-5">
      <h1 class="page-title">球队</h1>
      <button v-if="auth.isAdmin" @click="showCreateModal = true" class="btn-primary btn-sm">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        创建球队
      </button>
    </div>

    <!-- 加载骨架 -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 4" :key="i" class="skeleton h-16 rounded-2xl"></div>
    </div>

    <!-- 空状态 -->
    <div v-else-if="teams.length === 0" class="empty-state">
      <svg class="w-16 h-16 text-dark-600 mb-3" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.5">
        <path d="M16 20 L32 12 L48 20 L48 44 L32 52 L16 44 Z" opacity="0.3"/>
        <path d="M32 12 L32 52" opacity="0.2"/>
      </svg>
      <p class="text-dark-500 text-sm">{{ auth.isAdmin ? '暂无球队，点击上方按钮创建' : '暂无球队' }}</p>
    </div>

    <!-- 球队列表 -->
    <div v-else class="space-y-3">
      <router-link v-for="(team, idx) in teams" :key="team.id"
        :to="`/teams/${team.id}`"
        class="card card-body flex items-center gap-3 group cursor-pointer
               hover:border-primary-600/30 hover:shadow-neon-blue
               transition-all duration-300 animate-fade-in"
        :style="{ animationDelay: `${idx * 60}ms` }"
      >
        <!-- 球队色块 -->
        <div class="w-11 h-11 rounded-xl flex-shrink-0 flex items-center justify-center text-lg font-bold border-2"
          :style="{
            backgroundColor: (team.color || '#3b82f6') + '20',
            borderColor: (team.color || '#3b82f6') + '60',
            color: team.color || '#3b82f6'
          }">
          {{ team.name[0] }}
        </div>
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-white group-hover:text-primary-400 transition-colors">{{ team.name }}</p>
          <p class="text-xs text-dark-500">{{ team.player_count || 0 }} 名成员</p>
        </div>
        <!-- 管理员信息 -->
        <div v-if="team.owner" class="flex items-center gap-1.5 text-[11px] text-dark-500 flex-shrink-0">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
          </svg>
          <span>{{ team.owner_id === auth.user?.id ? (auth.profile?.display_name || auth.user?.username) : (team.owner?.display_name || team.owner?.username || '未知') }}</span>
        </div>
        <!-- 箭头 -->
        <svg class="w-4 h-4 text-dark-600 group-hover:text-primary-500 transition-all duration-200 group-hover:translate-x-1"
          fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </router-link>
    </div>

    <!-- 创建球队弹窗 -->
    <Teleport v-if="showCreateModal" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="showCreateModal = false">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showCreateModal = false"></div>
          <div class="relative bg-dark-850 rounded-2xl w-full max-w-md p-6 shadow-glass border border-dark-700/50">
            <h3 class="font-semibold text-white mb-5">创建球队</h3>
            <form @submit.prevent="createTeam" class="space-y-4">
              <div class="form-group">
                <label class="label">球队名称 *</label>
                <input v-model="newTeam.name" type="text" class="input" required />
              </div>
              <div class="form-group">
                <label class="label">简称</label>
                <input v-model="newTeam.shortName" type="text" class="input" maxlength="10" placeholder="最多10字" />
              </div>
              <div class="form-group">
                <label class="label">主题色</label>
                <div class="flex gap-2 flex-wrap">
                  <button v-for="c in TEAM_COLORS" :key="c" type="button"
                    @click="newTeam.color = c"
                    class="w-8 h-8 rounded-full border-2 transition-all duration-200 hover:scale-110"
                    :style="{ backgroundColor: c }"
                    :class="newTeam.color === c ? 'border-white scale-110 shadow-lg' : 'border-transparent'"
                  ></button>
                </div>
                <p v-if="isNewColorDuplicate" class="text-xs text-warning mt-1.5">⚠️ 该颜色已被其他球队使用，请更换</p>
              </div>
              <div class="flex gap-2 pt-2">
                <button type="button" @click="showCreateModal = false" class="btn-secondary flex-1">取消</button>
                <button type="submit" class="btn-primary flex-1" :disabled="creating || isNewColorDuplicate">
                  {{ creating ? '创建中...' : '创建' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { TEAM_COLORS } from '@/utils/helpers'

const auth = useAuthStore()

const teams = ref([])
const loading = ref(true)

const showCreateModal = ref(false)
const creating = ref(false)
const newTeam = reactive({ name: '', shortName: '', color: TEAM_COLORS[0] })

const isNewColorDuplicate = computed(() => {
  if (!newTeam.color) return false
  return teams.value.some(t => t.color === newTeam.color)
})

async function loadTeams() {
  loading.value = true
  try {
    let { data, error } = await supabase
      .from('teams')
      .select(`*, team_players(count), owner:owner_id(username, display_name)`)
      .eq('is_active', true)
      .order('name')
    
    if (error) {
      const res = await supabase
        .from('teams')
        .select(`*, owner:owner_id(username, display_name)`)
        .eq('is_active', true)
        .order('name')
      data = res.data
    }
    
    if (data) {
      teams.value = data.map(t => ({
        ...t,
        player_count: t.team_players?.[0]?.count || 0
      })).sort((a, b) => a.name.localeCompare(b.name, 'zh-CN-u-co-pinyin'))
    }
  } catch (e) {
    console.error('加载失败:', e)
  } finally {
    loading.value = false
  }
}

async function createTeam() {
  if (!newTeam.name.trim()) return
  creating.value = true
  try {
    const { error } = await supabase.rpc('add_team', {
      p_name: newTeam.name.trim(),
      p_short_name: newTeam.shortName || null,
      p_color: newTeam.color,
      p_owner_id: auth.user?.id || null
    })
    if (error) throw error
    showCreateModal.value = false
    newTeam.name = ''
    newTeam.shortName = ''
    await loadTeams()
  } catch (e) {
    alert('创建失败：' + (e.message || '未知错误'))
  } finally {
    creating.value = false
  }
}

onMounted(() => {
  loadTeams()
})
</script>

<style scoped>
.modal-enter-active { transition: all 0.2s ease; }
.modal-leave-active { transition: all 0.15s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-from > div:last-child { transform: scale(0.95); }
</style>
