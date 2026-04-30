<template>
  <div class="page-container">
    <div class="flex items-center justify-between mb-5">
      <h1 class="page-title">球员名册</h1>
      <button v-if="auth.isAdmin" @click="openCreateForm" class="btn-primary btn-sm">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        添加球员
      </button>
    </div>

    <!-- 添加/编辑球员表单（内嵌） -->
    <Transition name="slide-down">
      <div v-if="showForm" class="card p-5 mb-5 border-primary-600/30 shadow-neon-blue">
        <div class="flex items-center justify-between mb-4">
          <h3 class="font-semibold text-white flex items-center gap-2">
            <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
            {{ editingId ? '编辑球员' : '添加新球员' }}
          </h3>
          <button type="button" @click="closeForm" class="text-dark-500 hover:text-white transition-colors p-1 rounded-lg hover:bg-dark-800">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <form @submit.prevent="editingId ? saveEdit() : createPlayer()" class="space-y-4">

          <!-- 头像 + 姓名 -->
          <div class="flex items-start gap-4">
            <!-- 头像上传 -->
            <div class="flex-shrink-0">
              <div class="relative group cursor-pointer" @click="triggerAvatarUpload">
                <div class="w-20 h-20 rounded-full bg-dark-800 border-2 border-dashed border-dark-600
                            flex items-center justify-center overflow-hidden transition-all duration-200
                            group-hover:border-primary-500 group-hover:bg-dark-750">
                  <img v-if="avatarPreview" :src="avatarPreview" class="w-full h-full object-cover" />
                  <div v-else class="text-center">
                    <svg class="w-6 h-6 text-dark-500 group-hover:text-primary-400 transition-colors mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    <span class="text-[10px] text-dark-500 group-hover:text-primary-400 transition-colors">上传头像</span>
                  </div>
                </div>
                <!-- 上传中遮罩 -->
                <div v-if="uploadingAvatar" class="absolute inset-0 rounded-full bg-dark-900/70 flex items-center justify-center">
                  <svg class="w-5 h-5 text-primary-400 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                  </svg>
                </div>
              </div>
              <input ref="avatarInput" type="file" accept="image/jpeg,image/png,image/gif,image/webp"
                class="hidden" @change="handleAvatarChange" />
              <p class="text-[10px] text-dark-600 text-center mt-1">点击上传</p>
            </div>
            <!-- 姓名输入 -->
            <div class="flex-1 form-group">
              <label class="label">姓名 <span class="text-accent-400">*</span></label>
              <input v-model="formData.name" type="text" class="input" required placeholder="球员姓名" />
            </div>
          </div>

          <!-- 身高 + 体重 -->
          <div class="grid grid-cols-2 gap-3">
            <div class="form-group">
              <label class="label">身高(cm) <span class="text-accent-400">*</span></label>
              <input v-model.number="formData.height" type="number" class="input" min="100" max="250" required placeholder="如 180" />
            </div>
            <div class="form-group">
              <label class="label">体重(kg) <span class="text-accent-400">*</span></label>
              <input v-model.number="formData.weight" type="number" class="input" min="30" max="200" required placeholder="如 75" />
            </div>
          </div>

          <!-- 位置多选标签 -->
          <div class="form-group">
            <label class="label">可打位置</label>
            <div class="flex flex-wrap gap-2">
              <button v-for="(label, key) in POSITION_LABELS" :key="key" type="button"
                @click="togglePosition(key)"
                class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all duration-200"
                :class="formData.positions.includes(key)
                  ? 'bg-primary-600/20 border-primary-500/50 text-primary-300'
                  : 'bg-dark-800 border-dark-700 text-dark-400 hover:border-dark-600 hover:text-dark-300'"
              >{{ label }} ({{ key }})</button>
            </div>
          </div>

          <!-- 技能标签 -->
          <div class="form-group">
            <label class="label">技能标签</label>
            <div class="flex flex-wrap gap-2 mb-2">
              <button v-for="skill in PRESET_SKILLS" :key="skill" type="button"
                @click="toggleSkill(skill)"
                class="px-3 py-1 rounded-full text-xs font-medium border transition-all duration-200"
                :class="formData.skills.includes(skill)
                  ? 'bg-accent-500/15 border-accent-500/30 text-accent-300'
                  : 'bg-dark-800 border-dark-700 text-dark-400 hover:border-dark-600 hover:text-dark-300'"
              >{{ skill }}</button>
            </div>
            <input v-model="customSkill" type="text" class="input" placeholder="输入自定义技能后回车添加"
              @keydown.enter.prevent="addCustomSkill" />
            <div v-if="formData.skills.length > 0" class="flex flex-wrap gap-1.5 mt-2">
              <span v-for="(s, i) in formData.skills" :key="i"
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs
                       bg-accent-500/15 border border-accent-500/30 text-accent-300">
                {{ s }}
                <button type="button" @click="removeSkill(i)" class="hover:text-white transition-colors">&times;</button>
              </span>
            </div>
          </div>

          <!-- 备注 -->
          <div class="form-group">
            <label class="label">备注</label>
            <textarea v-model="formData.notes" class="input resize-none" rows="2" placeholder="选填"></textarea>
          </div>

          <!-- 操作按钮 -->
          <div class="flex gap-2 pt-1">
            <button type="button" @click="closeForm" class="btn-secondary flex-1">取消</button>
            <button type="submit" class="btn-primary flex-1" :disabled="creating">
              {{ creating ? '保存中...' : (editingId ? '保存修改' : '确认添加') }}
            </button>
          </div>
        </form>
      </div>
    </Transition>

    <!-- 删除确认弹窗 -->
    <Transition name="fade">
      <div v-if="deletingPlayer" class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="deletingPlayer = null">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>
        <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass animate-scale-in">
          <div class="text-center">
            <div class="w-14 h-14 rounded-full bg-danger/10 border border-danger/20 flex items-center justify-center mx-auto mb-4">
              <svg class="w-7 h-7 text-danger" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-white mb-2">删除球员档案</h3>
            <p class="text-sm text-dark-400 mb-1">确定要删除球员 <span class="text-white font-medium">"{{ deletingPlayer.name }}"</span> 吗？</p>
            <p class="text-xs text-dark-500 mb-5">该球员将被标记为已删除，相关比赛数据保留</p>
            <div class="flex gap-3">
              <button @click="deletingPlayer = null" class="btn-secondary flex-1">取消</button>
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

    <!-- 搜索 -->
    <div class="mb-5 relative">
      <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-dark-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
      </svg>
      <input v-model="search" type="text" class="input pl-10" placeholder="搜索球员姓名..." />
    </div>

    <!-- 加载骨架 -->
    <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
      <div v-for="i in 8" :key="i" class="skeleton h-36 rounded-2xl"></div>
    </div>

    <!-- 空状态 -->
    <div v-else-if="filteredPlayers.length === 0 && !showForm" class="empty-state">
      <svg class="w-16 h-16 text-dark-600 mb-3" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.5">
        <circle cx="32" cy="24" r="10" opacity="0.4"/>
        <path d="M16 52 Q16 40 32 40 Q48 40 48 52" opacity="0.4"/>
        <text x="32" y="58" text-anchor="middle" fill="currentColor" stroke="none" font-size="9" opacity="0.4">EMPTY</text>
      </svg>
      <p class="text-dark-500">{{ search ? '没有找到匹配的球员' : '暂无球员' }}</p>
    </div>

    <!-- 球员网格 -->
    <div v-else-if="filteredPlayers.length > 0" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
      <div v-for="(player, idx) in filteredPlayers" :key="player.id"
        class="card card-body flex flex-col items-center text-center gap-2.5
               hover:border-primary-600/30 hover:shadow-neon-blue transition-all duration-300 animate-fade-in
               relative group"
        :style="{ animationDelay: `${idx * 50}ms` }"
      >
        <!-- 管理员操作按钮（右上角） -->
        <div v-if="auth.isAdmin"
          class="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity duration-200 z-10">
          <button @click.prevent="openEditForm(player)" title="编辑"
            class="w-7 h-7 rounded-lg bg-dark-800/90 border border-dark-700/50
                   flex items-center justify-center text-dark-400 hover:text-primary-400
                   hover:border-primary-500/30 transition-all duration-150">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
            </svg>
          </button>
          <button @click.prevent="startDelete(player)" title="删除"
            class="w-7 h-7 rounded-lg bg-dark-800/90 border border-dark-700/50
                   flex items-center justify-center text-dark-400 hover:text-danger
                   hover:border-danger/30 transition-all duration-150">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
            </svg>
          </button>
        </div>

        <!-- 点击整个卡片跳转详情 -->
        <router-link :to="`/players/${player.id}`" class="flex flex-col items-center text-center gap-2.5 w-full">
          <div class="w-14 h-14 rounded-full bg-primary-600/15 border-2 border-primary-600/30
                      text-primary-400 flex items-center justify-center text-xl font-bold overflow-hidden">
            <img v-if="player.avatar_url" :src="player.avatar_url" class="w-full h-full object-cover" />
            <span v-else>{{ getInitials(player.name) }}</span>
          </div>
          <div>
            <p class="font-semibold text-white text-sm">{{ player.name }}</p>
            <p v-if="player.height || player.weight" class="text-xs text-dark-500 mt-0.5">
              {{ player.height || '-' }}cm / {{ player.weight || '-' }}kg
            </p>
            <div v-if="player.position" class="flex flex-wrap gap-1 justify-center mt-1">
              <span v-for="pos in player.position.split(',')" :key="pos"
                class="text-[10px] px-1.5 py-0.5 rounded bg-primary-600/15 text-primary-400">
                {{ POSITION_LABELS[pos] || pos }}
              </span>
            </div>
            <div v-if="player.skills" class="flex flex-wrap gap-1 justify-center mt-1">
              <span v-for="skill in player.skills.split(',').filter(Boolean).slice(0, 3)" :key="skill"
                class="text-[10px] px-1.5 py-0.5 rounded bg-accent-500/10 text-accent-400">
                {{ skill }}
              </span>
              <span v-if="player.skills.split(',').filter(Boolean).length > 3"
                class="text-[10px] text-dark-500">+{{ player.skills.split(',').filter(Boolean).length - 3 }}</span>
            </div>
          </div>
        </router-link>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { getInitials, POSITION_LABELS } from '@/utils/helpers'

const auth = useAuthStore()
const route = useRoute()
const players = ref([])
const loading = ref(true)
const search = ref('')
const showForm = ref(false)
const creating = ref(false)
const customSkill = ref('')
const avatarInput = ref(null)

// 编辑状态
const editingId = ref(null)

// 删除状态
const deletingPlayer = ref(null)
const deleting = ref(false)

// 头像相关
const avatarPreview = ref(null)
const avatarFile = ref(null)
const uploadingAvatar = ref(false)

// 预设技能标签
const PRESET_SKILLS = ['三分', '突破', '防守', '篮板', '助攻', '盖帽', '抢断', '中投', '运球', '扣篮']

// 表单数据（创建和编辑共用）
const formData = reactive({
  name: '',
  positions: [],
  height: null,
  weight: null,
  skills: [],
  notes: ''
})

// ── 表单操作 ──
function openCreateForm() {
  editingId.value = null
  resetForm()
  showForm.value = true
}

function openEditForm(player) {
  editingId.value = player.id
  formData.name = player.name || ''
  formData.positions = player.position ? player.position.split(',').filter(Boolean) : []
  formData.height = player.height || null
  formData.weight = player.weight || null
  formData.skills = player.skills ? player.skills.split(',').filter(Boolean) : []
  formData.notes = player.notes || ''
  avatarPreview.value = player.avatar_url || null
  avatarFile.value = null
  showForm.value = true
}

function closeForm() {
  showForm.value = false
  resetForm()
}

function resetForm() {
  editingId.value = null
  formData.name = ''
  formData.positions = []
  formData.height = null
  formData.weight = null
  formData.skills = []
  formData.notes = ''
  avatarPreview.value = null
  avatarFile.value = null
  customSkill.value = ''
}

function triggerAvatarUpload() {
  avatarInput.value?.click()
}

// ── 位置多选 ──
function togglePosition(key) {
  const idx = formData.positions.indexOf(key)
  if (idx >= 0) formData.positions.splice(idx, 1)
  else formData.positions.push(key)
}

// ── 技能标签 ──
function toggleSkill(skill) {
  const idx = formData.skills.indexOf(skill)
  if (idx >= 0) formData.skills.splice(idx, 1)
  else formData.skills.push(skill)
}

function addCustomSkill() {
  const s = customSkill.value.trim()
  if (s && !formData.skills.includes(s)) {
    formData.skills.push(s)
    customSkill.value = ''
  }
}

function removeSkill(idx) {
  formData.skills.splice(idx, 1)
}

// ── 头像上传 ──
function handleAvatarChange(e) {
  const file = e.target.files[0]
  if (!file) return
  if (file.size > 2 * 1024 * 1024) {
    alert('图片大小不能超过 2MB')
    return
  }
  avatarFile.value = file
  avatarPreview.value = URL.createObjectURL(file)
}

async function uploadAvatar(playerId) {
  if (!avatarFile.value || !playerId) return null
  uploadingAvatar.value = true
  try {
    const ext = avatarFile.value.name.split('.').pop()
    const filePath = `${playerId}.${ext}`
    const { error } = await supabase.storage
      .from('avatars')
      .upload(filePath, avatarFile.value, { upsert: true })
    if (error) throw error

    // 获取公开 URL
    const { data: urlData } = supabase.storage
      .from('avatars')
      .getPublicUrl(filePath)
    const publicUrl = urlData.publicUrl + '?t=' + Date.now()

    // 通过 RPC 写入 avatar_url（绕过 RLS）
    const { error: updateErr } = await supabase.rpc('update_player_avatar', {
      p_player_id: playerId,
      p_avatar_url: publicUrl
    })
    if (updateErr) console.error('写入头像URL失败:', updateErr)

    return publicUrl
  } catch (e) {
    console.error('头像上传失败:', e)
    return null
  } finally {
    uploadingAvatar.value = false
  }
}

// ── 搜索过滤 ──
const filteredPlayers = computed(() => {
  let list = players.value
  const q = search.value.trim().toLowerCase()
  if (q) {
    list = list.filter(p => p.name.toLowerCase().includes(q))
  }
  // 按拼音/字母/数字排序（中文会按拼音排列）
  return [...list].sort((a, b) => a.name.localeCompare(b.name, 'zh-CN-u-co-pinyin'))
})

// ── 加载球员列表 ──
async function loadPlayers() {
  const { data } = await supabase
    .from('players')
    .select('id, name, position, avatar_url, height, weight, skills')
    .eq('is_active', true)
    .order('name')
  if (data) players.value = data
  loading.value = false
}

// ── 创建球员 ──
async function createPlayer() {
  if (!formData.name.trim()) return
  if (!formData.height || !formData.weight) {
    alert('请填写身高和体重')
    return
  }
  creating.value = true
  try {
    const { data: result, error } = await supabase.rpc('add_player', {
      p_name: formData.name.trim(),
      p_position: formData.positions.length > 0 ? formData.positions.join(',') : null,
      p_height: formData.height || null,
      p_weight: formData.weight || null,
      p_skills: formData.skills.length > 0 ? formData.skills.join(',') : null,
      p_notes: formData.notes.trim() || null
    })
    if (error) throw error

    // 上传头像（通过 RPC 写入）
    if (avatarFile.value && result?.player_id) {
      await uploadAvatar(result.player_id)
    }

    closeForm()
    await loadPlayers()
  } catch (e) {
    alert('添加失败：' + (e.message || '未知错误'))
  } finally {
    creating.value = false
  }
}

// ── 编辑球员 ──
async function saveEdit() {
  if (!formData.name.trim()) return
  creating.value = true
  try {
    const { error } = await supabase.rpc('update_player', {
      p_player_id: editingId.value,
      p_name: formData.name.trim(),
      p_position: formData.positions.length > 0 ? formData.positions.join(',') : null,
      p_height: formData.height || null,
      p_weight: formData.weight || null,
      p_skills: formData.skills.length > 0 ? formData.skills.join(',') : null,
      p_notes: formData.notes.trim() || null
    })
    if (error) throw error

    // 如果更换了头像
    if (avatarFile.value) {
      await uploadAvatar(editingId.value)
    }

    closeForm()
    await loadPlayers()
  } catch (e) {
    alert('修改失败：' + (e.message || '未知错误'))
  } finally {
    creating.value = false
  }
}

// ── 删除球员 ──
function startDelete(player) {
  deletingPlayer.value = player
}

async function confirmDelete() {
  if (!deletingPlayer.value) return
  deleting.value = true
  try {
    const { error } = await supabase.rpc('delete_player', {
      p_player_id: deletingPlayer.value.id
    })
    if (error) throw error

    deletingPlayer.value = null
    await loadPlayers()
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  await loadPlayers()
  // 如果从球员详情页跳过来编辑，自动打开编辑表单
  const editId = route.query.editId
  if (editId && players.value.length > 0) {
    const target = players.value.find(p => p.id === editId)
    if (target) openEditForm(target)
  }
})

// 监听路由 query 变化（再次进入编辑）
watch(() => route.query.editId, (newId) => {
  if (newId && players.value.length > 0) {
    const target = players.value.find(p => p.id === newId)
    if (target) openEditForm(target)
  }
})
</script>

<style scoped>
.slide-down-enter-active {
  transition: all 0.3s ease-out;
}
.slide-down-leave-active {
  transition: all 0.2s ease-in;
}
.slide-down-enter-from {
  opacity: 0;
  transform: translateY(-10px);
  max-height: 0;
  margin-bottom: 0;
}
.slide-down-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>
