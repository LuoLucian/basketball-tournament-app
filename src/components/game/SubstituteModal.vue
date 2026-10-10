<template>
  <Teleport to="body">
    <Transition name="modal">
      <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
        <!-- 背景遮罩 -->
        <div class="absolute inset-0 bg-black/70 backdrop-blur-sm" @click="$emit('close')"></div>

        <!-- 弹窗 -->
        <div class="relative w-full sm:max-w-lg h-[92vh] sm:h-auto sm:max-h-[88vh] bg-dark-850 rounded-t-2xl sm:rounded-2xl
                    flex flex-col border border-dark-700/50 shadow-glass overflow-hidden">
          <!-- 标题 -->
          <div class="px-4 py-3 border-b border-dark-700/50 flex items-start justify-between gap-2 flex-shrink-0">
            <div class="min-w-0">
              <h3 class="font-bold text-white text-base flex items-center gap-2">
                <span class="w-2 h-2 rounded-full flex-shrink-0" :style="{ backgroundColor: team?.color || '#3b82f6' }"></span>
                {{ isStarting ? '选择首发阵容' : '换人' }}
                <span class="text-xs text-dark-400 font-medium truncate">{{ team?.name }}</span>
              </h3>
              <p class="text-[11px] text-dark-400 mt-1">
                {{ isStarting
                  ? '点击下方球员加入首发（最多 5 人），点击已选球员可移除'
                  : '标记下场（红）/上场（绿）后点「替换」暂存，可多批操作；点「完成」才真正换人' }}
              </p>
            </div>
            <button @click="$emit('close')" class="p-2 rounded-xl hover:bg-dark-800 transition-colors flex-shrink-0">
              <svg class="w-5 h-5 text-dark-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- 内容 -->
          <div class="flex-1 overflow-y-auto">
            <!-- 上半区：在场 / 已选首发（本地暂存状态） -->
            <div class="px-3 pt-3">
              <div class="flex items-center justify-between px-1 mb-2">
                <p class="text-[11px] font-bold text-dark-300 uppercase tracking-wider">
                  {{ isStarting ? '已选首发' : '在场球员' }} · {{ isStarting ? previewCount : courtCount }}/5
                </p>
                <p v-if="outSel.length" class="text-[10px] font-bold text-red-400">下场 {{ outSel.length }} 人</p>
              </div>
              <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
                <!-- 在场球员卡片 -->
                <button v-for="p in courtList" :key="'c-'+p.id" @click="toggleOut(p)"
                  class="relative rounded-xl border p-2.5 flex flex-col items-center gap-1.5 transition-all active:scale-95"
                  :class="isOut(p.id)
                    ? 'border-red-500 bg-red-500/15 ring-2 ring-red-500/40'
                    : 'border-dark-700 bg-dark-800 hover:border-dark-600'">
                  <span v-if="isOut(p.id)" class="absolute top-1 right-1 text-[9px] font-black text-red-300 bg-red-500/30 border border-red-500/50 rounded px-1">下场</span>
                  <div class="w-[52px] h-[52px] rounded-full flex-shrink-0 flex items-center justify-center text-sm font-bold text-white overflow-hidden border-2"
                       :style="{ backgroundColor: team?.color || '#334155', borderColor: isOut(p.id) ? '#ef4444' : 'rgba(255,255,255,0.1)' }">
                    <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover" alt="">
                    <span v-else>{{ p.name?.charAt(0) || '?' }}</span>
                  </div>
                  <p class="text-[13px] font-black tabular-nums leading-none" :style="{ color: team?.color || '#94a3b8' }">#{{ p.jersey_no || '?' }}</p>
                  <p class="text-[11px] text-white font-medium truncate w-full text-center leading-tight">{{ p.name }}</p>
                  <span v-if="pfChip(p)" class="text-[9px] px-1.5 py-0.5 rounded font-black" :class="pfChip(p)">{{ pfMap[p.id] || 0 }}犯</span>
                </button>
                <!-- 空位 -->
                <div v-for="i in (5 - courtList.length)" :key="'e-'+i"
                  class="rounded-xl border border-dashed border-dark-700/40 p-2.5 flex flex-col items-center gap-1.5">
                  <div class="w-[52px] h-[52px] rounded-full bg-dark-800/50 flex items-center justify-center text-dark-600 text-xl">+</div>
                  <p class="text-[10px] text-dark-700">空位</p>
                </div>
              </div>
            </div>

            <!-- 下半区：替补席 -->
            <div class="px-3 pt-4 pb-4">
              <div class="flex items-center justify-between px-1 mb-2">
                <p class="text-[11px] font-bold text-dark-300 uppercase tracking-wider">
                  {{ isStarting ? '候选球员' : '替补席' }} · {{ localBench.length }}
                </p>
                <p v-if="inSel.length" class="text-[10px] font-bold text-green-400">上场 {{ inSel.length }} 人</p>
              </div>
              <div v-if="localBench.length === 0" class="py-6 text-center">
                <p class="text-xs text-dark-600">替补席没有球员</p>
              </div>
              <div v-else class="grid grid-cols-3 sm:grid-cols-4 gap-2">
                <button v-for="p in localBench" :key="'b-'+p.id" @click="toggleIn(p)"
                  class="relative rounded-xl border p-2.5 flex flex-col items-center gap-1.5 transition-all active:scale-95"
                  :class="isIn(p.id)
                    ? 'border-green-500 bg-green-500/15 ring-2 ring-green-500/40'
                    : 'border-dark-800 bg-dark-850 hover:border-primary-500/40'">
                  <span v-if="isIn(p.id)" class="absolute top-1 right-1 text-[9px] font-black text-green-300 bg-green-500/30 border border-green-500/50 rounded px-1">上场</span>
                  <div class="w-[52px] h-[52px] rounded-full flex-shrink-0 flex items-center justify-center text-sm font-bold text-white overflow-hidden border-2"
                       :style="{ backgroundColor: team?.color || '#334155', borderColor: isIn(p.id) ? '#22c55e' : 'rgba(255,255,255,0.06)' }">
                    <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover" alt="">
                    <span v-else>{{ p.name?.charAt(0) || '?' }}</span>
                  </div>
                  <p class="text-[13px] font-black tabular-nums leading-none" :style="{ color: team?.color || '#94a3b8' }">#{{ p.jersey_no || '?' }}</p>
                  <p class="text-[11px] text-dark-200 font-medium truncate w-full text-center leading-tight">{{ p.name }}</p>
                </button>
              </div>
            </div>
          </div>

          <!-- 底部确认 -->
          <div class="px-4 py-3 border-t border-dark-700/50 flex-shrink-0">
            <p v-if="overLimit" class="text-[11px] text-red-400 font-bold mb-2 text-center">
              上场人数（{{ inSel.length }}）超过可换名额（{{ outSel.length + emptyCount }}）
            </p>
            <p v-else-if="!canConfirm" class="text-[11px] text-dark-500 mb-2 text-center">
              {{ isStarting
                ? '从下方选择球员加入首发'
                : (previewCount < 5 ? `场上 ${previewCount}/5 · 继续选择球员补满 5 人` : '选择要下场/上场的球员') }}
            </p>
            <p v-else class="text-[11px] text-dark-400 mb-2 text-center">
              <span class="text-red-400 font-bold">下 {{ outSel.length }}</span>
              ⇅
              <span class="text-green-400 font-bold">上 {{ inSel.length }}</span>
            </p>
            <!-- 赛前首发：单按钮一次提交 -->
            <button v-if="isStarting" @click="flush" :disabled="!canConfirm || busy"
              class="btn-primary w-full btn-lg whitespace-nowrap">
              {{ busy ? '执行中…' : confirmText }}
            </button>
            <!-- 赛中换人：替换暂存当前批次；完成=净差异真正提交 -->
            <div v-else class="flex gap-2">
              <button @click="applyBatch" :disabled="!canConfirm"
                class="btn-primary flex-1 btn-lg whitespace-nowrap">
                {{ confirmText }}
              </button>
              <button v-if="courtCount >= 5" @click="flush" :disabled="busy || canConfirm"
                class="px-5 rounded-xl font-bold whitespace-nowrap border transition-all active:scale-95
                       bg-green-500/20 text-green-300 border-green-500/50
                       disabled:opacity-40 disabled:pointer-events-none">
                {{ busy ? '提交中…' : '✓ 完成' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useGameStore } from '@/stores/game'

const props = defineProps({
  gameId: String,
  teamId: String,
  team: Object,
  gameType: String,
  gameStatus: String,
  courtPlayers: { type: Array, default: () => [] },
  benchPlayers: { type: Array, default: () => [] },
  pfMap: { type: Object, default: () => ({}) }
})
const emit = defineEmits(['close', 'done'])

const gameStore = useGameStore()
const outSel = ref([])
const inSel = ref([])
const busy = ref(false)

const isStarting = computed(() => props.gameStatus === 'pending')

// 全部成员 = 打开弹窗时的在场 + 替补
const members = computed(() => [
  ...props.courtPlayers.filter(Boolean),
  ...props.benchPlayers
])

// 本地暂存阵容：打开时快照，替换只改这里，点「完成」才提交服务器
const localCourt = ref(props.courtPlayers.map(p => p || null))

// 初始在场 id（用于完成时计算净差异）
const initialIds = new Set(props.courtPlayers.filter(Boolean).map(p => p.id))

const courtList = computed(() => localCourt.value.filter(Boolean))
const courtCount = computed(() => courtList.value.length)
const emptyCount = computed(() => 5 - courtCount.value)

// 赛前模式：标记未暂存，预览数 = 暂存数 - 待下 + 待上；赛中：完成按钮要求满 5
const previewCount = computed(() =>
  courtCount.value - outSel.value.length + inSel.value.length
)

// 替补 = 全部成员 - 本地在场
const localBench = computed(() => {
  const ids = new Set(courtList.value.map(p => p.id))
  return members.value.filter(m => !ids.has(m.id))
})

function isOut(id) { return outSel.value.includes(id) }
function isIn(id) { return inSel.value.includes(id) }

function toggleOut(p) {
  const i = outSel.value.indexOf(p.id)
  if (i >= 0) outSel.value.splice(i, 1)
  else outSel.value = [...outSel.value, p.id]
}

function toggleIn(p) {
  const i = inSel.value.indexOf(p.id)
  if (i >= 0) inSel.value.splice(i, 1)
  else inSel.value = [...inSel.value, p.id]
}

// 可换名额 = 已标记下场 + 现有空位
const overLimit = computed(() => inSel.value.length > outSel.value.length + emptyCount.value)
const canConfirm = computed(() =>
  !overLimit.value && (outSel.value.length > 0 || inSel.value.length > 0)
)

const confirmText = computed(() => {
  if (isStarting.value) {
    return `确认首发（${previewCount.value}/5）`
  }
  const parts = []
  if (outSel.value.length) parts.push(`下 ${outSel.value.length} 人`)
  if (inSel.value.length) parts.push(`上 ${inSel.value.length} 人`)
  return parts.length ? `替换：${parts.join(' · ')}` : '替换'
})

function pfChip(p) {
  if (props.gameType !== 'official') return ''
  const pf = props.pfMap[p.id] || 0
  if (pf >= 5) return 'bg-red-500/20 text-red-300 border border-red-500/50'
  if (pf === 4) return 'bg-orange-500/20 text-orange-300 border border-orange-500/50'
  if (pf === 3) return 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/50'
  return ''
}

// 替换：把当前标记应用到本地暂存阵容（不写服务器），可继续下一批
function applyBatch() {
  if (!canConfirm.value) return
  // 可用位置 = 现有空位 + 本次下场的位置
  const freedSlots = []
  localCourt.value.forEach((p, i) => { if (!p) freedSlots.push(i) })
  for (const id of outSel.value) {
    const idx = localCourt.value.findIndex(p => p?.id === id)
    if (idx >= 0) {
      localCourt.value[idx] = null
      freedSlots.push(idx)
    }
  }
  for (const id of inSel.value) {
    let slot = freedSlots.shift()
    if (slot === undefined) slot = localCourt.value.findIndex(p => !p)
    if (slot >= 0) localCourt.value[slot] = members.value.find(m => m.id === id) || null
  }
  outSel.value = []
  inSel.value = []
}

// 完成（或赛前确认）：净差异提交
// - 最终不在场的初始球员 → remove（关闭 stint）
// - 最终在场的新球员 → add（新 stint）
// - 两边都在场的球员（含本轮先下后上/位置变化）→ 不产生任何上下场记录
async function flush() {
  if (busy.value) return
  // 赛前单按钮：先把未暂存的标记应用进来
  if (outSel.value.length || inSel.value.length) {
    if (!canConfirm.value) return
    applyBatch()
  }
  busy.value = true
  try {
    const finalIds = new Set(courtList.value.map(p => p.id))
    const outs = [...initialIds].filter(id => !finalIds.has(id))
    const ins = [...finalIds].filter(id => !initialIds.has(id))

    // 槽位分配：留任球员保持原 slot；新上场球员按暂存顺序填剩余空位
    const slots = [null, null, null, null, null]
    props.courtPlayers.forEach((p, i) => {
      if (p && finalIds.has(p.id)) slots[i] = p.id
    })
    localCourt.value.forEach(p => {
      if (p && !initialIds.has(p.id)) {
        const e = slots.indexOf(null)
        if (e >= 0) slots[e] = p.id
      }
    })

    for (const id of outs) {
      await gameStore.substitutePlayer(props.gameId, props.teamId, id, null, 0)
    }
    for (const id of ins) {
      const idx = slots.indexOf(id)
      await gameStore.substitutePlayer(props.gameId, props.teamId, null, id, idx >= 0 ? idx + 1 : 1)
    }
    emit('done', { outs, ins })
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.modal-enter-active { transition: all 0.2s ease; }
.modal-leave-active { transition: all 0.15s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-from > div:last-child { transform: translateY(20px); }
</style>
