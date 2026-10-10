<template>
  <div class="page-container max-w-3xl mx-auto">
    <!-- 返回按钮 -->
    <router-link to="/teams" class="inline-flex items-center gap-1.5 text-sm text-dark-500 hover:text-primary-400 transition-colors mb-4">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
      </svg>
      返回球队列表
    </router-link>

    <!-- 加载中 -->
    <div v-if="loading" class="text-center py-20">
      <svg class="w-10 h-10 text-primary-400 animate-spin mx-auto" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
      </svg>
      <p class="text-dark-500 text-sm mt-3">加载中...</p>
    </div>

    <!-- 球队不存在 -->
    <div v-else-if="!team" class="text-center py-20">
      <p class="text-dark-500">球队不存在或已删除</p>
      <router-link to="/teams" class="text-primary-400 text-sm mt-2 inline-block">返回球队列表</router-link>
    </div>

    <template v-else>
      <!-- 球队头部 -->
      <div class="card p-5 mb-5">
        <div class="flex items-center gap-4">
          <!-- 球队色块 -->
          <div class="w-16 h-16 rounded-2xl flex-shrink-0 flex items-center justify-center text-2xl font-bold border-2"
            :style="{
              backgroundColor: (team.color || '#3b82f6') + '20',
              borderColor: (team.color || '#3b82f6') + '60',
              color: team.color || '#3b82f6'
            }">
            {{ team.name[0] }}
          </div>
          <div class="flex-1 min-w-0">
            <h1 class="text-xl font-bold text-white">{{ team.name }}</h1>
            <p class="text-sm text-dark-500">{{ team.short_name || '' }}</p>
            <div class="flex items-center gap-3 mt-1">
              <span class="text-xs text-dark-500">{{ members.length }} 名成员</span>
              <div class="flex items-center gap-1 text-xs text-dark-500">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                </svg>
                <span>{{ ownerDisplayName }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ═══ 球队信息编辑（默认折叠） ═══ -->
      <div v-if="canManage" class="card mb-5 overflow-hidden">
        <button @click="showTeamInfo = !showTeamInfo"
          class="w-full flex items-center justify-between p-4 text-left hover:bg-dark-800/40 transition-colors">
          <h2 class="font-semibold text-white text-sm flex items-center gap-2">
            <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
            </svg>
            球队信息
          </h2>
          <svg class="w-4 h-4 text-dark-500 transition-transform duration-200" :class="showTeamInfo ? 'rotate-180' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </button>
        <div v-show="showTeamInfo" class="px-5 pb-5">
          <div class="grid grid-cols-2 gap-3 mb-3">
            <div class="form-group">
              <label class="label">球队名称</label>
              <input v-model="editForm.name" type="text" class="input" />
            </div>
            <div class="form-group">
              <label class="label">简称</label>
              <input v-model="editForm.shortName" type="text" class="input" maxlength="10" />
            </div>
          </div>
          <div class="form-group mb-4">
            <label class="label">主题色</label>
            <div class="flex gap-2 flex-wrap">
              <button v-for="c in TEAM_COLORS" :key="c" type="button"
                @click="editForm.color = c"
                class="w-7 h-7 rounded-full border-2 transition-all duration-200 hover:scale-110"
                :style="{ backgroundColor: c }"
                :class="editForm.color === c ? 'border-white scale-110 shadow-lg' : 'border-transparent'"
              ></button>
            </div>
            <p v-if="isEditColorDuplicate" class="text-xs text-warning mt-1.5">⚠️ 该颜色已被其他球队使用，请更换</p>
          </div>
          <div class="flex gap-3">
            <button @click="saveTeamInfo" :disabled="saving || isEditColorDuplicate"
              class="flex-1 py-2.5 rounded-xl text-sm font-bold
                     bg-gradient-to-r from-primary-600 to-primary-500
                     text-white shadow-lg shadow-primary-600/20
                     hover:shadow-primary-600/40 hover:from-primary-500 hover:to-primary-400
                     active:scale-[0.98] transition-all duration-200 disabled:opacity-50">
              <span v-if="saving" class="flex items-center justify-center gap-2">
                <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                </svg>
                保存中...
              </span>
              <span v-else class="flex items-center justify-center gap-1.5">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
                保存信息
              </span>
            </button>
            <button @click="showDeleteConfirm = true" class="px-4 py-2.5 rounded-xl text-sm font-semibold
              bg-danger/10 border border-danger/20 text-danger hover:bg-danger/20 transition-all active:scale-[0.98]">
              删除球队
            </button>
          </div>
        </div>
      </div>

      <!-- ═══ 成员列表 ═══ -->
      <div class="card p-5">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-semibold text-white text-sm flex items-center gap-2">
            <svg class="w-4 h-4 text-accent-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            球队成员
            <span class="text-dark-500 font-normal">({{ members.length }} 人)</span>
          </h2>
          <button v-if="canManage" @click="openPlayerPicker" class="btn-primary btn-sm">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
            添加成员
          </button>
        </div>

        <!-- 成员网格 -->
        <div v-if="members.length > 0" class="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
          <router-link v-for="m in members" :key="m.player_id"
            :to="{ path: `/players/${m.player_id}`, query: { from: 'teams', teamId: route.params.id } }"
            class="relative group/member flex flex-col items-center gap-2 p-3 rounded-2xl
                   border border-dark-700/30 bg-dark-800/30
                   hover:border-primary-600/40 hover:bg-dark-800/60
                   hover:shadow-neon-blue
                   active:scale-[0.97]
                   transition-all duration-200 cursor-pointer"
          >
            <!-- 球员头像 -->
            <div class="w-11 h-11 rounded-full overflow-hidden flex items-center justify-center text-sm font-bold border-2 flex-shrink-0"
              :style="{
                backgroundColor: m.avatar_url ? 'transparent' : (team.color || '#3b82f6') + '20',
                borderColor: (team.color || '#3b82f6') + '40',
                color: team.color || '#3b82f6'
              }">
              <img v-if="m.avatar_url" :src="m.avatar_url" class="w-full h-full object-cover" />
              <span v-else>{{ m.player_name[0] }}</span>
            </div>
            <!-- 球衣号 + 姓名 -->
            <div class="text-center">
              <p class="text-sm font-semibold text-white group-hover/member:text-primary-300 transition-colors">
                {{ m.player_name }}
              </p>
              <!-- 管理员：球衣号+位置可点击编辑 -->
              <button v-if="canManage" @click.prevent="openJerseyEdit(m)"
                class="flex items-center justify-center gap-1 mt-0.5 mx-auto px-2 py-1 rounded-lg
                       bg-dark-800/60 border border-dark-600 hover:border-primary-500/50
                       hover:bg-primary-500/10 transition-all duration-150"
              >
                <span class="text-[11px] font-bold" :style="{ color: team.color || '#3b82f6' }">
                  #{{ m.jersey_no || '?' }}
                </span>
                <span v-if="m.team_position" class="text-[10px] text-dark-400">
                  {{ POSITION_LABELS[m.team_position] || m.team_position }}
                </span>
                <span v-else class="text-[10px] text-dark-600">未设置</span>
                <svg class="w-3 h-3 text-dark-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>
              <!-- 游客：只读球衣号+位置 -->
              <div v-else class="flex items-center justify-center gap-1 mt-0.5">
                <span class="text-[11px] font-bold" :style="{ color: team.color || '#3b82f6' }">
                  #{{ m.jersey_no || '?' }}
                </span>
                <span v-if="m.team_position" class="text-[10px] text-dark-500">
                  {{ POSITION_LABELS[m.team_position] || m.team_position }}
                </span>
              </div>
            </div>
            <!-- 跳转提示箭头 -->
            <svg class="absolute top-2 right-2 w-3.5 h-3.5 text-dark-600
                       group-hover/member:text-primary-400 opacity-0 group-hover/member:opacity-100
                       transition-all duration-200 group-hover/member:translate-x-0.5"
              fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
            </svg>
            <!-- 管理员移除按钮 -->
            <button v-if="canManage" @click.prevent="removeMember(m)"
              class="absolute top-2 left-2 w-5 h-5 rounded-md flex items-center justify-center
                     text-dark-500 hover:text-danger hover:bg-danger/10
                     transition-all duration-150"
              title="移除成员">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </router-link>
        </div>
        <div v-else class="text-center py-10 text-dark-500 text-sm border border-dark-700/30 rounded-xl">
          暂无成员
        </div>
      </div>
    </template>

    <!-- 球衣号编辑弹窗 -->
    <Teleport v-if="jerseyEditPlayer" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="jerseyEditPlayer = null">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click.self="jerseyEditPlayer = null"></div>
          <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass">
            <div class="text-center">
              <div class="w-14 h-14 rounded-full bg-primary-600/10 border border-primary-600/20 flex items-center justify-center mx-auto mb-4">
                <span class="text-2xl font-black" :style="{ color: team?.color || '#3b82f6' }">
                  #{{ jerseyEditPlayer.jersey_no }}
                </span>
              </div>
              <h3 class="text-lg font-semibold text-white mb-1">修改球衣号</h3>
              <p class="text-sm text-dark-400 mb-4">{{ jerseyEditPlayer.player_name }}</p>
              <input v-model.number="jerseyEditNo" type="number" min="0" max="99"
                class="input text-center text-2xl font-bold mb-3" placeholder="0-99"
                @keyup.enter="saveJersey" />
              <div class="mb-4">
                <label class="block text-xs text-dark-400 mb-1.5">球队位置</label>
                <select v-model="jerseyEditPosition"
                  class="w-full bg-dark-800 border border-dark-600 rounded-xl px-3 py-2 text-sm text-white
                         focus:border-primary-500 outline-none transition-all">
                  <option value="">不指定</option>
                  <option v-if="jerseyEditPlayer.player_positions"
                    v-for="pos in jerseyEditPlayer.player_positions.split(',').filter(Boolean)" :key="pos" :value="pos">
                    {{ POSITION_LABELS[pos] || pos }} ({{ pos }})
                  </option>
                </select>
              </div>
              <div class="flex gap-3">
                <button @click="jerseyEditPlayer = null" class="btn-secondary flex-1">取消</button>
                <button @click="saveJersey" :disabled="savingJersey || jerseyEditNo < 0 || jerseyEditNo > 99"
                  class="btn-primary flex-1" :class="{ 'opacity-50': savingJersey }">
                  {{ savingJersey ? '保存中...' : '确认' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- 删除确认弹窗 -->
    <Teleport v-if="showDeleteConfirm" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="showDeleteConfirm = false">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>
          <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass">
            <div class="text-center">
              <div class="w-14 h-14 rounded-full bg-danger/10 border border-danger/20 flex items-center justify-center mx-auto mb-4">
                <svg class="w-7 h-7 text-danger" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
              </div>
              <h3 class="text-lg font-semibold text-white mb-2">删除球队</h3>
              <p class="text-sm text-dark-400 mb-1">确定要删除 <span class="text-white font-medium">"{{ team?.name }}"</span> 吗？</p>
              <p class="text-xs text-dark-500 mb-5">球队将被标记为已删除，成员关联保留</p>
              <div class="flex gap-3">
                <button @click="showDeleteConfirm = false" class="btn-secondary flex-1">取消</button>
                <button @click="doDeleteTeam" :disabled="deleting" class="flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold
                  bg-danger/20 border border-danger/30 text-danger hover:bg-danger/30 transition-all">
                  {{ deleting ? '删除中...' : '确认删除' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- 球员选择器弹窗 -->
    <Teleport v-if="showPlayerPicker" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center" @click.self="showPlayerPicker = false">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showPlayerPicker = false"></div>
          <div class="relative bg-dark-850 rounded-t-2xl sm:rounded-2xl w-full sm:max-w-lg max-h-[85vh] flex flex-col shadow-glass border border-dark-700/50">
            <div class="flex items-center justify-between p-4 border-b border-dark-700/30 flex-shrink-0">
              <h3 class="font-semibold text-white flex items-center gap-2">
                <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                选择球员
                <span v-if="pickerSelected.size > 0" class="text-xs font-normal text-primary-400">
                  (已选 {{ pickerSelected.size }} 人)
                </span>
              </h3>
              <button @click="showPlayerPicker = false" class="text-dark-500 hover:text-white transition-colors p-1 rounded-lg hover:bg-dark-800">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="p-4 pb-2 flex-shrink-0">
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-dark-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <input v-model="pickerSearch" type="text" class="input pl-10 text-sm" placeholder="输入姓名搜索..." />
              </div>
            </div>
            <div class="flex-1 overflow-y-auto px-4 pb-2">
              <div v-if="pickerList.length === 0" class="text-center py-10 text-dark-500 text-sm">
                {{ pickerSearch ? '没有匹配的球员' : '暂无可添加的球员' }}
              </div>
              <div v-else class="space-y-1">
                <button v-for="p in pickerList" :key="p.id" type="button"
                  @click="togglePickerSelect(p)"
                  class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-150 text-left"
                  :class="p._inTeam
                    ? 'opacity-40 cursor-not-allowed bg-dark-800/30'
                    : pickerSelected.has(p.id)
                      ? 'bg-primary-600/15 border border-primary-600/30'
                      : 'hover:bg-dark-800/60'"
                >
                  <div class="w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0 transition-all duration-150"
                    :class="p._inTeam
                      ? 'border-dark-700 bg-dark-800'
                      : pickerSelected.has(p.id)
                        ? 'border-primary-500 bg-primary-600'
                        : 'border-dark-600'">
                    <svg v-if="pickerSelected.has(p.id)" class="w-3 h-3 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                  <div class="w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold flex-shrink-0 bg-dark-800 text-dark-400">
                    {{ p.name[0] }}
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm text-white truncate">{{ p.name }}</p>
                    <p class="text-[10px] text-dark-500">
                      <span v-if="p.height">{{ p.height }}cm</span>
                      <span v-if="p.height && p.position"> · </span>
                      <span v-if="p.position">{{ p.position.split(',').map(pos => POSITION_LABELS[pos] || pos).join('/') }}</span>
                    </p>
                  </div>
                  <div v-if="pickerSelected.has(p.id)" class="flex items-center gap-1 flex-shrink-0" @click.stop>
                    <select
                      :value="pickerPositions[p.id] || ''"
                      @change="pickerPositions[p.id] = $event.target.value"
                      class="px-1.5 py-1 rounded-lg text-[10px] bg-dark-800 border border-dark-600
                             text-dark-300 outline-none focus:border-primary-500 flex-shrink-0">
                      <option value="">选位置</option>
                      <option v-if="p.position"
                        v-for="pos in p.position.split(',').filter(Boolean)" :key="pos" :value="pos">
                        {{ POSITION_LABELS[pos] || pos }} ({{ pos }})
                      </option>
                    </select>
                  </div>
                  <span v-if="p._inTeam" class="text-[10px] text-dark-600 flex-shrink-0">已在队中</span>
                </button>
              </div>
            </div>
            <div class="p-4 border-t border-dark-700/30 flex items-center justify-between flex-shrink-0">
              <button @click="pickerSelectAll" class="text-xs text-primary-400 hover:text-primary-300 transition-colors">
                {{ pickerSelected.size === selectableCount && selectableCount > 0 ? '取消全选' : '全选' }}
              </button>
              <div class="flex gap-2">
                <button @click="showPlayerPicker = false" class="btn-secondary btn-sm">取消</button>
                <button @click="confirmBatchAdd" :disabled="pickerSelected.size === 0 || batchAdding"
                  class="btn-primary btn-sm">
                  {{ batchAdding ? '添加中...' : `确认添加 (${pickerSelected.size})` }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { TEAM_COLORS, POSITION_LABELS } from '@/utils/helpers'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const teamId = computed(() => route.params.id)

const loading = ref(true)
const team = ref(null)
const members = ref([])
const allPlayers = ref([])
const allTeams = ref([])

const saving = ref(false)
const editForm = reactive({ name: '', shortName: '', color: TEAM_COLORS[0] })

const showDeleteConfirm = ref(false)
const deleting = ref(false)
const showTeamInfo = ref(false)

const showPlayerPicker = ref(false)
const pickerSearch = ref('')
const pickerSelected = ref(new Set())
const pickerPositions = ref({})
const batchAdding = ref(false)

const jerseyEditPlayer = ref(null)
const jerseyEditNo = ref(0)
const jerseyEditPosition = ref('')
const savingJersey = ref(false)

const canManage = computed(() => {
  return auth.isSuperAdmin || team.value?.owner_id === auth.user?.id
})

// 实时计算管理员显示名称（如果当前用户是管理员，显示最新的 display_name）
const ownerDisplayName = computed(() => {
  if (!team.value?.owner_id) return '未知'
  // 如果当前用户就是管理员，使用 auth 中最新的 display_name
  if (team.value.owner_id === auth.user?.id) {
    return auth.profile?.display_name || auth.user?.username || '未知'
  }
  // 否则使用 team.owner 中的数据
  return team.value.owner?.display_name || team.value.owner?.username || '未知'
})

const isEditColorDuplicate = computed(() => {
  if (!editForm.color || !teamId.value) return false
  return allTeams.value.some(t => t.color === editForm.color && t.id !== teamId.value)
})

const pickerList = computed(() => {
  const q = pickerSearch.value.trim().toLowerCase()
  const memberIds = new Set(members.value.map(m => m.player_id))
  let list = allPlayers.value.map(p => ({ ...p, _inTeam: memberIds.has(p.id) }))
  if (q) {
    list = list.filter(p => p.name.toLowerCase().includes(q))
  }
  return [...list].sort((a, b) => a.name.localeCompare(b.name, 'zh-CN-u-co-pinyin'))
})

const selectableCount = computed(() => pickerList.value.filter(p => !p._inTeam).length)

async function loadTeam() {
  loading.value = true
  try {
    const [teamRes, membersRes, playersRes, teamsRes] = await Promise.all([
      supabase.from('teams').select('*, owner:owner_id(username, display_name)').eq('id', teamId.value).single(),
      supabase.from('team_players').select(`*, players!inner(id, name, position, height, avatar_url)`).eq('team_id', teamId.value).eq('is_active', true).order('jersey_no'),
      supabase.from('players').select('id, name, position, height, weight').eq('is_active', true),
      supabase.from('teams').select('id, color').eq('is_active', true)
    ])
    
    if (teamRes.data) {
      team.value = teamRes.data
      editForm.name = teamRes.data.name || ''
      editForm.shortName = teamRes.data.short_name || ''
      editForm.color = teamRes.data.color || TEAM_COLORS[0]
    }
    
    if (membersRes.data) {
      members.value = membersRes.data.map(m => ({
        player_id: m.player_id,
        jersey_no: m.jersey_no,
        player_name: m.players?.name || '',
        position: m.players?.position || '',
        team_position: m.position || '',
        height: m.players?.height || null,
        avatar_url: m.players?.avatar_url || null
      }))
    }
    
    allPlayers.value = playersRes.data || []
    allTeams.value = teamsRes.data || []
  } catch (e) {
    console.error('加载失败:', e)
  } finally {
    loading.value = false
  }
}

async function saveTeamInfo() {
  saving.value = true
  try {
    const { error } = await supabase.rpc('update_team', {
      p_team_id: teamId.value,
      p_name: editForm.name.trim() || null,
      p_short_name: editForm.shortName || null,
      p_color: editForm.color
    })
    if (error) throw error
    team.value.name = editForm.name
    team.value.short_name = editForm.shortName
    team.value.color = editForm.color
  } catch (e) {
    alert('保存失败：' + (e.message || '未知错误'))
  } finally {
    saving.value = false
  }
}

async function doDeleteTeam() {
  deleting.value = true
  try {
    const { error } = await supabase.rpc('delete_team', { p_team_id: teamId.value })
    if (error) throw error
    router.push('/teams')
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  } finally {
    deleting.value = false
  }
}

function openPlayerPicker() {
  pickerSearch.value = ''
  pickerSelected.value = new Set()
  pickerPositions.value = {}
  showPlayerPicker.value = true
}

function togglePickerSelect(p) {
  if (p._inTeam) return
  const newSet = new Set(pickerSelected.value)
  const newPositions = { ...pickerPositions.value }
  if (newSet.has(p.id)) {
    newSet.delete(p.id)
    delete newPositions[p.id]
  } else {
    newSet.add(p.id)
    const positions = (p.position || '').split(',').filter(Boolean)
    newPositions[p.id] = positions[0] || ''
  }
  pickerSelected.value = newSet
  pickerPositions.value = newPositions
}

function pickerSelectAll() {
  const selectable = pickerList.value.filter(p => !p._inTeam)
  if (pickerSelected.value.size === selectable.length) {
    pickerSelected.value = new Set()
    pickerPositions.value = {}
  } else {
    pickerSelected.value = new Set(selectable.map(p => p.id))
    const positions = {}
    for (const p of selectable) {
      const pos = (p.position || '').split(',').filter(Boolean)
      positions[p.id] = pos[0] || ''
    }
    pickerPositions.value = positions
  }
}

async function confirmBatchAdd() {
  if (pickerSelected.value.size === 0) return
  batchAdding.value = true
  const ids = [...pickerSelected.value]
  let successCount = 0
  for (const playerId of ids) {
    try {
      const { error } = await supabase.rpc('add_team_player', {
        p_team_id: teamId.value,
        p_player_id: playerId,
        p_jersey_no: null,
        p_position: pickerPositions.value[playerId] || null
      })
      if (!error) successCount++
    } catch {}
  }
  pickerSelected.value = new Set()
  pickerPositions.value = {}
  showPlayerPicker.value = false
  await loadTeam()
  batchAdding.value = false
}

function openJerseyEdit(m) {
  jerseyEditPlayer.value = {
    player_id: m.player_id,
    player_name: m.player_name,
    jersey_no: m.jersey_no,
    team_position: m.team_position || '',
    player_positions: m.position || ''
  }
  jerseyEditNo.value = m.jersey_no || 0
  jerseyEditPosition.value = m.team_position || ''
}

async function saveJersey() {
  if (!jerseyEditPlayer.value) return
  savingJersey.value = true
  try {
    await supabase.rpc('update_player_jersey', {
      p_team_id: teamId.value,
      p_player_id: jerseyEditPlayer.value.player_id,
      p_new_jersey_no: jerseyEditNo.value
    })
    if (jerseyEditPosition.value !== jerseyEditPlayer.value.team_position) {
      await supabase.rpc('update_team_player_position', {
        p_team_id: teamId.value,
        p_player_id: jerseyEditPlayer.value.player_id,
        p_position: jerseyEditPosition.value || null
      })
    }
    jerseyEditPlayer.value = null
    await loadTeam()
  } catch (e) {
    alert('修改失败：' + (e.message || '未知错误'))
  } finally {
    savingJersey.value = false
  }
}

async function removeMember(m) {
  if (!confirm(`确定将 ${m.player_name} 从球队移除？`)) return
  try {
    const { error } = await supabase.rpc('remove_team_player', {
      p_team_id: teamId.value,
      p_player_id: m.player_id
    })
    if (error) throw error
    await loadTeam()
  } catch (e) {
    alert('移除失败：' + (e.message || '未知错误'))
  }
}

onMounted(() => {
  loadTeam()
})
</script>

<style scoped>
.modal-enter-active { transition: all 0.2s ease; }
.modal-leave-active { transition: all 0.15s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-from > div:last-child { transform: scale(0.95); }
</style>
