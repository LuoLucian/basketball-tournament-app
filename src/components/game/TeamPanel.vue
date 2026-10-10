<template>
  <div ref="panelRef" class="flex flex-col h-full bg-dark-900">
    <!-- 队名栏：双队模式（标准模式）紧凑布局，避免手机端半宽下文字重叠 -->
    <div class="px-2.5 py-2 border-b border-dark-700/50 flex items-center justify-between gap-1.5"
         :style="{ borderTop: `2px solid ${team?.color || '#3b82f6'}` }">
      <div class="flex items-center gap-1.5 min-w-0 flex-1">
        <h3 class="font-semibold text-xs md:text-sm truncate" :style="{ color: team?.color || '#94a3b8' }">
          {{ team?.name || '队伍' }}
        </h3>
        <!-- 队伍犯规（本节） -->
        <span class="text-[10px] px-1.5 py-0.5 rounded font-bold tabular-nums flex-shrink-0" :class="teamFoulBadgeClass">
          {{ recordOnly ? `犯规 ${teamFouls}` : `犯 ${teamFouls}` }}
        </span>
        <span v-if="teamFouls >= 5"
          class="text-[9px] px-1 py-0.5 rounded font-black bg-red-500/20 text-red-300 border border-red-500/50 flex-shrink-0 animate-pulse">
          加罚
        </span>
        <!-- 暂停次数（FIBA：上半场 2 次 / 下半场 3 次）——高亮为醒目操作按钮 -->
        <button v-if="showTimeouts" @click="$emit('timeout', { teamId, delta: 1 })"
          :disabled="!canRecord || timeoutsRemaining <= 0"
          class="text-[12px] px-2.5 py-1 rounded-lg font-black tabular-nums flex-shrink-0 transition-all active:scale-95"
          :class="timeoutBtnClass" title="请求暂停：点击后剩余次数 -1，并自动停表">
          ⏸ 暂停 {{ timeoutsRemaining }}
        </button>
        <button v-if="showTimeouts && timeoutsUsed > 0" @click="$emit('timeout', { teamId, delta: -1 })"
          :disabled="!canRecord"
          class="text-[12px] px-2 py-1 rounded-lg font-bold flex-shrink-0 bg-dark-800 text-dark-400
                 border border-dark-700/50 hover:text-white transition-all active:scale-95"
          title="撤销一次暂停">−</button>
      </div>
      <div class="flex items-center gap-1.5 flex-shrink-0">
        <!-- 换人 / 选择首发 -->
        <button v-if="canChangeLineup" @click="subModalOpen = true"
          class="px-2.5 py-1.5 rounded-lg text-[11px] font-black whitespace-nowrap
                 bg-primary-500 text-white border border-primary-300/60 ring-1 ring-primary-400/50
                 shadow-[0_0_12px_rgba(59,130,246,0.55)] hover:bg-primary-400 active:scale-95 transition-all">
          {{ subBtnText }}
        </button>
        <!-- 状态标签仅单队模式显示（双队模式顶部栏已有 LIVE 状态，节省宽度） -->
        <span v-if="recordOnly" class="text-[10px] px-2 py-0.5 rounded-full font-medium" :class="statusLabelColor">
          {{ statusLabel }}
        </span>
      </div>
    </div>

    <!-- 录队模式：左侧球员阵容 + 右侧固定录分区 -->
    <template v-if="recordOnly">
      <div class="flex-1 flex overflow-hidden" style="height: 100%;">
        <!-- 左侧：在场球员（换人统一走弹窗）- 独立滚动 -->
        <div class="w-2/5 md:w-2/5 flex flex-col border-r border-dark-700/30 overflow-y-auto player-list-scroll flex-shrink-0">
          <div class="px-2 pt-2.5 pb-3">
            <div class="flex items-center justify-between px-1 mb-1.5">
              <p class="text-[10px] md:text-[11px] text-dark-400 font-semibold uppercase tracking-wider">
                在场 · {{ courtPlayers.filter(p => p).length }}/5
              </p>
              <button v-if="canChangeLineup" @click="subModalOpen = true"
                class="text-[10px] font-black px-2 py-0.5 rounded-full bg-primary-500 text-white
                       shadow-[0_0_10px_rgba(59,130,246,0.5)] hover:bg-primary-400 active:scale-95 transition-all">
                {{ gameStatus === 'pending' ? '选首发' : '换人' }} →
              </button>
            </div>
            <div class="space-y-2">
              <div v-for="(slot, index) in courtPlayers" :key="'s-'+index"
                class="flex items-center gap-2 rounded-xl px-2 md:px-2.5 py-2 md:py-2.5 border transition-all cursor-pointer"
                :class="[
                  selectedPlayer?.id === slot?.id
                    ? 'bg-primary-600/15 border-primary-500/60'
                    : slot ? 'bg-dark-800 border-dark-700/50 hover:border-dark-600'
                    : 'bg-dark-850 border border-dashed border-dark-700/30',
                  slot ? foulRing(slot) : ''
                ]"
                @click="slot && selectPlayer(slot)">
                <div v-if="slot" class="flex-1 flex items-center gap-2 md:gap-2.5 min-w-0">
                  <!-- 数字快捷键标签 - 仅电脑端显示 -->
                  <div class="hidden lg:flex w-6 h-6 rounded flex-shrink-0 items-center justify-center text-[11px] font-bold"
                       :class="selectedPlayer?.id === slot?.id ? 'bg-primary-500 text-white' : 'bg-dark-700 text-dark-400'">
                    {{ index + 1 }}
                  </div>
                  <!-- 球员头像 -->
                  <div class="w-10 h-10 md:w-11 md:h-11 rounded-lg flex-shrink-0 flex items-center justify-center text-xs md:text-sm font-bold text-white overflow-hidden"
                       :style="{ backgroundColor: team?.color || '#334155' }">
                    <img v-if="slot.avatar_url" :src="slot.avatar_url" class="w-full h-full object-cover" alt="">
                    <span v-else>{{ slot.name?.charAt(0) || '?' }}</span>
                  </div>
                  <!-- 号码 + 名字 -->
                  <div class="flex-1 min-w-0">
                    <p class="text-[13px] md:text-[14px] text-white font-bold truncate leading-tight">
                      <span class="mr-1 tabular-nums" :style="{ color: team?.color || '#64748b' }">#{{ slot.jersey_no || '?' }}</span>{{ slot.name }}
                    </p>
                    <p v-if="slot.position" class="text-[9px] md:text-[10px] text-dark-500 mt-0.5">{{ slot.position }}</p>
                  </div>
                  <!-- 犯规预警 -->
                  <span v-if="foulChip(slot)" class="text-[9px] px-1.5 py-0.5 rounded font-black flex-shrink-0" :class="foulChip(slot)">
                    {{ playerPf(slot) }}犯
                  </span>
                </div>
                <!-- 空位：赛前点击直达选首发 -->
                <div v-else class="flex items-center gap-2 flex-1 cursor-pointer" @click.stop="openSubModalIfAllowed">
                  <div class="hidden lg:flex w-6 h-6 rounded flex-shrink-0 items-center justify-center text-[11px] font-bold bg-dark-800 text-dark-600">
                    {{ index + 1 }}
                  </div>
                  <span class="text-[11px] md:text-[12px]" :class="canChangeLineup && gameStatus === 'pending' ? 'text-primary-500' : 'text-dark-700'">
                    {{ canChangeLineup && gameStatus === 'pending' ? '＋ 点击选择首发' : '空位' }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 右侧：固定录分区域 -->
        <div class="flex-1 flex flex-col overflow-hidden" style="height: 100%;">
          <!-- 球员头像和信息 -->
          <div v-if="selectedPlayer" class="flex items-center justify-between px-3 pt-2 pb-1 flex-shrink-0">
            <div class="flex items-center gap-2.5">
              <div class="w-11 h-11 md:w-12 md:h-12 rounded-xl flex items-center justify-center text-base md:text-lg font-bold text-white overflow-hidden"
                   :style="{ backgroundColor: team?.color || '#334155' }">
                <img v-if="selectedPlayer.avatar_url" :src="selectedPlayer.avatar_url" class="w-full h-full object-cover" alt="">
                <span v-else>{{ selectedPlayer.name?.charAt(0) || '?' }}</span>
              </div>
              <div>
                <p class="text-[15px] md:text-[16px] text-white font-bold">
                  <span v-if="selectedPlayer.jersey_no" class="text-dark-400 mr-1">#{{ selectedPlayer.jersey_no }}</span>{{ selectedPlayer.name }}
                </p>
              </div>
            </div>
            <button @click="selectedPlayer = null"
              class="text-dark-500 hover:text-white p-1 rounded-md hover:bg-dark-700">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- 未选中球员时的提示 + 快捷键说明（仅电脑端显示） -->
          <div v-if="!selectedPlayer" class="flex-1 flex flex-col items-center justify-center px-4">
            <p class="text-dark-600 text-xs mb-3">← 请从左侧选择球员</p>
            <!-- 快捷键提示 - 仅电脑端显示 -->
            <div class="hidden md:flex items-center gap-1.5">
              <span class="text-[10px] text-dark-500">快捷键:</span>
              <div class="flex items-center gap-1">
                <kbd v-for="i in 5" :key="i"
                     class="min-w-[20px] h-5 px-1 rounded text-[10px] font-bold flex items-center justify-center"
                     :class="courtPlayers[i-1]
                       ? 'bg-primary-500/20 text-primary-400 border border-primary-500/30'
                       : 'bg-dark-800 text-dark-600 border border-dark-700'">
                  {{ i }}
                </kbd>
              </div>
            </div>
            <p class="hidden md:block text-[9px] text-dark-600 mt-1.5">按 1-5 快速选择上场球员</p>
          </div>

          <!-- 录分区（选中球员后固定展示） -->
          <div v-if="selectedPlayer" class="flex-1 flex flex-col px-3 pb-3 overflow-y-auto">
            <!-- 统计数据 -->
            <div v-if="liveStats" class="mb-2 px-1 py-1.5 rounded-lg bg-dark-800/60 flex-shrink-0">
              <div class="grid grid-cols-7 gap-1 mb-1">
                <div v-for="s in liveStatItems.slice(0, 7)" :key="s.key" class="text-center">
                  <p class="text-[9px] text-dark-500 leading-tight">{{ s.label }}</p>
                  <p class="text-[13px] font-bold leading-tight mt-0.5 stat-num"
                     :class="s.highlight ? 'text-primary-400' : 'text-dark-200'"
                     :data-key="s.key">{{ liveStats[s.key] || 0 }}</p>
                </div>
              </div>
              <div class="grid grid-cols-3 gap-1 pt-1 border-t border-dark-700/30">
                <div v-for="s in liveStatItems.slice(7)" :key="s.key" class="text-center">
                  <p class="text-[8px] text-dark-500 leading-tight">{{ s.label }}</p>
                  <p class="text-[12px] font-bold leading-tight text-dark-300">{{ shootingStr(s.key) }}</p>
                </div>
              </div>
            </div>

            <!-- 大按钮：得分 -->
            <div class="grid grid-cols-3 gap-2 mb-2 flex-shrink-0">
              <button v-for="btn in scoreButtons" :key="btn.type" @click="record(btn.type)"
                class="py-4 rounded-xl text-[15px] font-bold text-white transition-all active:scale-95 disabled:opacity-30 disabled:cursor-not-allowed shadow-lg"
                :class="btn.cls" :disabled="!canRecord">
                {{ btn.label }}
              </button>
            </div>
            <!-- 大按钮：数据 -->
            <div class="grid grid-cols-4 gap-2 mb-2 flex-shrink-0">
              <button v-for="btn in statButtons" :key="btn.type" @click="record(btn.type)"
                class="py-3.5 rounded-xl text-[13px] font-bold border border-dark-700 bg-dark-800 text-dark-200
                       hover:bg-dark-700 hover:text-white active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed shadow"
                :disabled="!canRecord">
                {{ btn.label }}
              </button>
            </div>
            <!-- 大按钮：不中 -->
            <div class="grid grid-cols-3 gap-2 mb-2 flex-shrink-0">
              <button v-for="btn in missButtons" :key="btn.type" @click="record(btn.type)"
                class="py-3.5 rounded-xl text-[13px] font-bold border border-dark-700/30 bg-dark-800/50 text-dark-400
                       hover:text-dark-200 hover:bg-dark-800 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed shadow"
                :disabled="!canRecord">
                {{ btn.label }}
              </button>
            </div>

            <!-- 撤销 -->
            <div v-if="lastAction" class="flex items-center justify-between px-1 pt-2 border-t border-dark-700/30 flex-shrink-0">
              <p class="text-[10px] text-dark-500 truncate">上一步：{{ lastAction.player_name }} {{ actionLabel(lastAction.actionType || lastAction.action_type || '') }}</p>
              <button @click="emit('undo', lastAction)"
                class="flex items-center gap-1 px-3 py-1.5 rounded-md text-[11px] font-bold text-white bg-gradient-to-r from-orange-500 to-red-500 active:scale-95 transition-all">
                ↩ 撤销
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- 标准模式（两边都显示）：球员列表独立滚动 + 录入区固定底部 -->
    <template v-else>
    <div class="flex-1 flex flex-col min-h-0 overflow-hidden">
    <!-- 在场球员（换人统一走弹窗）- 紧凑卡片 -->
    <div class="flex-1 overflow-y-auto min-h-0 player-list-scroll">
    <div class="px-2 pt-2 pb-2">
      <div class="flex items-center justify-between px-1 mb-1">
        <p class="text-[10px] text-dark-400 font-semibold uppercase tracking-wider">
          在场 · {{ courtPlayers.filter(p => p).length }}/5
        </p>
        <button v-if="canChangeLineup" @click="subModalOpen = true"
          class="text-[10px] font-bold text-primary-400 hover:text-primary-300">
          {{ gameStatus === 'pending' ? '选首发' : '换人' }} →
        </button>
      </div>
      <div class="space-y-1.5">
        <!-- 在场球员卡片 / 空位 -->
        <template v-for="(slot, index) in courtPlayers" :key="'s-'+index">
          <!-- 有球员 -->
          <div v-if="slot"
               class="flex items-center gap-1.5 rounded-lg px-1.5 py-1.5 border transition-all cursor-pointer select-none"
               :class="[
                 selectedPlayer?.id === slot.id
                   ? 'bg-primary-600/15 border-primary-500/60 shadow-[0_0_12px_rgba(59,130,246,0.15)]'
                   : 'bg-dark-800 border-dark-700/50 hover:border-dark-600',
                 foulRing(slot)
               ]"
               @click="selectPlayer(slot)">
            <!-- 头像 -->
            <div class="w-7 h-7 rounded-md flex-shrink-0 flex items-center justify-center text-[10px] font-bold text-white overflow-hidden"
                 :style="{ backgroundColor: team?.color || '#334155' }">
              <img v-if="slot.avatar_url" :src="slot.avatar_url" class="w-full h-full object-cover" alt="">
              <span v-else>{{ slot.name?.charAt(0) || '?' }}</span>
            </div>
            <!-- 号码 + 名字 -->
            <div class="flex-1 min-w-0">
              <p class="text-[11px] text-white font-bold truncate leading-tight">
                <span class="mr-1 tabular-nums" :style="{ color: team?.color || '#64748b' }">#{{ slot.jersey_no || '?' }}</span>{{ slot.name }}
              </p>
            </div>
            <!-- 选中和犯规预警 -->
            <div class="flex items-center gap-1 flex-shrink-0">
              <span v-if="foulChip(slot)" class="text-[8px] px-1 py-0.5 rounded font-black" :class="foulChip(slot)">
                {{ playerPf(slot) }}犯
              </span>
              <span v-if="selectedPlayer?.id === slot.id"
                    class="w-1.5 h-1.5 rounded-full bg-primary-400 animate-pulse"></span>
            </div>
          </div>
          <!-- 空位：赛前点击直达选首发 -->
          <div v-else
               class="flex items-center gap-1.5 rounded-lg px-1.5 py-1.5 border border-dashed cursor-pointer"
               :class="canChangeLineup && gameStatus === 'pending'
                 ? 'border-primary-500/40 bg-primary-600/5 hover:bg-primary-600/10'
                 : 'border-dark-700/30'"
               @click="openSubModalIfAllowed">
            <div class="w-7 h-7 rounded-md bg-dark-800 flex items-center justify-center">
              <span class="text-[10px] text-dark-600">{{ index + 1 }}</span>
            </div>
            <span class="text-[10px]" :class="canChangeLineup && gameStatus === 'pending' ? 'text-primary-500' : 'text-dark-700'">
              {{ canChangeLineup && gameStatus === 'pending' ? '＋ 点击选择首发' : '空位' }}
            </span>
          </div>
        </template>
      </div>
    </div>
    </div>

    <!-- 录入区：固定底部展示，点击球员卡片后完整可见，无需滚动 -->
    <Transition name="slide-up">
      <div v-if="selectedPlayer" class="flex-shrink-0 max-h-[62%] overflow-y-auto player-list-scroll
                                    px-2 py-1.5 border-t border-dark-700/50 bg-dark-850/95">
        <div class="flex items-center gap-1.5 mb-1.5">
          <div class="w-5 h-5 rounded-md flex items-center justify-center text-[9px] font-bold text-white overflow-hidden"
               :style="{ backgroundColor: team?.color || '#334155' }">
            <img v-if="selectedPlayer.avatar_url" :src="selectedPlayer.avatar_url" class="w-full h-full object-cover" alt="">
            <span v-else>{{ selectedPlayer.name?.charAt(0) }}</span>
          </div>
          <span class="text-[11px] text-white font-semibold flex-1 truncate">{{ selectedPlayer.name }}</span>
          <button @click="selectedPlayer = null"
                  class="text-dark-500 hover:text-white p-0.5 rounded-md hover:bg-dark-700 transition-all">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- 实时数据面板 -->
        <div v-if="liveStats" class="mb-1.5 px-1 py-1 rounded-lg bg-dark-800/60 space-y-0.5">
          <div class="grid grid-cols-7 gap-0.5">
            <div v-for="s in liveStatItems.slice(0, 7)" :key="s.key" class="text-center">
              <p class="text-[8px] text-dark-500 leading-tight">{{ s.label }}</p>
              <p class="text-[11px] font-bold leading-tight stat-num"
                 :class="s.highlight ? 'text-primary-400' : 'text-dark-200'"
                 :data-key="s.key">
                {{ liveStats[s.key] || 0 }}
              </p>
            </div>
          </div>
          <div v-if="liveStatItems.length > 7" class="grid grid-cols-3 gap-0.5 pt-0.5 border-t border-dark-700/30">
            <div v-for="s in liveStatItems.slice(7)" :key="s.key" class="text-center">
              <p class="text-[7px] text-dark-500 leading-tight">{{ s.label }}</p>
              <p class="text-[10px] font-bold leading-tight text-dark-300">
                {{ shootingStr(s.key) }}
              </p>
            </div>
          </div>
        </div>

        <!-- 得分行 -->
        <div class="grid grid-cols-3 gap-1 mb-1">
          <button v-for="btn in scoreButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-1.5 rounded-lg text-[11px] font-bold text-white transition-all active:scale-95 disabled:opacity-30 disabled:cursor-not-allowed"
                  :class="btn.cls" :disabled="!canRecord">
            {{ btn.label }}
          </button>
        </div>
        <!-- 数据行 -->
        <div class="grid grid-cols-4 gap-0.5">
          <button v-for="btn in statButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-1 rounded-lg text-[9px] font-medium border border-dark-700 bg-dark-800 text-dark-300
                         hover:bg-dark-700 hover:text-white active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                  :disabled="!canRecord">
            {{ btn.label }}
          </button>
        </div>
        <!-- 不中行 -->
        <div class="grid grid-cols-3 gap-1 mt-1">
          <button v-for="btn in missButtons" :key="btn.type" @click="record(btn.type)"
                  class="py-1 rounded-lg text-[9px] font-medium border border-dark-700/30 bg-dark-800/50 text-dark-500
                         hover:text-dark-300 hover:bg-dark-800 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                  :disabled="!canRecord">
            {{ btn.label }}
          </button>
        </div>

        <!-- 撤销按钮 + 上一步操作 -->
        <div v-if="lastAction" class="mt-1.5 flex items-center justify-between px-1 pt-1 border-t border-dark-700/30">
          <div class="text-left min-w-0">
            <p class="text-[8px] text-dark-600">上一步</p>
            <p class="text-[10px] text-orange-400 font-medium truncate max-w-[100px]">
              {{ lastAction.player_name }} {{ actionLabel(lastAction.actionType || lastAction.action_type || '') }}
            </p>
          </div>
          <button @click="emit('undo', lastAction)"
                  class="flex items-center gap-0.5 px-2 py-0.5 rounded-md text-[9px] font-bold text-white
                         bg-gradient-to-r from-orange-500 to-red-500
                         active:scale-95 transition-all duration-200 flex-shrink-0">
            <span class="text-[10px]">↩</span>
            <span>撤销</span>
          </button>
        </div>
      </div>
    </Transition>
    </div><!-- /标准模式：flex 列容器（球员列表 + 底部录入区） -->
    </template>

    <!-- 换人 / 选择首发弹窗 -->
    <SubstituteModal
      v-if="subModalOpen"
      :game-id="gameId"
      :team-id="teamId"
      :team="team"
      :game-type="gameType"
      :game-status="gameStatus"
      :court-players="courtPlayers"
      :bench-players="benchPlayers"
      :pf-map="mergedPfMap"
      @close="subModalOpen = false"
      @done="onSubDone"
    />
  </div>
</template>

<script setup>
import { ref, shallowRef, triggerRef, watch, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '@/utils/supabase'
import { useGameStore } from '@/stores/game'
import SubstituteModal from './SubstituteModal.vue'

const props = defineProps({
  team: Object,
  lineup: { type: Array, default: () => [] },
  gameId: String,
  teamId: String,
  gameType: String,
  gameStatus: String,
  teamFouls: { type: Number, default: 0 },
  timeoutsRemaining: { type: Number, default: 0 },
  timeoutsUsed: { type: Number, default: 0 },
  readonly: { type: Boolean, default: false },
  lineupReadonly: { type: Boolean, default: false },
  lastUndoAction: { type: Array, default: () => [] },
  recordOnly: { type: Boolean, default: false }
})

const emit = defineEmits(['record', 'lineupChange', 'undo', 'timeout'])
const gameStore = useGameStore()

const panelRef = ref(null)
const courtPlayers = shallowRef([])
const benchPlayers = shallowRef([])
const selectedPlayer = ref(null)
const liveStats = ref(null)
const prevStats = ref(null)
const allTeamMembers = ref([])
const membersLoaded = ref(false)

// 换人弹窗
const subModalOpen = ref(false)

// 个人犯规：服务器 pf 底数 + localStats 覆盖
const serverPfMap = ref({})

// 操作锁：防止快速重复点击导致重复上场/下场
const lineupChanging = ref(false)

// 键盘快捷键：1-5 选择上场球员（仅录队模式）
const keyboardEnabled = ref(false)
let keyboardHandler = null

function enableKeyboardShortcuts() {
  if (!props.recordOnly || keyboardHandler) return
  keyboardHandler = (e) => {
    // 忽略在输入框中的按键
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return
    const key = e.key
    if (key >= '1' && key <= '5') {
      const idx = parseInt(key, 10) - 1
      const player = courtPlayers.value[idx]
      if (player) {
        e.preventDefault()
        selectPlayer(player)
      }
    }
  }
  window.addEventListener('keydown', keyboardHandler)
  keyboardEnabled.value = true
}

function disableKeyboardShortcuts() {
  if (keyboardHandler) {
    window.removeEventListener('keydown', keyboardHandler)
    keyboardHandler = null
    keyboardEnabled.value = false
  }
}

onUnmounted(() => {
  disableKeyboardShortcuts()
})

// 监听录队模式变化，启用/禁用键盘快捷键
watch(() => props.recordOnly, (isRecordOnly) => {
  if (isRecordOnly) {
    enableKeyboardShortcuts()
  } else {
    disableKeyboardShortcuts()
  }
}, { immediate: true })

const canRecord = computed(() => props.gameStatus === 'active' && !props.readonly)
const canChangeLineup = computed(() =>
  props.gameStatus !== 'finished' && props.gameStatus !== 'cancelled' && !props.lineupReadonly
)

// ── 队伍犯规徽章（本节）──
const teamFoulBadgeClass = computed(() => {
  if (props.teamFouls >= 5) return 'bg-red-500/20 text-red-300 border border-red-500/50'
  if (props.teamFouls === 4) return 'bg-orange-500/20 text-orange-300 border border-orange-500/50 animate-pulse'
  return 'bg-dark-800 text-dark-300 border border-dark-700/50'
})

// ── 暂停次数（仅正式制按 FIBA 规则统计）──
const showTimeouts = computed(() => props.gameType === 'official')
const timeoutBtnClass = computed(() => {
  if (props.timeoutsRemaining <= 0) return 'bg-dark-800 text-dark-600 border border-dark-700/50 cursor-not-allowed'
  return 'bg-amber-500 text-black border border-amber-300 shadow-[0_0_14px_rgba(245,158,11,0.6)] hover:bg-amber-400 ring-1 ring-amber-400/60'
})

// ── 个人犯规（仅正式赛/锦标赛预警）──
const foulWarnEnabled = computed(() => props.gameType === 'official')
function playerPf(p) {
  if (!p) return 0
  const local = gameStore.localStats[p.id]
  if (local) return Math.max(0, local.pf || 0)
  return serverPfMap.value[p.id] || 0
}
function foulRing(p) {
  if (!foulWarnEnabled.value) return ''
  const pf = playerPf(p)
  if (pf >= 5) return '!border-red-500 shadow-[0_0_10px_rgba(239,68,68,0.35)]'
  if (pf === 4) return '!border-orange-500'
  if (pf === 3) return '!border-yellow-500/80'
  return ''
}
function foulChip(p) {
  if (!foulWarnEnabled.value) return ''
  const pf = playerPf(p)
  if (pf >= 5) return 'bg-red-500/20 text-red-300 border border-red-500/50'
  if (pf === 4) return 'bg-orange-500/20 text-orange-300 border border-orange-500/50'
  if (pf === 3) return 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/50'
  return ''
}
// 传给换人弹窗的犯规映射
const mergedPfMap = computed(() => {
  const map = { ...serverPfMap.value }
  for (const [pid, s] of Object.entries(gameStore.localStats)) {
    if (s && s.team_id === props.teamId) map[pid] = Math.max(0, s.pf || 0)
  }
  return map
})

async function loadTeamPf() {
  if (!props.gameId || !props.teamId) return
  const { data } = await supabase
    .from('game_stats')
    .select('player_id, pf')
    .eq('game_id', props.gameId)
    .eq('team_id', props.teamId)
  if (data) {
    const m = {}
    for (const r of data) m[r.player_id] = r.pf || 0
    serverPfMap.value = m
  }
}
const lastAction = computed(() => {
  const stack = props.lastUndoAction
  if (!stack || stack.length === 0) return null
  // 从后往前找属于本队的最后一条（用 == 宽松比较避免类型不匹配）
  for (let i = stack.length - 1; i >= 0; i--) {
    if (stack[i].teamId == props.teamId) return stack[i]
  }
  return null
})
const statusLabel = computed(() => {
  if (props.gameStatus === 'active') return '比赛中'
  if (props.gameStatus === 'finished') return '已结束'
  if (props.gameStatus === 'cancelled') return '已取消'
  return '未开始'
})
const statusLabelColor = computed(() => {
  if (props.gameStatus === 'active') return 'bg-green-500/15 text-green-400'
  return 'bg-dark-800 text-dark-500'
})
// 换人按钮文案：双队半宽模式缩短，单队模式保持完整
const subBtnText = computed(() => {
  if (props.gameStatus === 'pending') return props.recordOnly ? '📋 选择首发' : '📋 首发'
  return '🔄 换人'
})

// 同步阵容：根据最新的 lineup prop 更新 courtPlayers 和 benchPlayers
function syncLineup(lineup) {
  const courtIds = new Set(lineup.map(l => l.player_id))

  // 按 slot_no 填充到 5 个位置，空位留 null
  const slots = [null, null, null, null, null]
  for (const l of lineup) {
    const idx = (l.slot_no || 1) - 1
    if (idx >= 0 && idx < 5) {
      slots[idx] = {
        id: l.player_id,
        name: l.player?.name || '',
        jersey_no: l.player?.jersey_no || '',
        position: l.player?.position || '',
        avatar_url: l.player?.avatar_url || null,
        _lineupId: l.id
      }
    }
  }
  courtPlayers.value = slots

  benchPlayers.value = allTeamMembers.value.filter(m => !courtIds.has(m.id))
}

// 初始化：加载球队全部成员（只需一次），然后同步阵容
async function loadData() {
  if (!props.teamId || !props.gameId) return

  if (!membersLoaded.value) {
    const { data: teamPlayerData } = await supabase
      .from('team_players')
      .select('player_id, jersey_no, position, players!inner(id, name, position, avatar_url)')
      .eq('team_id', props.teamId)
      .eq('is_active', true)
      .order('jersey_no')

    if (teamPlayerData) {
      allTeamMembers.value = teamPlayerData.map(m => ({
        id: m.player_id,
        jersey_no: m.jersey_no,
        name: m.players?.name || '',
        position: m.position || m.players?.position || '',
        avatar_url: m.players?.avatar_url || null
      }))
    }
    membersLoaded.value = true
  }

  syncLineup(props.lineup)
  loadTeamPf()
}

// 监听 lineup prop 变化（来自 gameStore realtime 更新），每次都重新同步阵容
// 但 lineupChanging 期间跳过，避免乐观更新被覆盖导致闪烁
watch(() => props.lineup, (newLineup) => {
  if (lineupChanging.value) return
  if (membersLoaded.value) {
    // 成员已加载，直接同步阵容
    syncLineup(newLineup)
  } else {
    // 成员还未加载，走完整初始化
    loadData()
  }
}, { immediate: true, deep: true })

onMounted(() => {
  if (!membersLoaded.value) loadData()
})

function selectPlayer(player) {
  selectedPlayer.value = selectedPlayer.value?.id === player.id ? null : player
  if (selectedPlayer.value) {
    prevStats.value = null
    loadPlayerStats()
  } else {
    liveStats.value = null
    prevStats.value = null
  }
}

async function loadPlayerStats() {
  if (!selectedPlayer.value || !props.gameId) return
  // 优先使用本地追踪数据（每次录分都已同步更新，最及时）
  const local = gameStore.getPlayerLocalStats(selectedPlayer.value.id)
  if (local) {
    liveStats.value = local
    return
  }
  // 无本地数据时从服务器读取
  if (navigator.onLine) {
    try {
      const { data } = await supabase
        .from('game_stats')
        .select('pts, reb, ast, stl, blk, tov, pf, fg2m, fg2a, fg3m, fg3a, ftm, fta, min_played')
        .eq('game_id', props.gameId)
        .eq('player_id', selectedPlayer.value.id)
        .maybeSingle()
      if (data) {
        // 将服务器数据保存到本地，后续录分在此基础累加
        if (!gameStore.localStats[selectedPlayer.value.id]) {
          gameStore.localStats[selectedPlayer.value.id] = { ...data, team_id: props.teamId }
        }
        liveStats.value = data
      } else {
        liveStats.value = {}
      }
    } catch {
      liveStats.value = {}
    }
  } else {
    liveStats.value = {}
  }
}

// 每次录入后刷新选中球员的数据（由父组件调用）
async function refreshStats() {
  if (selectedPlayer.value) {
    await loadPlayerStats()
    triggerStatAnimation()
  }
  loadTeamPf()
}

// 检测数值变化，仅高亮变化的项
function triggerStatAnimation() {
  if (!prevStats.value || !liveStats.value) {
    prevStats.value = liveStats.value ? { ...liveStats.value } : null
    return
  }
  const changedKeys = liveStatItems
    .filter(s => (liveStats.value[s.key] || 0) !== (prevStats.value[s.key] || 0))
    .map(s => s.key)
  if (changedKeys.length) {
    requestAnimationFrame(() => {
      const els = panelRef.value?.querySelectorAll('.stat-num')
      els.forEach(el => {
        const key = el.dataset.key
        if (changedKeys.includes(key)) {
          el.classList.remove('flash')
          void el.offsetWidth
          el.classList.add('flash')
        }
      })
    })
  }
  prevStats.value = { ...liveStats.value }
}

const liveStatItems = [
  { key: 'pts', label: '得分', highlight: true },
  { key: 'reb', label: '篮板' },
  { key: 'ast', label: '助攻' },
  { key: 'stl', label: '抢断' },
  { key: 'blk', label: '盖帽' },
  { key: 'pf', label: '犯规' },
  { key: 'tov', label: '失误' },
  // 第二行：投篮命中率（专业格式：命中/出手）
  { key: 'fg2', label: '2分' },
  { key: 'fg3', label: '3分' },
  { key: 'ft', label: '罚篮' }
]

function shootingStr(key) {
  if (!liveStats.value) return '-'
  if (key === 'fg2') {
    const m = liveStats.value.fg2m || 0
    const a = liveStats.value.fg2a || 0
    return a > 0 ? `${m}/${a}` : (m > 0 ? `${m}/${a}` : '-')
  }
  if (key === 'fg3') {
    const m = liveStats.value.fg3m || 0
    const a = liveStats.value.fg3a || 0
    return a > 0 ? `${m}/${a}` : (m > 0 ? `${m}/${a}` : '-')
  }
  if (key === 'ft') {
    const m = liveStats.value.ftm || 0
    const a = liveStats.value.fta || 0
    return a > 0 ? `${m}/${a}` : (m > 0 ? `${m}/${a}` : '-')
  }
  return '-'
}

function record(actionType) {
  if (!selectedPlayer.value || !canRecord.value) return
  emit('record', {
    playerId: selectedPlayer.value.id,
    teamId: props.teamId,
    actionType,
    playerName: selectedPlayer.value.name
  })
}

// ── 换人弹窗 ──
function openSubModalIfAllowed() {
  if (canChangeLineup.value) subModalOpen.value = true
}

// 换人完成回调：outs/ins 为净差异（本地暂存的多批操作已在弹窗内合并）
// 服务器写入已由 substitutePlayer 完成，这里本地乐观同步阵容
function onSubDone({ outs, ins }) {
  subModalOpen.value = false
  lineupChanging.value = true
  for (const id of outs) {
    const idx = courtPlayers.value.findIndex(p => p?.id === id)
    if (idx >= 0) courtPlayers.value[idx] = null
  }
  for (const id of ins) {
    // substitutePlayer 内部 loadLineup 已触发 watcher 同步过阵容，
    // 已在场的球员直接跳过，避免乐观更新把同一球员重复插入空位
    if (courtPlayers.value.some(p => p?.id === id)) continue
    const emptyIdx = courtPlayers.value.findIndex(s => s === null)
    const member = allTeamMembers.value.find(m => m.id === id)
    if (emptyIdx >= 0 && member) courtPlayers.value[emptyIdx] = member
  }
  triggerRef(courtPlayers)
  const courtIds = new Set(courtPlayers.value.filter(Boolean).map(p => p.id))
  benchPlayers.value = allTeamMembers.value.filter(m => !courtIds.has(m.id))
  if (selectedPlayer.value && outs.includes(selectedPlayer.value.id)) selectedPlayer.value = null
  emit('lineupChange', courtPlayers.value)
  setTimeout(() => { lineupChanging.value = false }, 800)
}

defineExpose({ refreshStats })

const scoreButtons = [
  { type: 'pts_1', label: '罚球 +1', cls: 'bg-yellow-600/80' },
  { type: 'pts_2', label: '两分 +2', cls: 'bg-blue-600/80' },
  { type: 'pts_3', label: '三分 +3', cls: 'bg-purple-600/80' }
]

const statButtons = [
  { type: 'reb', label: '篮板+1' },
  { type: 'ast', label: '助攻+1' },
  { type: 'stl', label: '抢断+1' },
  { type: 'blk', label: '盖帽+1' },
  { type: 'tov', label: '失误+1' },
  { type: 'pf',  label: '犯规+1' }
]

const missButtons = [
  { type: 'fga_miss',  label: '两分不中' },
  { type: 'fg3a_miss', label: '三分不中' },
  { type: 'fta_miss',  label: '罚球不中' }
]

function actionLabel(type) {
  const map = {
    pts_1: '+1分', pts_2: '+2分', pts_3: '+3分',
    reb: '篮板+1', ast: '助攻+1', stl: '抢断+1', blk: '盖帽+1',
    tov: '失误+1', pf: '犯规+1', fga_miss: '两分不中', fg3a_miss: '三分不中', fta_miss: '罚球不中'
  }
  return map[type] || '已录入'
}
</script>

<style scoped>
.slide-up-enter-active, .slide-up-leave-active { transition: all 0.15s ease; }
.slide-up-enter-from, .slide-up-leave-to { opacity: 0; transform: translateY(4px); }

/* 数值变化闪烁动画（简洁） */
.stat-num {
  transition: color 0.2s ease;
}
.stat-num.flash {
  animation: statFlash 0.3s ease;
}
@keyframes statFlash {
  0% { color: #f97316; }
  100% { color: inherit; }
}

/* 球员列表滚动条样式 - 只在需要时显示 */
.player-list-scroll {
  scrollbar-width: thin;
  scrollbar-color: rgba(75, 85, 99, 0.5) transparent;
}
.player-list-scroll::-webkit-scrollbar {
  width: 4px;
}
.player-list-scroll::-webkit-scrollbar-track {
  background: transparent;
}
.player-list-scroll::-webkit-scrollbar-thumb {
  background-color: rgba(75, 85, 99, 0.5);
  border-radius: 2px;
}
.player-list-scroll::-webkit-scrollbar-thumb:hover {
  background-color: rgba(75, 85, 99, 0.8);
}
</style>
