<template>
  <router-link :to="`/games/${game.id}`"
    class="card card-body flex items-center gap-3 group
           hover:border-primary-600/30 hover:shadow-neon-blue transition-all duration-300"
  >
    <!-- 赛制标签 -->
    <div class="w-10 h-10 rounded-xl flex items-center justify-center text-lg flex-shrink-0"
      :class="game.game_type === 'entertainment' ? 'bg-accent-500/15 border border-accent-500/30' : 'bg-primary-600/15 border border-primary-600/30'">
      {{ game.game_type === 'entertainment' ? '🎮' : '🏆' }}
    </div>

    <!-- 赛事信息 -->
    <div class="flex-1 min-w-0">
      <div class="flex items-center gap-2 mb-1">
        <span class="badge text-xs" :class="statusClass">{{ statusText }}</span>
        <span class="text-xs text-dark-500">{{ gameTypeText }}</span>
        <span v-if="game.status === 'active'" class="w-1.5 h-1.5 rounded-full bg-success animate-pulse"></span>
      </div>
      <!-- 双队对阵 -->
      <div v-if="game.home_team && game.away_team"
        class="flex items-center gap-2"
      >
        <span class="font-semibold text-sm truncate flex-1" :style="{ color: game.home_team.color }">
          {{ game.home_team.short_name || game.home_team.name }}
        </span>
        <div class="flex items-center gap-1 text-white font-bold text-sm whitespace-nowrap">
          <span>{{ game.home_score }}</span>
          <span class="text-dark-600">:</span>
          <span>{{ game.away_score }}</span>
        </div>
        <span class="font-semibold text-sm truncate flex-1 text-right" :style="{ color: game.away_team.color }">
          {{ game.away_team.short_name || game.away_team.name }}
        </span>
      </div>
      <div v-else class="text-sm font-medium text-dark-200 truncate">{{ game.title }}</div>
    </div>

    <!-- 箭头 -->
    <svg class="w-4 h-4 text-dark-600 group-hover:text-primary-400 flex-shrink-0 transition-all duration-200 group-hover:translate-x-0.5"
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
</script>
