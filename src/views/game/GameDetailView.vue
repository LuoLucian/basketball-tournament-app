<template>
  <div class="page-container">
    <!-- 返回 -->
    <div class="flex items-center gap-3 mb-5">
      <router-link to="/games" class="text-dark-500 hover:text-white transition-colors p-1">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </router-link>
      <div class="flex-1 min-w-0">
        <h1 class="text-lg font-bold text-white truncate">{{ game?.title || '赛事详情' }}</h1>
        <p v-if="game?.scheduled_at" class="text-xs text-dark-500 mt-0.5">{{ fmtDateTime(game.scheduled_at) }}{{ game?.venue ? ' · ' + game.venue : '' }}</p>
      </div>
      <router-link v-if="canRecord" :to="`/games/${gameId}/record`"
        class="btn-accent btn-sm flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
        </svg>
        进入录入
      </router-link>
      <button v-if="auth.isSuperAdmin"
        @click="showDeleteConfirm = true"
        class="btn-ghost btn-sm text-dark-500 hover:text-danger hover:bg-danger/10 hover:border-danger/20 flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
        </svg>
        删除赛事
      </button>
    </div>

    <div v-if="loading" class="space-y-3">
      <div class="skeleton h-56 rounded-2xl"></div>
      <div class="skeleton h-60 rounded-2xl"></div>
    </div>

    <div v-else-if="loadError" class="text-center py-20">
      <div class="text-4xl mb-4">⚠️</div>
      <p class="text-dark-400 mb-2">{{ loadError }}</p>
      <p class="text-dark-600 text-xs mb-6">赛事ID: {{ gameId }}</p>
      <router-link to="/games" class="btn-primary btn-sm">返回赛事列表</router-link>
    </div>

    <template v-else-if="game">
      <!-- ════════════════════════════════════════
           对抗比分板（动态视觉特效）
           ════════════════════════════════════════ -->
      <div class="vs-arena relative rounded-2xl overflow-hidden mb-5" style="min-height: 200px;">

        <!-- 队伍对抗背景色块 -->
        <div class="absolute inset-0 pointer-events-none flex">
          <div class="w-1/2 h-full transition-colors duration-500"
            :style="{ backgroundColor: homeColor + '12' }"></div>
          <div class="w-1/2 h-full transition-colors duration-500"
            :style="{ backgroundColor: awayColor + '12' }"></div>
        </div>

        <!-- 队伍光晕 -->
        <div class="absolute inset-0 pointer-events-none">
          <div class="absolute top-0 left-0 w-1/2 h-full"
            :style="{ background: `radial-gradient(ellipse at 20% 50%, ${homeColor}22 0%, transparent 70%)` }"></div>
          <div class="absolute top-0 right-0 w-1/2 h-full"
            :style="{ background: `radial-gradient(ellipse at 80% 50%, ${awayColor}22 0%, transparent 70%)` }"></div>
        </div>

        <!-- 底部渐变边框 -->
        <div class="absolute inset-0 rounded-2xl border border-dark-700/50
                    bg-gradient-to-br from-dark-800 via-dark-850 to-dark-900"></div>

        <!-- 顶部彩色分隔条 -->
        <div class="absolute top-0 left-0 right-0 h-0.5 flex overflow-hidden rounded-t-2xl">
          <div class="flex-1 h-full transition-all duration-500" :style="{ backgroundColor: homeColor }"></div>
          <div class="w-px bg-dark-700"></div>
          <div class="flex-1 h-full transition-all duration-500" :style="{ backgroundColor: awayColor }"></div>
        </div>

        <!-- 内容 -->
        <div class="relative z-10 p-6 pt-5">
          <!-- 状态行 -->
          <div class="flex items-center justify-between mb-5">
            <span class="badge"
              :class="game.status === 'active' ? 'badge-green animate-pulse' : game.status === 'finished' ? 'badge-blue' : 'badge-gray'">
              {{ GAME_STATUS_LABELS[game.status]?.text }}
            </span>
            <span class="text-xs text-dark-500 font-medium">
              {{ game.game_type === 'entertainment' ? `目标 ${game.target_score} 分` : `第 ${game.current_quarter} 节` }}
            </span>
          </div>

          <!-- 比分区域 -->
          <div class="flex items-center justify-between">

            <!-- 主队 -->
            <div class="flex-1 text-center">
              <!-- 队名 -->
              <p class="text-sm font-bold mb-3 truncate px-2 tracking-wide"
                :style="{ color: homeColor }">
                {{ game.home_team?.name || '主队' }}
              </p>
              <!-- 比分 -->
              <div class="relative inline-block">
                <p class="text-7xl font-black tabular-nums leading-none"
                  :style="{ color: homeColor, textShadow: `0 0 40px ${homeColor}66, 0 0 80px ${homeColor}22` }">
                  {{ game.home_score }}
                </p>
              </div>
            </div>

            <!-- VS 中间 -->
            <div class="flex flex-col items-center px-4 flex-shrink-0">
              <!-- 动态 VS -->
              <div class="vs-clash relative">
                <!-- 左侧冲击线 -->
                <div class="clash-line-left absolute right-full top-1/2 -translate-y-1/2 flex items-center gap-0.5 mr-1">
                  <div v-for="i in 3" :key="i" class="h-0.5 rounded-full"
                    :style="{ width: `${(4-i)*4}px`, backgroundColor: homeColor, opacity: 1 - i * 0.25 }"></div>
                </div>
                <!-- 右侧冲击线 -->
                <div class="clash-line-right absolute left-full top-1/2 -translate-y-1/2 flex items-center gap-0.5 flex-row-reverse ml-1">
                  <div v-for="i in 3" :key="i" class="h-0.5 rounded-full"
                    :style="{ width: `${(4-i)*4}px`, backgroundColor: awayColor, opacity: 1 - i * 0.25 }"></div>
                </div>
                <!-- VS 文字 -->
                <div class="vs-text text-2xl font-black tracking-tight select-none px-3 py-1"
                  style="background: linear-gradient(135deg, #3b82f6, #f97316); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;">
                  VS
                </div>
              </div>
              <!-- 比分差 -->
              <div v-if="game.home_score !== game.away_score" class="mt-2 text-xs text-dark-500">
                {{ Math.abs(game.home_score - game.away_score) }} 分差
              </div>
              <div v-else class="mt-2 text-xs text-warning font-bold">平局</div>
            </div>

            <!-- 客队 -->
            <div class="flex-1 text-center">
              <p class="text-sm font-bold mb-3 truncate px-2 tracking-wide"
                :style="{ color: awayColor }">
                {{ game.away_team?.name || '客队' }}
              </p>
              <div class="relative inline-block">
                <p class="text-7xl font-black tabular-nums leading-none"
                  :style="{ color: awayColor, textShadow: `0 0 40px ${awayColor}66, 0 0 80px ${awayColor}22` }">
                  {{ game.away_score }}
                </p>
              </div>
            </div>

          </div><!-- end 比分区域 -->
        </div><!-- end 内容 -->
      </div><!-- end 对抗比分板 -->

      <!-- ════════════════════════════════════════
           MVP 展示（比赛结束后）
           ════════════════════════════════════════ -->
      <div v-if="mvpWinner && game.status === 'finished'"
        class="mvp-banner relative rounded-2xl p-5 mb-5 overflow-hidden">
        <!-- 多层光效背景 -->
        <div class="absolute inset-0 bg-gradient-to-r from-yellow-900/30 via-orange-900/20 to-dark-850"></div>
        <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_left,rgba(234,179,8,0.15),transparent_60%)]"></div>
        <!-- 顶部金色边框 -->
        <div class="absolute top-0 left-0 right-0 h-0.5 bg-gradient-to-r from-yellow-500 via-orange-400 to-transparent rounded-t-2xl"></div>
        <!-- 漂浮粒子 -->
        <div class="absolute top-2 right-6 w-1.5 h-1.5 rounded-full bg-yellow-400/60 mvp-particle-1"></div>
        <div class="absolute top-5 right-12 w-1 h-1 rounded-full bg-orange-400/40 mvp-particle-2"></div>
        <div class="absolute bottom-3 right-8 w-1 h-1 rounded-full bg-yellow-300/50 mvp-particle-3"></div>

        <div class="relative z-10 flex items-center gap-4">
          <!-- 奖杯 -->
          <div class="relative flex-shrink-0">
            <div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-yellow-400 to-orange-500
                        flex items-center justify-center text-3xl shadow-neon-orange">
              🏆
            </div>
            <div class="absolute -inset-1 rounded-2xl bg-gradient-to-br from-yellow-400/20 to-orange-500/20 blur-md -z-10"></div>
          </div>
          <!-- 信息 -->
          <div class="flex-1 min-w-0">
            <p class="text-xs text-yellow-500/80 font-bold uppercase tracking-widest mb-0.5">⭐ 本场 MVP</p>
            <p class="font-black text-white text-xl leading-tight">{{ mvpWinner.player?.name }}</p>
            <p class="text-xs text-dark-400 mt-1">
              综合评分
              <span class="text-yellow-400 font-black text-base ml-1">{{ mvpWinner.mvp_score }}</span>
            </p>
          </div>
          <!-- MVP 数据摘要 -->
          <div v-if="mvpStats" class="hidden sm:flex flex-col gap-1 flex-shrink-0 text-right">
            <div class="text-xs text-dark-500">
              <span class="text-white font-bold text-base">{{ mvpStats.pts }}</span> 分
            </div>
            <div class="text-xs text-dark-500">
              <span class="text-dark-300 font-bold">{{ mvpStats.reb }}</span> 板
              <span class="text-dark-300 font-bold ml-2">{{ mvpStats.ast }}</span> 助
            </div>
          </div>
        </div>
      </div>

      <!-- ════════════════════════════════════════
           球员数据统计表
           ════════════════════════════════════════ -->
      <div class="card mb-4">
        <div class="card-header flex items-center justify-between">
          <h2 class="font-semibold text-white">球员数据</h2>
          <!-- 队伍切换 -->
          <div class="flex gap-1 bg-dark-800 rounded-lg p-0.5">
            <button v-for="opt in teamFilterOptions" :key="opt.value"
              @click="teamFilter = opt.value"
              class="px-2.5 py-1 rounded-md text-xs font-medium transition-all duration-200"
              :class="teamFilter === opt.value
                ? 'bg-primary-600/20 text-primary-300 shadow-sm'
                : 'text-dark-500 hover:text-dark-300'">
              {{ opt.label }}
            </button>
          </div>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full" style="table-layout: fixed;">
            <thead>
              <tr class="border-b border-dark-700/50">
                <th class="text-left px-4 py-2 text-xs font-semibold text-dark-500 whitespace-nowrap">球员</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">#</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">得分</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">篮板</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">助攻</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">抢断</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">盖帽</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">犯规</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">2分%</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">3分%</th>
                <th class="px-2 py-2 text-center text-xs font-semibold text-dark-500 whitespace-nowrap">失误</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-dark-700/30">

              <!-- ── 主队区块 ── -->
              <template v-if="teamFilter !== 'away'">
                <!-- 主队标题行（仅全队模式显示） -->
                <tr v-if="teamFilter === 'all' && getTeamStats('home').length"
                  class="bg-dark-800/50">
                  <td colspan="11" class="px-4 py-1.5">
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: homeColor }"></div>
                      <span class="text-[11px] font-bold" :style="{ color: homeColor }">{{ game.home_team?.name }}</span>
                      <span class="text-[10px] text-dark-600">主队 · {{ game.home_score }} 分</span>
                    </div>
                  </td>
                </tr>
                <!-- 主队球员行 -->
                <tr v-for="stat in getTeamStats('home')" :key="stat.player_id"
                  class="hover:bg-dark-800/40 transition-colors text-xs">
                  <td class="px-4 py-2">
                    <div class="flex items-center gap-2">
                      <span v-if="isMvpRow(stat)" class="text-sm leading-none flex-shrink-0" title="本场MVP">👑</span>
                      <div class="w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold flex-shrink-0"
                        :style="{ backgroundColor: homeColor + '33', color: homeColor }">
                        {{ getInitials(stat.player?.name) }}
                      </div>
                      <span class="font-medium whitespace-nowrap"
                        :class="isMvpRow(stat) ? 'text-yellow-200' : 'text-white'">
                        {{ stat.player?.name }}
                      </span>
                    </div>
                  </td>
                  <td class="px-2 py-2 text-center font-bold" :style="{ color: homeColor }">
                    {{ stat.player?.jersey_no || '-' }}
                  </td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('pts', stat, 'home') ? 'top-value' : 'text-dark-400'">{{ stat.pts }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('reb', stat, 'home') ? 'top-value' : 'text-dark-400'">{{ stat.reb }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('ast', stat, 'home') ? 'top-value' : 'text-dark-400'">{{ stat.ast }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('stl', stat, 'home') ? 'top-value' : 'text-dark-400'">{{ stat.stl }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('blk', stat, 'home') ? 'top-value' : 'text-dark-400'">{{ stat.blk }}</td>
                  <td class="px-2 py-2 text-center" :class="stat.pf >= 5 ? 'text-danger font-bold' : stat.pf >= 3 ? 'text-warning font-semibold' : 'text-dark-500'">{{ stat.pf }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('fg_pct', stat, 'home') ? 'top-value' : 'text-dark-500'">{{ fgPct(stat) }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('fg3_pct', stat, 'home') ? 'top-value' : 'text-dark-500'">{{ fg3Pct(stat) }}</td>
                  <td class="px-2 py-2 text-center text-dark-500">{{ stat.tov }}</td>
                </tr>
              </template>

              <!-- ── 客队区块 ── -->
              <template v-if="teamFilter !== 'home'">
                <!-- 客队标题行（仅全队模式显示） -->
                <tr v-if="teamFilter === 'all' && getTeamStats('away').length"
                  class="bg-dark-800/50">
                  <td colspan="11" class="px-4 py-1.5">
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: awayColor }"></div>
                      <span class="text-[11px] font-bold" :style="{ color: awayColor }">{{ game.away_team?.name }}</span>
                      <span class="text-[10px] text-dark-600">客队 · {{ game.away_score }} 分</span>
                    </div>
                  </td>
                </tr>
                <!-- 客队球员行 -->
                <tr v-for="stat in getTeamStats('away')" :key="stat.player_id"
                  class="hover:bg-dark-800/40 transition-colors text-xs">
                  <td class="px-4 py-2">
                    <div class="flex items-center gap-2">
                      <span v-if="isMvpRow(stat)" class="text-sm leading-none flex-shrink-0" title="本场MVP">👑</span>
                      <div class="w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold flex-shrink-0"
                        :style="{ backgroundColor: awayColor + '33', color: awayColor }">
                        {{ getInitials(stat.player?.name) }}
                      </div>
                      <span class="font-medium whitespace-nowrap"
                        :class="isMvpRow(stat) ? 'text-yellow-200' : 'text-white'">
                        {{ stat.player?.name }}
                      </span>
                    </div>
                  </td>
                  <td class="px-2 py-2 text-center font-bold" :style="{ color: awayColor }">
                    {{ stat.player?.jersey_no || '-' }}
                  </td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('pts', stat, 'away') ? 'top-value' : 'text-dark-400'">{{ stat.pts }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('reb', stat, 'away') ? 'top-value' : 'text-dark-400'">{{ stat.reb }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('ast', stat, 'away') ? 'top-value' : 'text-dark-400'">{{ stat.ast }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('stl', stat, 'away') ? 'top-value' : 'text-dark-400'">{{ stat.stl }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('blk', stat, 'away') ? 'top-value' : 'text-dark-400'">{{ stat.blk }}</td>
                  <td class="px-2 py-2 text-center" :class="stat.pf >= 5 ? 'text-danger font-bold' : stat.pf >= 3 ? 'text-warning font-semibold' : 'text-dark-500'">{{ stat.pf }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('fg_pct', stat, 'away') ? 'top-value' : 'text-dark-500'">{{ fgPct(stat) }}</td>
                  <td class="px-2 py-2 text-center" :class="isTopInColForTeam('fg3_pct', stat, 'away') ? 'top-value' : 'text-dark-500'">{{ fg3Pct(stat) }}</td>
                  <td class="px-2 py-2 text-center text-dark-500">{{ stat.tov }}</td>
                </tr>
              </template>

              <!-- 空状态 -->
              <tr v-if="teamFilter === 'all' && getTeamStats('home').length === 0 && getTeamStats('away').length === 0">
                <td colspan="11" class="text-center py-8 text-dark-500 text-xs">暂无数据</td>
              </tr>
              <tr v-if="teamFilter === 'home' && getTeamStats('home').length === 0">
                <td colspan="11" class="text-center py-6 text-dark-500 text-xs">暂无主队数据</td>
              </tr>
              <tr v-if="teamFilter === 'away' && getTeamStats('away').length === 0">
                <td colspan="11" class="text-center py-6 text-dark-500 text-xs">暂无客队数据</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- 图例 -->
        <div class="px-4 py-2 border-t border-dark-700/30 flex flex-wrap gap-3 text-[10px] text-dark-600">
          <span><span class="text-orange-400 font-bold">高亮</span> 队内最高</span>
          <span><span class="text-warning">3+</span> / <span class="text-danger">5+</span> 犯规预警</span>
          <span><span class="text-dark-400">-</span> 无出手记录</span>
        </div>
      </div>

    </template>

    <!-- 删除确认弹窗 -->
    <Transition name="fade">
      <div v-if="showDeleteConfirm" class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="showDeleteConfirm = false">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>
        <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass animate-scale-in">
          <div class="text-center">
            <div class="w-14 h-14 rounded-full bg-danger/10 border border-danger/20 flex items-center justify-center mx-auto mb-4">
              <svg class="w-7 h-7 text-danger" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-white mb-2">删除赛事</h3>
            <p class="text-sm text-dark-400 mb-1">确定要删除 <span class="text-white font-medium">"{{ game?.title }}"</span> 吗？</p>
            <p class="text-xs text-dark-500 mb-5">所有比赛数据、统计、MVP记录将被永久删除</p>
            <div class="flex gap-3">
              <button @click="showDeleteConfirm = false" class="btn-secondary flex-1">取消</button>
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
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { GAME_STATUS_LABELS, getInitials, fmtDateTime } from '@/utils/helpers'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const gameId = route.params.id

const game = ref(null)
const stats = ref([])
const mvp = ref([])
const loading = ref(true)
const loadError = ref('')

// 队伍颜色（带默认值）
const homeColor = computed(() => game.value?.home_team?.color || '#3b82f6')
const awayColor = computed(() => game.value?.away_team?.color || '#f97316')

const canRecord = computed(() => {
  if (!game.value) return false
  if (['finished', 'cancelled'].includes(game.value.status)) return false
  return auth.isAdmin || auth.role === 'recorder'
})

// ── 队伍筛选 ──
const teamFilter = ref('all')
const teamFilterOptions = [
  { label: '全队', value: 'all' },
  { label: '主队', value: 'home' },
  { label: '客队', value: 'away' },
]

function teamColor(side) {
  return side === 'home' ? homeColor.value : awayColor.value
}

// 按队伍过滤
function getTeamStats(side) {
  const teamId = side === 'home' ? game.value?.home_team_id : game.value?.away_team_id
  return stats.value.filter(s => s.team_id === teamId)
}

const mvpWinner = computed(() => mvp.value.find(m => m.is_winner))

// MVP 对应的数据行
const mvpStats = computed(() => {
  if (!mvpWinner.value) return null
  return stats.value.find(s => s.player_id === mvpWinner.value.player_id) || null
})

// ── 命中率计算 ──
function fgPct(stat) {
  // 2分出手 = fga（两分不中）+ fgm（两分命中），但 fga 字段在录入时只记录不中次数
  // 实际出手 = fgm + fga_miss（不中次数，存在 fga 字段）
  const made = (stat.fgm || 0)
  const attempted = made + (stat.fga || 0)
  if (attempted === 0) return '-'
  return (made / attempted * 100).toFixed(0) + '%'
}

function fg3Pct(stat) {
  const made = (stat.fg3m || 0)
  const attempted = made + (stat.fg3a || 0)
  if (attempted === 0) return '-'
  return (made / attempted * 100).toFixed(0) + '%'
}

// 用于比较的数值（'-' 视为 -1）
function fgPctVal(stat) {
  const made = (stat.fgm || 0)
  const attempted = made + (stat.fga || 0)
  if (attempted === 0) return -1
  return made / attempted
}
function fg3PctVal(stat) {
  const made = (stat.fg3m || 0)
  const attempted = made + (stat.fg3a || 0)
  if (attempted === 0) return -1
  return made / attempted
}

// ── 各列最大值计算（按队伍分别计算）──
const homeTopValues = computed(() => calcTopValues('home'))
const awayTopValues = computed(() => calcTopValues('away'))

function calcTopValues(side) {
  const d = getTeamStats(side)
  if (!d.length) return {}
  return {
    pts:     Math.max(...d.map(s => s.pts || 0)),
    reb:     Math.max(...d.map(s => s.reb || 0)),
    ast:     Math.max(...d.map(s => s.ast || 0)),
    stl:     Math.max(...d.map(s => s.stl || 0)),
    blk:     Math.max(...d.map(s => s.blk || 0)),
    fg_pct:  Math.max(...d.map(s => fgPctVal(s))),
    fg3_pct: Math.max(...d.map(s => fg3PctVal(s))),
  }
}

function isTopInColForTeam(col, stat, side) {
  const tv = side === 'home' ? homeTopValues.value : awayTopValues.value
  if (!tv[col] || tv[col] <= 0) return false
  const getVal = {
    pts:     s => s.pts || 0,
    reb:     s => s.reb || 0,
    ast:     s => s.ast || 0,
    stl:     s => s.stl || 0,
    blk:     s => s.blk || 0,
    fg_pct:  s => fgPctVal(s),
    fg3_pct: s => fg3PctVal(s),
  }
  return (getVal[col]?.(stat) || 0) === tv[col]
}

function isMvpRow(stat) {
  return mvpWinner.value && stat.player_id === mvpWinner.value.player_id && game.value?.status === 'finished'
}

// 删除功能
const showDeleteConfirm = ref(false)
const deleting = ref(false)

async function confirmDelete() {
  deleting.value = true
  try {
    const { error } = await supabase.rpc('delete_game', {
      p_game_id: gameId,
      p_user_id: auth.user?.id || null
    })
    if (error) throw error
    router.push('/games')
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  try {
    const { data: gameData, error: gErr } = await supabase
      .from('games')
      .select('*, home_team:home_team_id(*), away_team:away_team_id(*)')
      .eq('id', gameId)
      .single()
    if (gErr) {
      loadError.value = '赛事查询失败：' + gErr.message + ' (code: ' + gErr.code + ')'
      loading.value = false
      return
    }
    if (!gameData) {
      loadError.value = '找不到该赛事，ID: ' + gameId
      loading.value = false
      return
    }
    game.value = gameData
    loading.value = false

    // 并行获取：两队所有球员 + 本场统计数据 + MVP
    const [tpRes, statsRes, mvpQuery] = await Promise.allSettled([
      supabase.from('team_players')
        .select(`team_id, player_id, jersey_no, player:player_id(id, name)`)
        .in('team_id', [gameData.home_team_id, gameData.away_team_id])
        .eq('is_active', true),
      supabase.from('game_stats')
        .select(`*, player:player_id(id, name)`)
        .eq('game_id', gameId),
      supabase.from('game_mvp')
        .select('*, player:player_id(id, name)')
        .eq('game_id', gameId)
    ])

    // 统计数据的 map，方便按 player_id 查找
    const statsMap = {}
    if (statsRes.status === 'fulfilled' && statsRes.value.data) {
      for (const s of statsRes.value.data) {
        statsMap[s.player_id] = s
      }
    }

    // 合并：所有报名球员都要显示，有数据就用，没有就填 0
    const statFields = ['pts', 'reb', 'oreb', 'dreb', 'ast', 'stl', 'blk', 'tov', 'pf', 'fgm', 'fga', 'fg3m', 'fg3a', 'ftm', 'fta', 'min_played']
    const merged = []
    if (tpRes.status === 'fulfilled' && tpRes.value.data) {
      const homeColorVal = gameData.home_team?.color || '#3b82f6'
      const awayColorVal = gameData.away_team?.color || '#f97316'
      const homeName = gameData.home_team?.name || '主队'
      const awayName = gameData.away_team?.name || '客队'

      for (const tp of tpRes.value.data) {
        const existing = statsMap[tp.player_id]
        if (existing) {
          // 有统计数据：合并球衣号码，同时把 NULL 字段默认为 0
          const normalized = { ...existing }
          for (const f of statFields) {
            if (normalized[f] == null) normalized[f] = 0
          }
          normalized.player = {
            ...existing.player,
            jersey_no: tp.jersey_no
          }
          // 确保 team_id 正确（可能来自 game_stats，可能为 null）
          normalized.team_id = normalized.team_id || tp.team_id
          merged.push(normalized)
        } else {
          // 无统计数据：创建全 0 的记录
          const isHome = tp.team_id === gameData.home_team_id
          merged.push({
            game_id:   gameId,
            player_id: tp.player_id,
            team_id:   tp.team_id,
            pts: 0, reb: 0, ast: 0, stl: 0, blk: 0,
            pf: 0, tov: 0, fgm: 0, fga: 0, fg3m: 0, fg3a: 0,
            player: {
              id:        tp.player_id,
              name:      tp.player?.name || '未知',
              jersey_no: tp.jersey_no
            },
            team: {
              id:    tp.team_id,
              name:  isHome ? homeName : awayName,
              color: isHome ? homeColorVal : awayColorVal
            }
          })
        }
      }
    }

    // 排序：主队在前 → 按球衣号 → 按名字
    const homeId = gameData.home_team_id
    merged.sort((a, b) => {
      const aHome = a.team_id === homeId
      const bHome = b.team_id === homeId
      if (aHome && !bHome) return -1
      if (!aHome && bHome) return 1
      const aNo = parseInt(a.player?.jersey_no) || 9999
      const bNo = parseInt(b.player?.jersey_no) || 9999
      if (aNo !== bNo) return aNo - bNo
      return (a.player?.name || '').localeCompare(b.player?.name || '', 'zh-CN')
    })

    stats.value = merged

    if (mvpQuery.status === 'fulfilled' && mvpQuery.value.data) {
      mvp.value = mvpQuery.value.data
    }
  } catch (e) {
    console.error('[GameDetail] 加载异常:', e)
    loadError.value = '加载异常：' + (e.message || '未知错误')
    loading.value = false
  }
})
</script>

<style scoped>
/* ── 比分板 ── */
.vs-arena {
  background: linear-gradient(135deg, #0f1117 0%, #1a1f2e 50%, #0f1117 100%);
}

/* VS 文字抖动 */
.vs-clash {
  animation: vsShake 2s ease-in-out infinite;
}
@keyframes vsShake {
  0%, 100% { transform: translateY(0) scale(1); }
  25% { transform: translateY(-2px) scale(1.05); }
  75% { transform: translateY(2px) scale(0.98); }
}

/* ── MVP 区域 ── */
.mvp-banner {
  border: 1px solid rgba(234, 179, 8, 0.2);
}

.mvp-particle-1 {
  animation: particleFloat 3s ease-in-out infinite;
}
.mvp-particle-2 {
  animation: particleFloat 2.5s ease-in-out infinite 0.7s;
}
.mvp-particle-3 {
  animation: particleFloat 3.5s ease-in-out infinite 1.2s;
}
@keyframes particleFloat {
  0%, 100% { transform: translateY(0) scale(1); opacity: 0.6; }
  50% { transform: translateY(-8px) scale(1.3); opacity: 1; }
}

/* ── 数据表最高值强化样式（无背景色，不影响列宽） ── */
.top-value {
  font-weight: 800;
  color: #f97316;
  text-shadow: 0 0 8px rgba(249, 115, 22, 0.5);
}

/* ── 动画 ── */
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}

@keyframes scaleIn {
  from { transform: scale(0.9); opacity: 0; }
  to { transform: scale(1); opacity: 1; }
}
.animate-scale-in {
  animation: scaleIn 0.2s ease;
}
</style>
