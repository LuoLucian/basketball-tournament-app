<template>
  <router-link :to="`/games/${game.id}`"
    class="glass-card-light p-4 flex items-center gap-3 group
           hover-glow-blue transition-all duration-300 animate-fade-in-up"
  >
    <!-- LIVE 标识 - 进行中比赛 -->
    <div v-if="game.status === 'active' || game.status === 'halftime'"
      class="flex-shrink-0 flex flex-col items-center gap-1">
      <div class="relative">
        <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-black
                     bg-red-500/20 text-red-400 border border-red-500/30 live-pulse">
          <span class="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>
          LIVE
        </span>
      </div>
      <span class="text-[10px] text-dark-500 font-medium">
        {{ game.status === 'halftime' ? '中场' : '进行中' }}
      </span>
    </div>

    <!-- 赛制标签 - 非进行中比赛 -->
    <div v-else
      class="w-10 h-10 rounded-xl flex items-center justify-center text-lg flex-shrink-0
             transition-all duration-300 group-hover:scale-110"
      :class="game.status === 'finished'
        ? 'bg-dark-700/50 border border-dark-600/50'
        : game.game_type === 'entertainment'
          ? 'bg-accent-500/15 border border-accent-500/30'
          : 'bg-primary-600/15 border border-primary-600/30'">
      {{ game.status === 'finished' ? '✅' : game.game_type === 'entertainment' ? '🎮' : '🏆' }}
    </div>

    <!-- 赛事信息 -->
    <div class="flex-1 min-w-0">
      <!-- 状态行 -->
      <div class="flex items-center gap-2 mb-1.5">
        <span v-if="game.status !== 'active' && game.status !== 'halftime'"
          class="badge text-xs" :class="statusClass">{{ statusText }}</span>
        <span class="text-[10px] text-dark-500 font-medium tracking-wide">{{ gameTypeText }}</span>
      </div>

      <!-- 双队对阵 -->
      <div v-if="game.home_team && game.away_team"
        class="flex items-center gap-2"
      >
        <!-- 主队 -->
        <div class="flex-1 min-w-0 text-right">
          <span class="font-semibold text-sm truncate block transition-colors duration-200"
            :class="{
              'text-white': isFinished && isHomeWin,
              'text-dark-300': isFinished && !isHomeWin,
              'text-dark-200': !isFinished
            }"
            :style="!isFinished || !isHomeWin ? { color: game.home_team.color } : {}">
            {{ game.home_team.short_name || game.home_team.name }}
          </span>
        </div>

        <!-- 比分 -->
        <div class="flex items-center gap-1.5 font-bold whitespace-nowrap px-2"
          :class="{
            'score-glow': game.status === 'active' || game.status === 'halftime'
          }">
          <span class="text-lg tabular-nums"
            :class="{
              'text-white text-xl': (game.status === 'active' || game.status === 'halftime'),
              'text-white': isFinished && isHomeWin,
              'text-dark-500': isFinished && !isHomeWin,
              'text-dark-300': !isFinished && game.status !== 'active' && game.status !== 'halftime'
            }">
            {{ game.home_score ?? '-' }}
          </span>
          <span class="text-dark-600 text-sm">:</span>
          <span class="text-lg tabular-nums"
            :class="{
              'text-white text-xl': (game.status === 'active' || game.status === 'halftime'),
              'text-white': isFinished && isAwayWin,
              'text-dark-500': isFinished && !isAwayWin,
              'text-dark-300': !isFinished && game.status !== 'active' && game.status !== 'halftime'
            }">
            {{ game.away_score ?? '-' }}
          </span>
        </div>

        <!-- 客队 -->
        <div class="flex-1 min-w-0">
          <span class="font-semibold text-sm truncate block transition-colors duration-200"
            :class="{
              'text-white': isFinished && isAwayWin,
              'text-dark-300': isFinished && !isAwayWin,
              'text-dark-200': !isFinished
            }"
            :style="!isFinished || !isAwayWin ? { color: game.away_team.color } : {}">
            {{ game.away_team.short_name || game.away_team.name }}
          </span>
        </div>
      </div>

      <!-- 无队伍信息 -->
      <div v-else class="text-sm font-medium text-dark-200 truncate">{{ game.title }}</div>
    </div>

    <!-- 箭头 -->
    <svg class="w-4 h-4 text-dark-600 group-hover:text-primary-400 flex-shrink-0 transition-all duration-300 group-hover:translate-x-1"
      fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
    </svg>
  </router-link>
</template>

<script setup>
import { computed } from 'vue'
import { GAME_TYPE_LABELS, GAME_STATUS_LABELS } from '@/utils/helpers'

const props = defineProps({
  game: { type: Object, required: true }
})

const statusInfo = computed(() => GAME_STATUS_LABELS[props.game.status] || { text: '未知', color: 'gray' })
const statusText = computed(() => statusInfo.value.text)
const gameTypeText = computed(() => props.game.game_type === 'entertainment' ? '娱乐制' : '正式制')
const statusClass = computed(() => ({
  'badge-green': statusInfo.value.color === 'green',
  'badge-orange': statusInfo.value.color === 'orange',
  'badge-blue': statusInfo.value.color === 'blue',
  'badge-red': statusInfo.value.color === 'red',
  'badge-gray': statusInfo.value.color === 'gray'
}))

const isFinished = computed(() => props.game.status === 'finished')
const isHomeWin = computed(() => isFinished.value && props.game.home_score > props.game.away_score)
const isAwayWin = computed(() => isFinished.value && props.game.away_score > props.game.home_score)
</script>
