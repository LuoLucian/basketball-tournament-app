<template>
  <div class="page-container">
    <!-- 返回 + 标题 -->
    <div class="flex items-center gap-3 mb-5">
      <router-link to="/games" class="text-dark-500 hover:text-white transition-colors p-1 flex-shrink-0">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </router-link>
      <div class="flex-1 min-w-0">
        <h1 class="text-lg font-bold text-white truncate">{{ game?.title || '赛事详情' }}</h1>
        <p v-if="game?.scheduled_at" class="text-xs text-dark-500 mt-0.5">{{ fmtDateTime(game.scheduled_at) }}{{ game?.venue ? ' · ' + game.venue : '' }}</p>
      </div>
    </div>
    <!-- 操作按钮（独立行，避免与标题重叠） -->
    <div v-if="canRecord || auth.isSuperAdmin" class="flex gap-2 mb-5">
      <router-link v-if="canRecord" :to="`/games/${gameId}/record`"
        class="btn-accent btn-sm flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
        </svg>
        进入录入
      </router-link>
      <button v-if="auth.isSuperAdmin && game && !editMode"
        @click="enterEditMode"
        class="btn-ghost btn-sm text-dark-500 hover:text-warning hover:bg-warning/10 hover:border-warning/20 flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
        </svg>
        编辑数据
      </button>
      <button v-if="auth.isSuperAdmin && !editMode"
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
        class="mvp-banner relative rounded-2xl p-6 mb-6 overflow-hidden animate-mvp-entrance">
        <!-- 多层光效背景 -->
        <div class="absolute inset-0 bg-gradient-to-r from-yellow-900/40 via-orange-900/30 to-dark-850"></div>
        <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(234,179,8,0.2),transparent_70%)]"></div>
        <!-- 旋转光环 -->
        <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div class="mvp-ring-1 absolute w-32 h-32 rounded-full border border-yellow-400/20"></div>
          <div class="mvp-ring-2 absolute w-40 h-40 rounded-full border border-orange-400/15"></div>
          <div class="mvp-ring-3 absolute w-48 h-48 rounded-full border border-yellow-300/10"></div>
        </div>
        <!-- 顶部金色边框 -->
        <div class="absolute top-0 left-0 right-0 h-0.5 bg-gradient-to-r from-yellow-500 via-orange-400 to-yellow-500 rounded-t-2xl"></div>
        <!-- 底部金色边框 -->
        <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-yellow-500/50 to-transparent"></div>
        <!-- 漂浮粒子（更多） -->
        <div class="absolute top-3 right-8 w-2 h-2 rounded-full bg-yellow-400/60 mvp-particle-1"></div>
        <div class="absolute top-6 right-16 w-1.5 h-1.5 rounded-full bg-orange-400/50 mvp-particle-2"></div>
        <div class="absolute bottom-4 right-10 w-1 h-1 rounded-full bg-yellow-300/60 mvp-particle-3"></div>
        <div class="absolute top-8 left-12 w-1.5 h-1.5 rounded-full bg-yellow-500/40 mvp-particle-4"></div>
        <div class="absolute bottom-6 left-20 w-1 h-1 rounded-full bg-orange-300/50 mvp-particle-5"></div>
        <!-- 闪光效果 -->
        <div class="absolute top-0 left-1/4 w-px h-full bg-gradient-to-b from-yellow-400/30 via-transparent to-transparent mvp-flash"></div>
        <div class="absolute top-0 right-1/3 w-px h-full bg-gradient-to-b from-orange-400/20 via-transparent to-transparent mvp-flash-reverse"></div>

        <div class="relative z-10 flex items-center gap-5">
          <!-- 奖杯（放大+光晕） -->
          <div class="relative flex-shrink-0">
            <div class="w-20 h-20 rounded-2xl bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600
                        flex items-center justify-center text-4xl shadow-neon-orange
                        animate-mvp-trophy">
              🏆
            </div>
            <!-- 多层光晕 -->
            <div class="absolute -inset-2 rounded-2xl bg-gradient-to-br from-yellow-400/30 to-orange-500/30 blur-xl -z-10 animate-mvp-glow"></div>
            <div class="absolute -inset-4 rounded-3xl bg-gradient-to-br from-yellow-400/15 to-orange-500/15 blur-2xl -z-20 animate-pulse"></div>
          </div>
          <!-- 信息（放大） -->
          <div class="flex-1 min-w-0">
            <p class="text-xs text-yellow-500/90 font-black uppercase tracking-[0.2em] mb-1">⭐ 本场 MVP</p>
            <p class="font-black text-white text-2xl leading-tight mb-1 animate-mvp-name">{{ mvpWinner.player?.name }}</p>
            <p class="text-xs text-dark-400">
              综合评分
              <span class="text-yellow-400 font-black text-lg ml-1">{{ mvpWinner.mvp_score }}</span>
            </p>
          </div>
          <!-- MVP 数据摘要（更详细） -->
          <div v-if="mvpStats" class="hidden sm:flex flex-col gap-1.5 flex-shrink-0 text-right bg-dark-800/40 rounded-xl p-3 border border-yellow-500/20">
            <div class="text-xs text-dark-500">
              <span class="text-white font-black text-lg">{{ mvpStats.pts }}</span>
              <span class="text-yellow-500 ml-0.5">分</span>
            </div>
            <div class="flex gap-3 text-xs">
              <span class="text-dark-500">
                <span class="text-blue-400 font-bold">{{ mvpStats.reb }}</span> 板
              </span>
              <span class="text-dark-500">
                <span class="text-green-400 font-bold">{{ mvpStats.ast }}</span> 助
              </span>
            </div>
            <div v-if="mvpStats.stl || mvpStats.blk" class="flex gap-3 text-[10px]">
              <span v-if="mvpStats.stl" class="text-dark-600">
                <span class="text-purple-400 font-bold">{{ mvpStats.stl }}</span> 断
              </span>
              <span v-if="mvpStats.blk" class="text-dark-600">
                <span class="text-pink-400 font-bold">{{ mvpStats.blk }}</span> 帽
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- ════════════════════════════════════════
           Tab 切换：数据统计 / 教练视角
           ════════════════════════════════════════ -->
      <div class="flex gap-1 bg-dark-800 rounded-lg p-0.5 mb-4">
        <button v-for="tab in detailTabs" :key="tab.key"
          @click="activeTab = tab.key"
          class="flex-1 px-3 py-2 rounded-md text-xs font-medium transition-all duration-200"
          :class="activeTab === tab.key
            ? 'bg-primary-600/20 text-primary-300 shadow-sm'
            : 'text-dark-500 hover:text-dark-300'">
          {{ tab.label }}
        </button>
      </div>

      <!-- ════════════════════════════════════════
           球员数据统计表
           ════════════════════════════════════════ -->
      <div v-show="activeTab === 'stats'" class="card mb-4">
        <div class="card-header flex items-center justify-between">
          <h2 class="font-semibold text-white">球员数据</h2>
          <!-- 队伍切换 / 编辑模式按钮 -->
          <div v-if="!editMode" class="flex gap-1 bg-dark-800 rounded-lg p-0.5">
            <button v-for="opt in teamFilterOptions" :key="opt.value"
              @click="teamFilter = opt.value"
              class="px-2.5 py-1 rounded-md text-xs font-medium transition-all duration-200"
              :class="teamFilter === opt.value
                ? 'bg-primary-600/20 text-primary-300 shadow-sm'
                : 'text-dark-500 hover:text-dark-300'">
              {{ opt.label }}
            </button>
          </div>
          <div v-if="editMode" class="flex gap-2">
            <button @click="saveEdits" :disabled="saving" class="px-3 py-1 rounded-lg text-xs font-semibold bg-primary-600 text-white hover:bg-primary-500">
              {{ saving ? '保存中...' : '保存' }}
            </button>
            <button @click="cancelEdit" class="px-3 py-1 rounded-lg text-xs font-medium bg-dark-800 text-dark-400 hover:text-white">
              取消
            </button>
          </div>
        </div>

        <div style="overflow-x: auto; overflow-y: clip;">
          <table class="w-full" style="min-width: 620px;">
            <thead>
              <tr class="border-b border-dark-700/50">
                <th class="sticky-th text-left px-2 py-2.5 text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 90px;">球员</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 44px;">得分</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 44px;">篮板</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 44px;">助攻</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 44px;">抢断</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 44px;">盖帽</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 44px;">犯规</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 60px;">2分%</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 60px;">3分%</th>
                <th class="px-2 py-2.5 text-center text-xs font-semibold text-dark-500 whitespace-nowrap"
                    style="min-width: 44px;">失误</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-dark-700/30">

              <!-- ── 主队区块 ── -->
              <template v-if="teamFilter !== 'away'">
                <!-- 主队标题行（仅全队模式显示） -->
                <tr v-if="teamFilter === 'all' && getTeamStats('home').length"
                  class="bg-dark-800/50">
                  <td colspan="10" class="px-3 py-1.5">
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: homeColor }"></div>
                      <span class="text-[11px] font-bold" :style="{ color: homeColor }">{{ game.home_team?.name }}</span>
                      <span class="text-[10px] text-dark-600">主队 · {{ game.home_score }} 分</span>
                    </div>
                  </td>
                </tr>
                <!-- 主队球员行 -->
                <tr v-for="stat in getTeamStats('home')" :key="stat.player_id"
                  class="hover:bg-dark-800/40 transition-colors text-xs"
                  :class="isOnCourt(stat.player_id) ? 'bg-green-500/[0.04]' : ''">
                  <!-- 球员信息（固定列） -->
                  <td class="sticky-player-info px-2 py-1.5">
                    <div class="flex items-center gap-1.5">
                      <span v-if="isMvpRow(stat)" class="text-xs leading-none flex-shrink-0" title="本场MVP">👑</span>
                      <div class="w-6 h-6 rounded-full flex-shrink-0 overflow-hidden border border-dark-700/50">
                        <img v-if="stat.player_avatar_url || stat.player?.avatar_url"
                             :src="stat.player_avatar_url || stat.player?.avatar_url"
                             class="w-full h-full object-cover" alt="" />
                        <div v-else class="w-full h-full rounded-full flex items-center justify-center text-[8px] font-bold"
                             :style="{ backgroundColor: homeColor + '33', color: homeColor }">
                          {{ getInitials(stat.player_name || stat.player?.name) }}
                        </div>
                      </div>
                      <div class="min-w-0">
                        <span class="font-medium text-xs whitespace-nowrap truncate block leading-tight"
                          :class="isMvpRow(stat) ? 'text-yellow-200' : 'text-white'">
                          {{ stat.player_name || stat.player?.name }}
                        </span>
                        <div class="flex items-center gap-1.5 leading-tight">
                          <span v-if="isOnCourt(stat.player_id)"
                                class="relative flex h-2 w-2 flex-shrink-0">
                            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                            <span class="relative inline-flex rounded-full h-2 w-2 bg-green-400 shadow-[0_0_6px_rgba(74,222,128,0.6)]"></span>
                          </span>
                          <span v-if="stat.jersey_no || stat.player?.jersey_no"
                                class="text-[9px] font-bold" :style="{ color: homeColor }">
                            #{{ stat.jersey_no || stat.player?.jersey_no }}
                          </span>
                          <span v-if="stat.player?.team_position"
                                class="text-[8px] text-dark-500 bg-dark-700/40 px-0.5 rounded">
                            {{ stat.player?.team_position }}
                          </span>
                        </div>
                      </div>
                    </div>
                  </td>
                  <!-- 得分 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('pts', stat, 'home') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].pts" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.pts }}</span>
                  </td>
                  <!-- 篮板 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('reb', stat, 'home') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].reb" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.reb }}</span>
                  </td>
                  <!-- 助攻 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('ast', stat, 'home') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].ast" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.ast }}</span>
                  </td>
                  <!-- 抢断 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('stl', stat, 'home') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].stl" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.stl }}</span>
                  </td>
                  <!-- 盖帽 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('blk', stat, 'home') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].blk" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.blk }}</span>
                  </td>
                  <!-- 犯规 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (stat.pf >= 5 ? 'text-danger font-bold' : stat.pf >= 3 ? 'text-warning font-semibold' : 'text-dark-500')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].pf" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.pf }}</span>
                  </td>
                  <!-- 2分命中率 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('fg_pct', stat, 'home') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].fgm" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fga" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ fgPct(stat) }}</span>
                  </td>
                  <!-- 3分命中率 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('fg3_pct', stat, 'home') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].fg3m" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fg3a" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ fg3Pct(stat) }}</span>
                  </td>
                  <!-- 失误 -->
                  <td class="px-2 py-2 text-center text-dark-500">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].tov" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.tov }}</span>
                  </td>
                </tr>
              </template>

              <!-- ── 客队区块 ── -->
              <template v-if="teamFilter !== 'home'">
                <!-- 客队标题行（仅全队模式显示） -->
                <tr v-if="teamFilter === 'all' && getTeamStats('away').length"
                  class="bg-dark-800/50">
                  <td colspan="10" class="px-3 py-1.5">
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: awayColor }"></div>
                      <span class="text-[11px] font-bold" :style="{ color: awayColor }">{{ game.away_team?.name }}</span>
                      <span class="text-[10px] text-dark-600">客队 · {{ game.away_score }} 分</span>
                    </div>
                  </td>
                </tr>
                <!-- 客队球员行 -->
                <tr v-for="stat in getTeamStats('away')" :key="stat.player_id"
                  class="hover:bg-dark-800/40 transition-colors text-xs"
                  :class="isOnCourt(stat.player_id) ? 'bg-green-500/[0.04]' : ''">
                  <!-- 球员信息（固定列） -->
                  <td class="sticky-player-info px-2 py-1.5">
                    <div class="flex items-center gap-1.5">
                      <span v-if="isMvpRow(stat)" class="text-xs leading-none flex-shrink-0" title="本场MVP">👑</span>
                      <div class="w-6 h-6 rounded-full flex-shrink-0 overflow-hidden border border-dark-700/50">
                        <img v-if="stat.player_avatar_url || stat.player?.avatar_url"
                             :src="stat.player_avatar_url || stat.player?.avatar_url"
                             class="w-full h-full object-cover" alt="" />
                        <div v-else class="w-full h-full rounded-full flex items-center justify-center text-[8px] font-bold"
                             :style="{ backgroundColor: awayColor + '33', color: awayColor }">
                          {{ getInitials(stat.player_name || stat.player?.name) }}
                        </div>
                      </div>
                      <div class="min-w-0">
                        <span class="font-medium text-xs whitespace-nowrap truncate block leading-tight"
                          :class="isMvpRow(stat) ? 'text-yellow-200' : 'text-white'">
                          {{ stat.player_name || stat.player?.name }}
                        </span>
                        <div class="flex items-center gap-1.5 leading-tight">
                          <span v-if="isOnCourt(stat.player_id)"
                                class="relative flex h-2 w-2 flex-shrink-0">
                            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                            <span class="relative inline-flex rounded-full h-2 w-2 bg-green-400 shadow-[0_0_6px_rgba(74,222,128,0.6)]"></span>
                          </span>
                          <span v-if="stat.jersey_no || stat.player?.jersey_no"
                                class="text-[9px] font-bold" :style="{ color: awayColor }">
                            #{{ stat.jersey_no || stat.player?.jersey_no }}
                          </span>
                          <span v-if="stat.player?.team_position"
                                class="text-[8px] text-dark-500 bg-dark-700/40 px-0.5 rounded">
                            {{ stat.player?.team_position }}
                          </span>
                        </div>
                      </div>
                    </div>
                  </td>
                  <!-- 得分 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('pts', stat, 'away') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].pts" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.pts }}</span>
                  </td>
                  <!-- 篮板 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('reb', stat, 'away') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].reb" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.reb }}</span>
                  </td>
                  <!-- 助攻 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('ast', stat, 'away') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].ast" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.ast }}</span>
                  </td>
                  <!-- 抢断 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('stl', stat, 'away') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].stl" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.stl }}</span>
                  </td>
                  <!-- 盖帽 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('blk', stat, 'away') ? 'top-value' : 'text-dark-400')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].blk" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.blk }}</span>
                  </td>
                  <!-- 犯规 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (stat.pf >= 5 ? 'text-danger font-bold' : stat.pf >= 3 ? 'text-warning font-semibold' : 'text-dark-500')">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].pf" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.pf }}</span>
                  </td>
                  <!-- 2分命中率 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('fg_pct', stat, 'away') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].fgm" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fga" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ fgPct(stat) }}</span>
                  </td>
                  <!-- 3分命中率 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('fg3_pct', stat, 'away') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].fg3m" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fg3a" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ fg3Pct(stat) }}</span>
                  </td>
                  <!-- 失误 -->
                  <td class="px-2 py-2 text-center text-dark-500">
                    <input v-if="editMode" v-model.number="editData[stat.player_id].tov" type="number" min="0"
                      class="w-10 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-xs text-white" />
                    <span v-else>{{ stat.tov }}</span>
                  </td>
                </tr>
              </template>

              <!-- 空状态 -->
              <tr v-if="teamFilter === 'all' && getTeamStats('home').length === 0 && getTeamStats('away').length === 0">
                <td colspan="10" class="text-center py-8 text-dark-500 text-xs">暂无数据</td>
              </tr>
              <tr v-if="teamFilter === 'home' && getTeamStats('home').length === 0">
                <td colspan="10" class="text-center py-6 text-dark-500 text-xs">暂无主队数据</td>
              </tr>
              <tr v-if="teamFilter === 'away' && getTeamStats('away').length === 0">
                <td colspan="10" class="text-center py-6 text-dark-500 text-xs">暂无客队数据</td>
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

      <!-- ════════════════════════════════════════
           教练视角面板
           ════════════════════════════════════════ -->
      <div v-show="activeTab === 'coach'" class="space-y-4">
        <!-- 队伍切换 -->
        <div class="flex gap-1 bg-dark-800 rounded-lg p-0.5">
          <button v-for="opt in coachTeamOptions" :key="opt.value"
            @click="coachTeamFilter = opt.value"
            class="flex-1 px-3 py-2 rounded-md text-xs font-medium transition-all duration-200"
            :class="coachTeamFilter === opt.value
              ? 'bg-primary-600/20 text-primary-300 shadow-sm'
              : 'text-dark-500 hover:text-dark-300'">
            {{ opt.label }}
          </button>
        </div>

        <!-- 加载中 -->
        <div v-if="coachLoading" class="card p-8 text-center text-dark-500 text-sm">加载教练数据...</div>

        <!-- 教练数据卡片 -->
        <div v-else class="space-y-3">
          <!-- 全部队伍模式：按队伍分组显示 -->
          <template v-if="coachTeamFilter === 'all'">
            <!-- 主队区域 -->
            <div v-if="homeCoachPlayers.length > 0">
              <div class="flex items-center gap-2 mb-2 px-1">
                <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: homeColor }"></div>
                <span class="text-[11px] font-bold" :style="{ color: homeColor }">{{ game.home_team?.name }}</span>
                <span class="text-[10px] text-dark-600">主队 · {{ game.home_score }} 分</span>
              </div>
              <div class="space-y-3">
          <div v-for="p in homeCoachPlayers" :key="p.player_id"
            class="card p-3 border border-dark-700/50"
            :class="isOnCourt(p.player_id) ? 'border-green-500/30 bg-green-500/5' : ''">
            <div class="flex items-center gap-2.5 mb-2.5">
              <div class="w-8 h-8 rounded-lg flex-shrink-0 overflow-hidden border border-dark-700/50"
                :style="{ backgroundColor: (p.team_id === game?.home_team_id ? homeColor : awayColor) + '33' }">
                <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover" alt="" />
                <div v-else class="w-full h-full flex items-center justify-center text-[10px] font-bold"
                  :style="{ color: p.team_id === game?.home_team_id ? homeColor : awayColor }">
                  {{ (p.name || '?').charAt(0) }}
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-1.5">
                  <span class="text-xs font-bold text-white truncate">{{ p.name }}</span>
                  <span v-if="isOnCourt(p.player_id)"
                    class="text-[8px] bg-green-500/20 text-green-400 px-1 rounded font-bold">场上</span>
                </div>
                <div class="flex items-center gap-2 text-[10px]">
                  <span v-if="p.jersey_no" class="text-dark-500">#{{ p.jersey_no }}</span>
                  <!-- 位置标签（可点击切换） -->
                  <span class="text-[9px] px-1.5 py-0.5 rounded bg-dark-700 text-dark-400 font-medium">{{ p.position }}</span>
                  <!-- 上场时间醒目显示 -->
                  <span class="bg-primary-500/15 text-primary-400 px-1.5 py-0.5 rounded font-bold text-[10px]">
                    ⏱ {{ p.totalMinutes }}
                  </span>
                </div>
              </div>
              <!-- 评分 -->
              <div class="text-right flex-shrink-0">
                <p class="text-[9px] text-dark-500">效率评分</p>
                <p class="text-lg font-black" :class="p.rating >= 15 ? 'text-green-400' : p.rating >= 8 ? 'text-yellow-400' : p.rating >= 0 ? 'text-dark-300' : 'text-red-400'">
                  {{ p.rating > 0 ? '+' : '' }}{{ p.rating }}
                </p>
              </div>
            </div>

            <!-- 全场数据 -->
            <div class="grid grid-cols-7 gap-1 mb-2">
              <div v-for="s in coachStatItems" :key="s.key" class="text-center">
                <p class="text-[9px] text-dark-600">{{ s.label }}</p>
                <p class="text-xs font-bold" :class="p[s.key] > 0 ? 'text-white' : 'text-dark-600'">{{ p[s.key] }}</p>
              </div>
            </div>

            <!-- 上场阶段数据 -->
            <div v-if="p.stints && p.stints.length > 0" class="border-t border-dark-700/30 pt-2">
              <p class="text-[9px] text-dark-600 mb-1.5 font-semibold">上场阶段</p>
              <div class="space-y-1">
                <div v-for="s in p.stints" :key="s.stintIndex" class="flex items-center gap-2 text-[10px]">
                  <span class="w-8 text-dark-500 font-medium flex-shrink-0">#{{ s.stintIndex }}</span>
                  <select v-if="canViewCoachTab" @change="changeStintPosition(p.player_id, s.stintIndex, $event.target.value)"
                    :value="s.stintPosition || p.position"
                    class="bg-dark-700 text-dark-300 text-[9px] px-1 py-0 rounded border border-dark-600 cursor-pointer focus:outline-none focus:border-primary-500 w-10 flex-shrink-0">
                    <option value="PG">PG</option>
                    <option value="SG">SG</option>
                    <option value="SF">SF</option>
                    <option value="PF">PF</option>
                    <option value="C">C</option>
                    <option value="FLEX">FLEX</option>
                  </select>
                  <span v-else class="text-dark-500 w-10 flex-shrink-0">{{ s.stintPosition || p.position }}</span>
                  <span class="text-primary-400 font-medium w-10 flex-shrink-0">{{ s.minutes }}</span>
                  <div class="flex-1 flex gap-1.5">
                    <span class="text-dark-400">{{ s.pts }}分</span>
                    <span class="text-dark-500">{{ s.reb }}板</span>
                    <span class="text-dark-500">{{ s.ast }}助</span>
                    <span v-if="s.stl" class="text-dark-600">{{ s.stl }}断</span>
                    <span v-if="s.blk" class="text-dark-600">{{ s.blk }}帽</span>
                    <span v-if="s.tov" class="text-red-400/60">{{ s.tov }}误</span>
                  </div>
                  <span class="font-bold flex-shrink-0" :class="getRatingClass(s.rating)">
                    {{ s.rating > 0 ? '+' : '' }}{{ s.rating }}
                  </span>
                </div>
              </div>
            </div>
          </div>
              </div>
            </div>
            <!-- 客队区域 -->
            <div v-if="awayCoachPlayers.length > 0">
              <div class="flex items-center gap-2 mb-2 px-1 mt-2">
                <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: awayColor }"></div>
                <span class="text-[11px] font-bold" :style="{ color: awayColor }">{{ game.away_team?.name }}</span>
                <span class="text-[10px] text-dark-600">客队 · {{ game.away_score }} 分</span>
              </div>
              <div class="space-y-3">
          <div v-for="p in awayCoachPlayers" :key="p.player_id"
            class="card p-3 border border-dark-700/50"
            :class="isOnCourt(p.player_id) ? 'border-green-500/30 bg-green-500/5' : ''">
            <div class="flex items-center gap-2.5 mb-2.5">
              <div class="w-8 h-8 rounded-lg flex-shrink-0 overflow-hidden border border-dark-700/50"
                :style="{ backgroundColor: (p.team_id === game?.home_team_id ? homeColor : awayColor) + '33' }">
                <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover" alt="" />
                <div v-else class="w-full h-full flex items-center justify-center text-[10px] font-bold"
                  :style="{ color: p.team_id === game?.home_team_id ? homeColor : awayColor }">
                  {{ (p.name || '?').charAt(0) }}
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-1.5">
                  <span class="text-xs font-bold text-white truncate">{{ p.name }}</span>
                  <span v-if="isOnCourt(p.player_id)"
                    class="text-[8px] bg-green-500/20 text-green-400 px-1 rounded font-bold">场上</span>
                </div>
                <div class="flex items-center gap-2 text-[10px]">
                  <span v-if="p.jersey_no" class="text-dark-500">#{{ p.jersey_no }}</span>
                  <!-- 位置标签（可点击切换） -->
                  <span class="text-[9px] px-1.5 py-0.5 rounded bg-dark-700 text-dark-400 font-medium">{{ p.position }}</span>
                  <!-- 上场时间醒目显示 -->
                  <span class="bg-primary-500/15 text-primary-400 px-1.5 py-0.5 rounded font-bold text-[10px]">
                    ⏱ {{ p.totalMinutes }}
                  </span>
                </div>
              </div>
              <!-- 评分 -->
              <div class="text-right flex-shrink-0">
                <p class="text-[9px] text-dark-500">效率评分</p>
                <p class="text-lg font-black" :class="p.rating >= 15 ? 'text-green-400' : p.rating >= 8 ? 'text-yellow-400' : p.rating >= 0 ? 'text-dark-300' : 'text-red-400'">
                  {{ p.rating > 0 ? '+' : '' }}{{ p.rating }}
                </p>
              </div>
            </div>

            <!-- 全场数据 -->
            <div class="grid grid-cols-7 gap-1 mb-2">
              <div v-for="s in coachStatItems" :key="s.key" class="text-center">
                <p class="text-[9px] text-dark-600">{{ s.label }}</p>
                <p class="text-xs font-bold" :class="p[s.key] > 0 ? 'text-white' : 'text-dark-600'">{{ p[s.key] }}</p>
              </div>
            </div>

            <!-- 上场阶段数据 -->
            <div v-if="p.stints && p.stints.length > 0" class="border-t border-dark-700/30 pt-2">
              <p class="text-[9px] text-dark-600 mb-1.5 font-semibold">上场阶段</p>
              <div class="space-y-1">
                <div v-for="s in p.stints" :key="s.stintIndex" class="flex items-center gap-2 text-[10px]">
                  <span class="w-8 text-dark-500 font-medium flex-shrink-0">#{{ s.stintIndex }}</span>
                  <select v-if="canViewCoachTab" @change="changeStintPosition(p.player_id, s.stintIndex, $event.target.value)"
                    :value="s.stintPosition || p.position"
                    class="bg-dark-700 text-dark-300 text-[9px] px-1 py-0 rounded border border-dark-600 cursor-pointer focus:outline-none focus:border-primary-500 w-10 flex-shrink-0">
                    <option value="PG">PG</option>
                    <option value="SG">SG</option>
                    <option value="SF">SF</option>
                    <option value="PF">PF</option>
                    <option value="C">C</option>
                    <option value="FLEX">FLEX</option>
                  </select>
                  <span v-else class="text-dark-500 w-10 flex-shrink-0">{{ s.stintPosition || p.position }}</span>
                  <span class="text-primary-400 font-medium w-10 flex-shrink-0">{{ s.minutes }}</span>
                  <div class="flex-1 flex gap-1.5">
                    <span class="text-dark-400">{{ s.pts }}分</span>
                    <span class="text-dark-500">{{ s.reb }}板</span>
                    <span class="text-dark-500">{{ s.ast }}助</span>
                    <span v-if="s.stl" class="text-dark-600">{{ s.stl }}断</span>
                    <span v-if="s.blk" class="text-dark-600">{{ s.blk }}帽</span>
                    <span v-if="s.tov" class="text-red-400/60">{{ s.tov }}误</span>
                  </div>
                  <span class="font-bold flex-shrink-0" :class="getRatingClass(s.rating)">
                    {{ s.rating > 0 ? '+' : '' }}{{ s.rating }}
                  </span>
                </div>
              </div>
            </div>
          </div>
              </div>
            </div>
            <div v-if="homeCoachPlayers.length === 0 && awayCoachPlayers.length === 0" class="card p-8 text-center text-dark-500 text-sm">暂无数据</div>
          </template>

          <!-- 单队模式 -->
          <template v-else>
          <div v-for="p in filteredCoachPlayers" :key="p.player_id"
            class="card p-3 border border-dark-700/50"
            :class="isOnCourt(p.player_id) ? 'border-green-500/30 bg-green-500/5' : ''">
            <div class="flex items-center gap-2.5 mb-2.5">
              <div class="w-8 h-8 rounded-lg flex-shrink-0 overflow-hidden border border-dark-700/50"
                :style="{ backgroundColor: (p.team_id === game?.home_team_id ? homeColor : awayColor) + '33' }">
                <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover" alt="" />
                <div v-else class="w-full h-full flex items-center justify-center text-[10px] font-bold"
                  :style="{ color: p.team_id === game?.home_team_id ? homeColor : awayColor }">
                  {{ (p.name || '?').charAt(0) }}
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-1.5">
                  <span class="text-xs font-bold text-white truncate">{{ p.name }}</span>
                  <span v-if="isOnCourt(p.player_id)"
                    class="text-[8px] bg-green-500/20 text-green-400 px-1 rounded font-bold">场上</span>
                </div>
                <div class="flex items-center gap-2 text-[10px]">
                  <span v-if="p.jersey_no" class="text-dark-500">#{{ p.jersey_no }}</span>
                  <!-- 位置标签（可点击切换） -->
                  <span class="text-[9px] px-1.5 py-0.5 rounded bg-dark-700 text-dark-400 font-medium">{{ p.position }}</span>
                  <!-- 上场时间醒目显示 -->
                  <span class="bg-primary-500/15 text-primary-400 px-1.5 py-0.5 rounded font-bold text-[10px]">
                    ⏱ {{ p.totalMinutes }}
                  </span>
                </div>
              </div>
              <!-- 评分 -->
              <div class="text-right flex-shrink-0">
                <p class="text-[9px] text-dark-500">效率评分</p>
                <p class="text-lg font-black" :class="p.rating >= 15 ? 'text-green-400' : p.rating >= 8 ? 'text-yellow-400' : p.rating >= 0 ? 'text-dark-300' : 'text-red-400'">
                  {{ p.rating > 0 ? '+' : '' }}{{ p.rating }}
                </p>
              </div>
            </div>

            <!-- 全场数据 -->
            <div class="grid grid-cols-7 gap-1 mb-2">
              <div v-for="s in coachStatItems" :key="s.key" class="text-center">
                <p class="text-[9px] text-dark-600">{{ s.label }}</p>
                <p class="text-xs font-bold" :class="p[s.key] > 0 ? 'text-white' : 'text-dark-600'">{{ p[s.key] }}</p>
              </div>
            </div>

            <!-- 上场阶段数据 -->
            <div v-if="p.stints && p.stints.length > 0" class="border-t border-dark-700/30 pt-2">
              <p class="text-[9px] text-dark-600 mb-1.5 font-semibold">上场阶段</p>
              <div class="space-y-1">
                <div v-for="s in p.stints" :key="s.stintIndex" class="flex items-center gap-2 text-[10px]">
                  <span class="w-8 text-dark-500 font-medium flex-shrink-0">#{{ s.stintIndex }}</span>
                  <select v-if="canViewCoachTab" @change="changeStintPosition(p.player_id, s.stintIndex, $event.target.value)"
                    :value="s.stintPosition || p.position"
                    class="bg-dark-700 text-dark-300 text-[9px] px-1 py-0 rounded border border-dark-600 cursor-pointer focus:outline-none focus:border-primary-500 w-10 flex-shrink-0">
                    <option value="PG">PG</option>
                    <option value="SG">SG</option>
                    <option value="SF">SF</option>
                    <option value="PF">PF</option>
                    <option value="C">C</option>
                    <option value="FLEX">FLEX</option>
                  </select>
                  <span v-else class="text-dark-500 w-10 flex-shrink-0">{{ s.stintPosition || p.position }}</span>
                  <span class="text-primary-400 font-medium w-10 flex-shrink-0">{{ s.minutes }}</span>
                  <div class="flex-1 flex gap-1.5">
                    <span class="text-dark-400">{{ s.pts }}分</span>
                    <span class="text-dark-500">{{ s.reb }}板</span>
                    <span class="text-dark-500">{{ s.ast }}助</span>
                    <span v-if="s.stl" class="text-dark-600">{{ s.stl }}断</span>
                    <span v-if="s.blk" class="text-dark-600">{{ s.blk }}帽</span>
                    <span v-if="s.tov" class="text-red-400/60">{{ s.tov }}误</span>
                  </div>
                  <span class="font-bold flex-shrink-0" :class="getRatingClass(s.rating)">
                    {{ s.rating > 0 ? '+' : '' }}{{ s.rating }}
                  </span>
                </div>
              </div>
            </div>
          </div>
            <div v-if="filteredCoachPlayers.length === 0" class="card p-8 text-center text-dark-500 text-sm">暂无数据</div>
          </template>
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
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useGameStore } from '@/stores/game'
import { supabase } from '@/utils/supabase'
import { GAME_STATUS_LABELS, getInitials, fmtDateTime } from '@/utils/helpers'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const gameStore = useGameStore()
const gameId = route.params.id

const game = ref(null)
const gameChannel = ref(null)  // 实时订阅频道
const stats = ref([])
const mvp = ref([])
const courtLineup = ref([])  // 当前场上阵容 [{player_id, team_id, slot_no, on_at}]
const coachLoading = ref(false)
const coachTeamFilter = ref('all')
const coachPlayers = ref([])  // 教练视角球员数据
const coachPositionOverrides = ref({})  // { [playerId]: position } 教练手动调整的位置
const activeTab = ref('stats')
const loading = ref(true)
const loadError = ref('')

const editMode = ref(false)
const saving = ref(false)
const editData = ref({})

// ── 超管编辑功能 ──
const statEditFields = ['pts', 'reb', 'ast', 'stl', 'blk', 'pf', 'tov', 'fgm', 'fga', 'fg3m', 'fg3a']

function enterEditMode() {
  editData.value = {}
  for (const stat of stats.value) {
    editData.value[stat.player_id] = {}
    for (const f of statEditFields) {
      editData.value[stat.player_id][f] = stat[f] || 0
    }
  }
  editMode.value = true
}

function cancelEdit() {
  editMode.value = false
  editData.value = {}
}

async function saveEdits() {
  saving.value = true
  try {
    for (const stat of stats.value) {
      const d = editData.value[stat.player_id]
      if (!d) continue
      for (const f of statEditFields) {
        const newVal = d[f] ?? 0
        if (newVal !== (stat[f] || 0)) {
          const { data: result, error } = await supabase.rpc('admin_set_game_stat', {
            p_game_id: gameId,
            p_player_id: stat.player_id,
            p_team_id: stat.team_id,
            p_field: f,
            p_new_value: newVal,
            p_user_id: auth.user?.id || null
          })
          if (error) throw error
          if (result?.success === false) throw new Error(result.error || '保存失败')
        }
      }
    }
    editMode.value = false
    // 重新加载数据
    router.go(0)
  } catch (e) {
    alert('保存失败：' + (e.message || '未知错误'))
  } finally {
    saving.value = false
  }
}

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

// MVP PER 评分算法（与教练面板一致）
const MVP_POSITION_WEIGHTS = {
  PG:  { pts: 1.0, reb: 0.6, ast: 1.5, stl: 1.3, blk: 0.4, tov: -1.2, pf: -0.8, fga_miss: -0.7, fta_miss: -0.3 },
  SG:  { pts: 1.2, reb: 0.7, ast: 1.1, stl: 1.1, blk: 0.5, tov: -1.0, pf: -0.8, fga_miss: -0.8, fta_miss: -0.3 },
  SF:  { pts: 1.1, reb: 0.9, ast: 1.0, stl: 1.0, blk: 0.7, tov: -1.0, pf: -0.8, fga_miss: -0.8, fta_miss: -0.3 },
  PF:  { pts: 1.0, reb: 1.3, ast: 0.7, stl: 0.8, blk: 1.0, tov: -0.9, pf: -0.9, fga_miss: -0.7, fta_miss: -0.4 },
  C:   { pts: 1.0, reb: 1.5, ast: 0.5, stl: 0.6, blk: 1.4, tov: -0.8, pf: -1.0, fga_miss: -0.6, fta_miss: -0.5 },
  FLEX:{ pts: 1.0, reb: 1.0, ast: 1.0, stl: 1.0, blk: 1.0, tov: -1.0, pf: -0.8, fga_miss: -0.7, fta_miss: -0.4 }
}

function calcMvpRating(s, pos) {
  const w = MVP_POSITION_WEIGHTS[pos] || MVP_POSITION_WEIGHTS.FLEX
  const fgaMiss = (s.fga || 0) - (s.fgm || 0)
  const ftaMiss = (s.fta || 0) - (s.ftm || 0)
  return Math.round((
    (s.pts || 0) * w.pts +
    (s.reb || 0) * w.reb +
    (s.ast || 0) * w.ast +
    (s.stl || 0) * w.stl +
    (s.blk || 0) * w.blk +
    (s.tov || 0) * w.tov +
    (s.pf || 0) * w.pf +
    fgaMiss * w.fga_miss +
    ftaMiss * w.fta_miss
  ) * 10) / 10
}

const mvpWinner = computed(() => {
  if (!stats.value.length || game.value?.status !== 'finished') return null
  // 确定胜方
  const homeScore = game.value?.home_score || 0
  const awayScore = game.value?.away_score || 0
  let winningTeamId = null
  if (homeScore > awayScore) winningTeamId = game.value?.home_team_id
  else if (awayScore > homeScore) winningTeamId = game.value?.away_team_id
  else return null // 平局没有MVP
  
  // 从胜方球员中选评分最高的
  const winningStats = stats.value.filter(s => s.team_id === winningTeamId)
  if (!winningStats.length) return null
  
  let best = null
  let bestScore = -Infinity
  for (const s of winningStats) {
    const pos = s.player?.team_position || s.player_position || 'FLEX'
    const score = calcMvpRating(s, pos)
    if (score > bestScore) {
      bestScore = score
      best = { ...s, mvp_score: score, player: s.player }
    }
  }
  return best
})

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

// 判断球员是否当前在场上
function isOnCourt(playerId) {
  return courtLineup.value.some(l => l.player_id === playerId)
}

// Tab 配置
const detailTabs = computed(() => {
  const tabs = [{ key: 'stats', label: '📊 数据统计' }]
  // 教练视角权限：super_admin 看全部，admin 看自己创建的球队
  // 比赛进行中或已结束时均可查看（用于回顾总结）
  if (['active', 'finished'].includes(game.value?.status) && auth.isLoggedIn && canViewCoachTab.value) {
    tabs.push({ key: 'coach', label: '👔 教练视角' })
  }
  return tabs
})

// 教练视角权限判断
const canViewCoachTab = computed(() => {
  if (auth.role === 'super_admin') return true
  if (auth.role === 'admin') {
    const uid = auth.user?.id
    if (!uid || !game.value) return false
    const homeTeam = game.value.home_team || {}
    const awayTeam = game.value.away_team || {}
    // 兼容 owner_id 和 created_by 两种字段
    return homeTeam.owner_id === uid || homeTeam.created_by === uid
        || awayTeam.owner_id === uid || awayTeam.created_by === uid
  }
  return false
})

// 教练视角队伍筛选选项（超管可以看全部，管理员只看自己队伍不显示TAB）
const coachTeamOptions = computed(() => {
  if (!game.value) return []
  const opts = []
  // 球队管理员只有1个选项，不需要显示TAB
  if (auth.role === 'admin') return opts
  // 超管显示全部TAB
  if (auth.role === 'super_admin') {
    opts.push({ value: 'all', label: '全部' })
  }
  const uid = auth.user?.id
  const isHomeOwner = game.value.home_team?.owner_id === uid || game.value.home_team?.created_by === uid
  const isAwayOwner = game.value.away_team?.owner_id === uid || game.value.away_team?.created_by === uid
  if (isHomeOwner || auth.role === 'super_admin') {
    opts.push({ value: game.value.home_team_id, label: game.value.home_team?.name || '主队' })
  }
  if (isAwayOwner || auth.role === 'super_admin') {
    opts.push({ value: game.value.away_team_id, label: game.value.away_team?.name || '客队' })
  }
  return opts
})

// 教练面板统计项
const coachStatItems = [
  { key: 'pts', label: '得分' },
  { key: 'reb', label: '篮板' },
  { key: 'ast', label: '助攻' },
  { key: 'stl', label: '抢断' },
  { key: 'blk', label: '盖帽' },
  { key: 'tov', label: '失误' },
  { key: 'pf', label: '犯规' }
]

// 按队伍分组的教练球员
const homeCoachPlayers = computed(() => coachPlayers.value.filter(p => p.team_id === game.value?.home_team_id))
const awayCoachPlayers = computed(() => coachPlayers.value.filter(p => p.team_id === game.value?.away_team_id))

// 筛选后的教练球员
const filteredCoachPlayers = computed(() => {
  if (coachTeamFilter.value === 'all') return coachPlayers.value
  return coachPlayers.value.filter(p => p.team_id === coachTeamFilter.value)
})

// 加载教练视角数据
async function loadCoachData() {
  if (!game.value) return
  coachLoading.value = true
  try {
    // 获取所有阵容记录（含历史上下场记录）
    const { data: allLineup, error: lErr } = await supabase
      .from('game_lineup')
      .select('player_id, team_id, slot_no, quarter, on_at, off_at')
      .eq('game_id', gameId)
      .order('on_at', { ascending: true })
    if (lErr) throw lErr

    // 获取所有 action_logs（按节分组统计）
    const { data: actionLogs, error: aErr } = await supabase
      .from('action_logs')
      .select('player_id, team_id, action_type, delta, quarter, created_at')
      .eq('game_id', gameId)
      .eq('is_voided', false)
    if (aErr) throw aErr

    // 获取 game_stats（全场数据）
    const { data: gameStats, error: sErr } = await supabase
      .from('game_stats')
      .select('player_id, team_id, pts, reb, ast, stl, blk, tov, pf, fgm, fga, fg3m, fg3a, ftm, fta')
      .eq('game_id', gameId)
    if (sErr) throw sErr

    // 获取球衣号码和位置（先查，因为包含所有球队成员的 player_id）
    const teamIds = [game.value.home_team_id, game.value.away_team_id]
    let jerseyMap = {}
    let positionMap = {}
    const { data: tpData } = await supabase
      .from('team_players')
      .select('player_id, team_id, jersey_no, position')
      .in('team_id', teamIds)
    if (tpData) {
      jerseyMap = Object.fromEntries(tpData.map(t => [t.player_id, t]))
      positionMap = Object.fromEntries(tpData.map(t => [t.player_id, t.position]))
    }

    // 获取球员信息（包含球队所有成员 + 有lineup/stats记录的球员）
    const teamPlayerIds = (tpData || []).map(t => t.player_id)
    const playerIds = [...new Set([
      ...teamPlayerIds,
      ...(allLineup || []).map(l => l.player_id),
      ...(gameStats || []).map(s => s.player_id)
    ])]
    let playerMap = {}
    if (playerIds.length > 0) {
      const { data: players } = await supabase
        .from('players')
        .select('id, name, avatar_url')
        .in('id', playerIds)
      if (players) {
        playerMap = Object.fromEntries(players.map(p => [p.id, p]))
      }
    }

    // 计算每个球员的上场时间，并按上场阶段分组
    const minutesMap = {}  // { [playerId]: { total: 秒, quarters: { [q]: 秒 } } }
    const stintsMap = {}   // { [playerId]: [{ quarter, on_at, off_at, duration, team_id }] } 上场阶段

    for (const l of (allLineup || [])) {
      if (!minutesMap[l.player_id]) minutesMap[l.player_id] = { total: 0, quarters: {} }
      if (!stintsMap[l.player_id]) stintsMap[l.player_id] = []
      const m = minutesMap[l.player_id]
      // 使用 getLineupDurationSec 计算有效时长（扣除暂停）
      const duration = getLineupDurationSec(l)  // 秒
      m.total += duration

      const q = l.quarter || 1
      if (!m.quarters[q]) m.quarters[q] = 0
      m.quarters[q] += duration

      // 原始时长（未扣除暂停，用于评分计算）
      const rawDuration = Math.max(0, Math.floor(
        ((l.off_at ? new Date(l.off_at).getTime() : Date.now()) - new Date(l.on_at).getTime()) / 1000
      ))
      stintsMap[l.player_id].push({
        quarter: q,
        on_at: l.on_at,
        off_at: l.off_at || null,
        duration,           // 扣除暂停后的时长（用于显示）
        rawDuration,        // 原始时长（用于评分计算）
        team_id: l.team_id
      })
    }

    // 计算每个上场阶段中，该球员所在队伍和对方队伍的总得分变化
    function calcTeamPointsInWindow(teamId, startAt, endAt) {
      let pts = 0
      for (const a of (actionLogs || [])) {
        if (a.team_id !== teamId) continue
        const t = new Date(a.created_at)
        if (t >= startAt && t <= endAt) {
          if (a.action_type === 'pts_1') pts += 1 * (a.delta || 1)
          else if (a.action_type === 'pts_2') pts += 2 * (a.delta || 1)
          else if (a.action_type === 'pts_3') pts += 3 * (a.delta || 1)
        }
      }
      return pts
    }

    // 获取对方队伍 ID
    const homeId = game.value?.home_team_id
    const awayId = game.value?.away_team_id
    function getOpponentTeamId(teamId) {
      return teamId === homeId ? awayId : homeId
    }

    // 按 action_logs 的时间戳精确匹配到上场阶段
    const stintStatsMap = {}
    for (const pid of Object.keys(stintsMap)) {
      stintStatsMap[pid] = stintsMap[pid].map(stint => ({
        quarter: stint.quarter,
        duration: stint.duration,
        rawDuration: stint.rawDuration,
        team_id: stint.team_id,
        on_at: stint.on_at,
        off_at: stint.off_at,
        teamPointsGained: 0,      // 该阶段己方球队总得分
        oppPointsGained: 0,       // 该阶段对方球队总得分
        netEfficiency: 0,         // 净效率（己方 - 对方，每分钟）
        beforeNetRate: 0,         // 上场前净得分速率（每分钟）
        stats: { pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0, fgm: 0, fga: 0, ftm: 0, fta: 0 }
      }))
    }

    // 将 action_logs 分配到对应的上场阶段（按时间精确匹配）
    for (const a of (actionLogs || [])) {
      const stints = stintStatsMap[a.player_id]
      if (!stints) continue
      const actionTime = new Date(a.created_at)
      const d = a.delta || 1
      // 找到包含该 action 时间点的上场阶段
      const stint = stints.find(s => {
        const start = new Date(s.on_at)
        const end = s.off_at ? new Date(s.off_at) : new Date()
        return actionTime >= start && actionTime <= end
      })
      if (!stint) continue
      switch (a.action_type) {
        case 'pts_1': stint.stats.pts += 1 * d; stint.stats.ftm += 1 * d; stint.stats.fta += 1 * d; break
        case 'pts_2': stint.stats.pts += 2 * d; stint.stats.fgm += 1 * d; stint.stats.fga += 1 * d; break
        case 'pts_3': stint.stats.pts += 3 * d; stint.stats.fgm += 1 * d; stint.stats.fga += 1 * d; break
        case 'reb': stint.stats.reb += d; break
        case 'ast': stint.stats.ast += d; break
        case 'stl': stint.stats.stl += d; break
        case 'blk': stint.stats.blk += d; break
        case 'tov': stint.stats.tov += d; break
        case 'pf': stint.stats.pf += d; break
        case 'fga_miss': stint.stats.fga += d; break
        case 'fta_miss': stint.stats.fta += d; break
      }
    }

    // 计算每个阶段的己方得分、对方得分、净效率
    for (const pid of Object.keys(stintStatsMap)) {
      for (const stint of stintStatsMap[pid]) {
        const startAt = new Date(stint.on_at)
        const endAt = stint.off_at ? new Date(stint.off_at) : new Date()
        const oppTeamId = getOpponentTeamId(stint.team_id)

        stint.teamPointsGained = calcTeamPointsInWindow(stint.team_id, startAt, endAt)
        stint.oppPointsGained = calcTeamPointsInWindow(oppTeamId, startAt, endAt)

        // 净效率：该阶段每分钟净得分（己方 - 对方）
        const stintMins = Math.max(stint.duration / 60, 0.1)
        stint.netEfficiency = Math.round(((stint.teamPointsGained - stint.oppPointsGained) / stintMins) * 10) / 10

        // 上场前的净得分速率（往前推同样长的时间窗口）
        const beforeEnd = new Date(stint.on_at)
        const beforeStart = new Date(beforeEnd.getTime() - stint.duration * 1000)
        // 如果上场前没有足够的历史数据，用比赛整体平均代替
        const gameStart = game.value?.started_at ? new Date(game.value.started_at) : beforeStart
        const effectiveBeforeStart = beforeStart < gameStart ? gameStart : beforeStart
        const beforeWindowMs = beforeEnd.getTime() - effectiveBeforeStart.getTime()
        if (beforeWindowMs > 0) {
          const beforeOwnPts = calcTeamPointsInWindow(stint.team_id, effectiveBeforeStart, beforeEnd)
          const beforeOppPts = calcTeamPointsInWindow(oppTeamId, effectiveBeforeStart, beforeEnd)
          const beforeMins = Math.max(beforeWindowMs / 60000, 0.1)
          stint.beforeNetRate = Math.round(((beforeOwnPts - beforeOppPts) / beforeMins) * 10) / 10
        }
      }
    }

    // ═══════════════════════════════════════════════════════════
    // 业余友好效率评分算法（Amateur-Friendly Context-Aware PER）
    // ═══════════════════════════════════════════════════════════
    // 核心思想：
    // 1. 位置加权：不同位置有不同的核心贡献指标
    // 2. 上下文感知：球员贡献占球队得分比例越高，效率越高
    // 3. 无效上场惩罚：球队得分多但球员无贡献 → 轻微扣分
    // 4. 时间补偿：上场时间越长，维持高效率越难，给予适当补偿
    // 5. 业余友好：基础分底薪 + 降低惩罚力度 + 放宽贡献阈值

    const POSITION_WEIGHTS = {
      PG:  { pts: 1.2, reb: 0.8, ast: 1.8, stl: 1.5, blk: 0.5, tov: -0.6, pf: -0.4, fga_miss: -0.4, fta_miss: -0.2 },
      SG:  { pts: 1.5, reb: 0.8, ast: 1.2, stl: 1.2, blk: 0.5, tov: -0.5, pf: -0.4, fga_miss: -0.5, fta_miss: -0.2 },
      SF:  { pts: 1.3, reb: 1.0, ast: 1.1, stl: 1.1, blk: 0.8, tov: -0.5, pf: -0.4, fga_miss: -0.5, fta_miss: -0.2 },
      PF:  { pts: 1.2, reb: 1.5, ast: 0.8, stl: 0.9, blk: 1.2, tov: -0.5, pf: -0.5, fga_miss: -0.4, fta_miss: -0.3 },
      C:   { pts: 1.2, reb: 1.8, ast: 0.6, stl: 0.7, blk: 1.6, tov: -0.4, pf: -0.5, fga_miss: -0.3, fta_miss: -0.3 },
      FLEX:{ pts: 1.2, reb: 1.2, ast: 1.2, stl: 1.2, blk: 1.2, tov: -0.5, pf: -0.4, fga_miss: -0.4, fta_miss: -0.2 }
    }

    // 位置核心指标（用于计算"位置贡献度"）
    const POSITION_FOCUS = {
      PG:  { offense: 'ast', defense: 'stl' },
      SG:  { offense: 'pts', defense: 'stl' },
      SF:  { offense: 'pts', defense: 'reb' },
      PF:  { offense: 'reb', defense: 'blk' },
      C:   { offense: 'reb', defense: 'blk' },
      FLEX:{ offense: 'pts', defense: 'reb' }
    }

    function calcRating(s, pos, minutes, teamPointsGained, oppPointsGained, netEfficiency, beforeNetRate) {
      const w = POSITION_WEIGHTS[pos] || POSITION_WEIGHTS.FLEX
      const fgaMiss = (s.fga || 0) - (s.fgm || 0)
      const ftaMiss = (s.fta || 0) - (s.ftm || 0)

      // 第一步：基础加权分数（个人表现）
      const rawScore =
        (s.pts || 0) * w.pts +
        (s.reb || 0) * w.reb +
        (s.ast || 0) * w.ast +
        (s.stl || 0) * w.stl +
        (s.blk || 0) * w.blk +
        (s.tov || 0) * w.tov +
        (s.pf || 0) * w.pf +
        fgaMiss * w.fga_miss +
        ftaMiss * w.fta_miss

      if (minutes && minutes > 0) {
        // 第二步：上下文感知调整
        let contextBonus = 0

        if (teamPointsGained > 0) {
          // 球员得分占球队得分比例（贡献度）
          const contributionRatio = Math.min((s.pts || 0) / teamPointsGained, 1)
          if (contributionRatio >= 0.20) {
            contextBonus = 1.5  // 核心贡献者
          } else if (contributionRatio >= 0.10) {
            contextBonus = 0.5  // 正常贡献
          } else if (contributionRatio > 0) {
            contextBonus = -0.3  // 贡献偏低
          } else {
            contextBonus = -2.0  // 零贡献惩罚（加大）
          }

          // 位置特色奖励
          const focus = POSITION_FOCUS[pos] || POSITION_FOCUS.FLEX
          const offVal = s[focus.offense] || 0
          const defVal = s[focus.defense] || 0
          const offPerMin = offVal / minutes
          const defPerMin = defVal / minutes
          if (offPerMin >= 0.5) contextBonus += 0.8
          if (defPerMin >= 0.3) contextBonus += 0.5
        } else {
          // 球队没有得分变化
          const defFocus = POSITION_FOCUS[pos]?.defense || 'reb'
          const defVal = s[defFocus] || 0
          if (defVal > 0) {
            contextBonus = 0.3
          } else if (minutes >= 3) {
            contextBonus = -1.5  // 上场较久但无贡献（加大惩罚）
          }
        }

        // 第三步：净效率奖励/惩罚
        let impactBonus = 0
        const netEff = netEfficiency || 0
        const beforeNet = beforeNetRate || 0
        const netImprovement = netEff - beforeNet

        if (netEff > 0) {
          impactBonus += 1.0
          if (netImprovement > 0) {
            impactBonus += Math.min(netImprovement * 0.3, 1.5)
          }
        } else if (netEff < 0) {
          if (netImprovement < 0) {
            impactBonus -= Math.min(Math.abs(netImprovement) * 0.3, 1.0)
          }
          if ((oppPointsGained || 0) > (teamPointsGained || 0) * 1.5) {
            impactBonus -= 0.5
          }
        }

        // 防守型位置（PF/C）额外防守奖励
        if (['PF', 'C'].includes(pos)) {
          if ((oppPointsGained || 0) === 0 && minutes >= 2) {
            impactBonus += 1.0
          }
          const defActions = (s.blk || 0) + (s.stl || 0)
          if (defActions >= 1 && netEff >= 0) {
            impactBonus += 0.8
          }
        }

        // 第四步：时间补偿（减弱衰减：用 minutes^0.7 代替 minutes）
        let timeModifier = 1.0
        if (minutes <= 2) timeModifier = 1.4
        else if (minutes <= 5) timeModifier = 1.2
        else if (minutes >= 15) timeModifier = 0.95

        // 第五步：底薪（有贡献才给，零贡献不给）
        let baseScore = 0
        const hasContribution = (s.pts || 0) > 0 || (s.reb || 0) > 0 || (s.ast || 0) > 0
          || (s.stl || 0) > 0 || (s.blk || 0) > 0
        if (hasContribution) {
          baseScore = 0.5 * minutes
        }

        const finalScore = (rawScore + contextBonus + impactBonus + baseScore) * timeModifier
        // 用 minutes^0.7 减弱时间衰减（长时间上场不会过度稀释评分）
        const adjustedMinutes = Math.pow(minutes, 0.7)
        return Math.round((finalScore / adjustedMinutes) * 10) / 10
      }

      return Math.round(rawScore * 10) / 10
    }

    // 组装教练面板数据（包含球队所有成员，即使没上场也显示）
    const allPlayerIds = [...new Set([
      ...teamPlayerIds,
      ...(allLineup || []).map(l => l.player_id),
      ...(gameStats || []).map(s => s.player_id)
    ])]

    coachPlayers.value = allPlayerIds.map(pid => {
      const pInfo = playerMap[pid] || {}
      const jInfo = jerseyMap[pid] || {}
      const gs = (gameStats || []).find(s => s.player_id === pid) || {}
      const mins = minutesMap[pid] || { total: 0, quarters: {} }
      const stints = stintStatsMap[pid] || []

      // 计算总上场分钟数
      const totalMins = Math.ceil(mins.total / 60)
      // 优先使用教练手动调整的位置
      const pos = coachPositionOverrides.value[pid] || positionMap[pid] || 'FLEX'

      // 按上场阶段计算评分
      const playerLineupData = (allLineup || []).filter(l => l.player_id === pid)
      const stintsData = stints.map((stint, idx) => {
        const stintMins = Math.ceil(stint.duration / 60) || 1
        // 找到对应的 lineup 记录（用于实时更新时间）
        const lineupEntry = playerLineupData.find(l => {
          return new Date(l.on_at).getTime() === new Date(stint.on_at).getTime()
        })
        return {
          stintIndex: idx + 1,
          quarter: stint.quarter,
          minutes: formatSeconds(stint.duration),
          on_at: stint.on_at,
          off_at: stint.off_at,
          ...stint.stats,
          rating: calcRating(stint.stats, pos, stintMins, stint.teamPointsGained, stint.oppPointsGained, stint.netEfficiency, stint.beforeNetRate),
          _lineupEntry: lineupEntry || null
        }
      })

      return {
        player_id: pid,
        team_id: (allLineup || []).find(l => l.player_id === pid)?.team_id
          || gs.team_id
          || jerseyMap[pid]?.team_id,
        name: pInfo.name || '未知',
        avatar_url: pInfo.avatar_url,
        jersey_no: jInfo.jersey_no,
        position: pos,
        totalMinutes: formatSeconds(mins.total),
        _lineupData: playerLineupData,  // 保存引用用于定时器更新
        pts: gs.pts || 0,
        reb: gs.reb || 0,
        ast: gs.ast || 0,
        stl: gs.stl || 0,
        blk: gs.blk || 0,
        tov: gs.tov || 0,
        pf: gs.pf || 0,
        // 全场评分：按各阶段时间加权平均
        rating: 0, // 先设为0，下面组装完 stintsData 后计算
        stints: stintsData
      }
      // 按时间加权计算总评分，返回0时保留原值（暂停时不会误清零）
      const newRating = calcTimeWeightedRating(stintsData)
      const existingPlayer = coachPlayers.value.find(p => p.player_id === pid)
      player.rating = newRating > 0 ? newRating : (existingPlayer?.rating || 0)
      return player
    }).sort((a, b) => b.rating - a.rating)  // 按评分排序
  } catch (e) {
    console.error('加载教练数据失败:', e)
  } finally {
    coachLoading.value = false
  }
}

// 教练手动切换某个上场阶段的位置，只重算该阶段评分
function changeStintPosition(playerId, stintIndex, newPosition) {
  const player = coachPlayers.value.find(p => p.player_id === playerId)
  if (!player) return
  const stint = (player.stints || []).find(s => s.stintIndex === stintIndex)
  if (!stint) return

  // 记录该阶段的位置覆盖
  stint.stintPosition = newPosition

  // 用新位置重算该阶段评分（使用业余友好权重）
  const POSITION_WEIGHTS = {
    PG:  { pts: 1.2, reb: 0.8, ast: 1.8, stl: 1.5, blk: 0.5, tov: -0.6, pf: -0.4, fga_miss: -0.4, fta_miss: -0.2 },
    SG:  { pts: 1.5, reb: 0.8, ast: 1.2, stl: 1.2, blk: 0.5, tov: -0.5, pf: -0.4, fga_miss: -0.5, fta_miss: -0.2 },
    SF:  { pts: 1.3, reb: 1.0, ast: 1.1, stl: 1.1, blk: 0.8, tov: -0.5, pf: -0.4, fga_miss: -0.5, fta_miss: -0.2 },
    PF:  { pts: 1.2, reb: 1.5, ast: 0.8, stl: 0.9, blk: 1.2, tov: -0.5, pf: -0.5, fga_miss: -0.4, fta_miss: -0.3 },
    C:   { pts: 1.2, reb: 1.8, ast: 0.6, stl: 0.7, blk: 1.6, tov: -0.4, pf: -0.5, fga_miss: -0.3, fta_miss: -0.3 },
    FLEX:{ pts: 1.2, reb: 1.2, ast: 1.2, stl: 1.2, blk: 1.2, tov: -0.5, pf: -0.4, fga_miss: -0.4, fta_miss: -0.2 }
  }
  const w = POSITION_WEIGHTS[newPosition] || POSITION_WEIGHTS.FLEX
  const stintMins = Math.ceil(parseInt(stint.minutes) / 60) || 1
  const fgaMiss = (stint.fga || 0) - (stint.fgm || 0)
  const ftaMiss = (stint.fta || 0) - (stint.ftm || 0)
  const raw = (stint.pts||0)*w.pts + (stint.reb||0)*w.reb + (stint.ast||0)*w.ast + (stint.stl||0)*w.stl + (stint.blk||0)*w.blk + (stint.tov||0)*w.tov + (stint.pf||0)*w.pf + fgaMiss*w.fga_miss + ftaMiss*w.fta_miss
  stint.rating = Math.round((raw / stintMins) * 10) / 10

  // 重算全场评分（按时间加权平均）
  const allStints = player.stints || []
  player.rating = calcTimeWeightedRating(allStints)

  // 重新排序
  coachPlayers.value.sort((a, b) => b.rating - a.rating)
}

// 格式化秒数为 mm:ss
function getRatingClass(rating) {
  if (rating >= 15) return 'text-green-400'
  if (rating >= 8) return 'text-yellow-400'
  if (rating >= 0) return 'text-dark-300'
  return 'text-red-400'
}

function formatSeconds(totalSec) {
  const m = Math.floor(totalSec / 60)
  const s = totalSec % 60
  return `${m}:${String(s).padStart(2, '0')}`
}

// watch tab 切换，加载教练数据
watch(activeTab, (val) => {
  if (val === 'coach') {
    // 管理员默认只看自己的队伍
    if (auth.role === 'admin') {
      const uid = auth.user?.id
      if (game.value?.home_team?.owner_id === uid || game.value?.home_team?.created_by === uid) coachTeamFilter.value = game.value.home_team_id
      else if (game.value?.away_team?.owner_id === uid || game.value?.away_team?.created_by === uid) coachTeamFilter.value = game.value.away_team_id
    } else {
      coachTeamFilter.value = 'all'
    }
    loadCoachData()
    // 只有比赛进行中且未暂停才启动定时器，结束后或暂停时数据不变
    if (game.value?.status === 'active' && !game.value.is_paused) {
      startCoachTimer()
    }
  } else {
    stopCoachTimer()
  }
})

// 教练页定时器：实时更新上场时间 + 重算评分
let coachTimer = null

// 从 game 记录获取累计暂停毫秒数（数据库持久化，跨页面可靠）
function getGamePausedMs() {
  const g = game.value
  if (!g) return 0
  let ms = g.total_paused_ms || 0
  // 如果当前暂停中，还要加上从 paused_at 到现在的时长
  if (g.is_paused && g.paused_at) {
    ms += Date.now() - new Date(g.paused_at).getTime()
  }
  return ms
}

function getLineupDurationSec(lineupEntry) {
  if (!lineupEntry) return 0
  const start = new Date(lineupEntry.on_at).getTime()
  const end = lineupEntry.off_at ? new Date(lineupEntry.off_at).getTime() : Date.now()
  // 只对未结束的阶段扣除暂停时间
  let paused = 0
  if (!lineupEntry.off_at) {
    paused = getGamePausedMs()
  }
  return Math.max(0, Math.floor((end - start - paused) / 1000))
}

// 简化版评分函数（供定时器使用，与 changeStintPosition 一致）
const TIMER_POSITION_WEIGHTS = {
  PG:  { pts: 1.2, reb: 0.8, ast: 1.8, stl: 1.5, blk: 0.5, tov: -0.6, pf: -0.4, fga_miss: -0.4, fta_miss: -0.2 },
  SG:  { pts: 1.5, reb: 0.8, ast: 1.2, stl: 1.2, blk: 0.5, tov: -0.5, pf: -0.4, fga_miss: -0.5, fta_miss: -0.2 },
  SF:  { pts: 1.3, reb: 1.0, ast: 1.1, stl: 1.1, blk: 0.8, tov: -0.5, pf: -0.4, fga_miss: -0.5, fta_miss: -0.2 },
  PF:  { pts: 1.2, reb: 1.5, ast: 0.8, stl: 0.9, blk: 1.2, tov: -0.5, pf: -0.5, fga_miss: -0.4, fta_miss: -0.3 },
  C:   { pts: 1.2, reb: 1.8, ast: 0.6, stl: 0.7, blk: 1.6, tov: -0.4, pf: -0.5, fga_miss: -0.3, fta_miss: -0.3 },
  FLEX:{ pts: 1.2, reb: 1.2, ast: 1.2, stl: 1.2, blk: 1.2, tov: -0.5, pf: -0.4, fga_miss: -0.4, fta_miss: -0.2 }
}

function quickRecalcStintRating(stint, pos) {
  const w = TIMER_POSITION_WEIGHTS[pos] || TIMER_POSITION_WEIGHTS.FLEX
  // 解析时间 mm:ss → 分钟数
  const parts = (stint.minutes || '0:00').split(':')
  const stintMins = parseInt(parts[0]) * 60 + parseInt(parts[1] || 0)
  const mins = Math.max(Math.ceil(stintMins / 60), 1)
  const fgaMiss = (stint.fga || 0) - (stint.fgm || 0)
  const ftaMiss = (stint.fta || 0) - (stint.ftm || 0)
  const raw = (stint.pts||0)*w.pts + (stint.reb||0)*w.reb + (stint.ast||0)*w.ast + (stint.stl||0)*w.stl + (stint.blk||0)*w.blk + (stint.tov||0)*w.tov + (stint.pf||0)*w.pf + fgaMiss*w.fga_miss + ftaMiss*w.fta_miss
  // 有贡献才给底薪
  const hasContribution = (stint.pts||0) > 0 || (stint.reb||0) > 0 || (stint.ast||0) > 0 || (stint.stl||0) > 0 || (stint.blk||0) > 0
  const baseScore = hasContribution ? 0.5 * mins : 0
  let timeModifier = 1.0
  if (mins <= 2) timeModifier = 1.4
  else if (mins <= 5) timeModifier = 1.2
  else if (mins >= 15) timeModifier = 0.95
  const finalScore = (raw + baseScore) * timeModifier
  stint.rating = Math.round((finalScore / mins) * 10) / 10
}

// 防抖：避免短时间内多次录入触发过多 loadCoachData
let coachDataDebounce = null
function debouncedLoadCoachData() {
  if (coachDataDebounce) clearTimeout(coachDataDebounce)
  coachDataDebounce = setTimeout(() => {
    if (activeTab.value === 'coach') loadCoachData()
  }, 2000)
}

// 订阅比赛实时更新（暂停状态同步 + 教练数据同步）
function subscribeGameUpdates() {
  if (gameChannel.value) {
    supabase.removeChannel(gameChannel.value)
  }
  gameChannel.value = supabase
    .channel(`game-detail:${gameId}`)
    .on('postgres_changes', {
      event: 'UPDATE',
      schema: 'public',
      table: 'games',
      filter: `id=eq.${gameId}`
    }, (payload) => {
      if (payload.new && game.value) {
        game.value = { ...game.value, ...payload.new }
        // 暂停状态变化时，启停定时器（暂停时间由数据库 total_paused_ms 追踪）
        const newPaused = !!payload.new.is_paused
        if (newPaused) {
          stopCoachTimer()
        } else if (game.value.status === 'active') {
          startCoachTimer()
        }
      }
    })
    // 监听 action_logs 变化（录入端新增操作时触发）- 增量更新
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'action_logs',
      filter: `game_id=eq.${gameId}`
    }, (payload) => {
      if (activeTab.value === 'coach' && payload.new) {
        incrementalUpdatePlayerStats(payload.new)
      }
    })
    // 监听 game_stats 变化（统计数据更新时触发）- 全量刷新（阵容变化较少）
    .on('postgres_changes', {
      event: 'UPDATE',
      schema: 'public',
      table: 'game_stats',
      filter: `game_id=eq.${gameId}`
    }, () => {
      debouncedLoadCoachData()
    })
    // 监听 game_lineup 变化（换人时触发）- 全量刷新（阵容变化较少）
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'game_lineup',
      filter: `game_id=eq.${gameId}`
    }, () => {
      debouncedLoadCoachData()
    })
    .subscribe()
}

// 增量更新球员统计数据（避免全量刷新）
function incrementalUpdatePlayerStats(actionLog) {
  const playerId = actionLog.player_id
  const player = coachPlayers.value.find(p => p.player_id === playerId)
  if (!player || !player.stints) return

  const actionTime = new Date(actionLog.created_at)
  const delta = actionLog.delta || 1

  // 找到包含该 action 的上场阶段
  const stint = player.stints.find(s => {
    if (!s.on_at) return false
    const start = new Date(s.on_at)
    const end = s.off_at ? new Date(s.off_at) : new Date()
    return actionTime >= start && actionTime <= end
  })
  if (!stint) return

  // 更新阶段统计数据
  switch (actionLog.action_type) {
    case 'pts_1':
      stint.pts = (stint.pts || 0) + 1 * delta
      stint.ftm = (stint.ftm || 0) + 1 * delta
      stint.fta = (stint.fta || 0) + 1 * delta
      break
    case 'pts_2':
      stint.pts = (stint.pts || 0) + 2 * delta
      stint.fgm = (stint.fgm || 0) + 1 * delta
      stint.fga = (stint.fga || 0) + 1 * delta
      break
    case 'pts_3':
      stint.pts = (stint.pts || 0) + 3 * delta
      stint.fgm = (stint.fgm || 0) + 1 * delta
      stint.fga = (stint.fga || 0) + 1 * delta
      stint.fg3m = (stint.fg3m || 0) + 1 * delta
      stint.fg3a = (stint.fg3a || 0) + 1 * delta
      break
    case 'reb': stint.reb = (stint.reb || 0) + delta; break
    case 'ast': stint.ast = (stint.ast || 0) + delta; break
    case 'stl': stint.stl = (stint.stl || 0) + delta; break
    case 'blk': stint.blk = (stint.blk || 0) + delta; break
    case 'tov': stint.tov = (stint.tov || 0) + delta; break
    case 'pf': stint.pf = (stint.pf || 0) + delta; break
  }

  // 更新全场统计数据
  player.pts = (player.pts || 0) + (actionLog.action_type === 'pts_1' ? 1 : actionLog.action_type === 'pts_2' ? 2 : actionLog.action_type === 'pts_3' ? 3 : 0) * delta
  if (actionLog.action_type === 'reb') player.reb = (player.reb || 0) + delta
  if (actionLog.action_type === 'ast') player.ast = (player.ast || 0) + delta
  if (actionLog.action_type === 'stl') player.stl = (player.stl || 0) + delta
  if (actionLog.action_type === 'blk') player.blk = (player.blk || 0) + delta
  if (actionLog.action_type === 'tov') player.tov = (player.tov || 0) + delta
  if (actionLog.action_type === 'pf') player.pf = (player.pf || 0) + delta

  // 重新计算该阶段评分
  const pos = stint.stintPosition || player.position || 'FLEX'
  const stintMins = Math.ceil(stint.rawDuration / 60) || 1
  stint.rating = calcRating(stint, pos, stintMins, stint.teamPointsGained || 0, stint.oppPointsGained || 0, stint.netEfficiency || 0, stint.beforeNetRate || 0)

  // 重新计算全场评分
  player.rating = calcTimeWeightedRating(player.stints)

  // 重新排序（可选：如果不需要实时排序可以注释掉）
  coachPlayers.value.sort((a, b) => b.rating - a.rating)
}

// 按时间加权平均计算总评分（直接从 on_at/off_at 计算原始秒数，不依赖暂停追踪）
function calcTimeWeightedRating(stints) {
  if (!stints || stints.length === 0) return 0
  let totalWeightedRating = 0
  let totalSeconds = 0
  for (const stint of stints) {
    let secs = 0
    if (stint.on_at) {
      const start = new Date(stint.on_at).getTime()
      const end = stint.off_at ? new Date(stint.off_at).getTime() : Date.now()
      secs = Math.max(0, Math.floor((end - start) / 1000))
    }
    if (secs <= 0) continue
    totalWeightedRating += (stint.rating || 0) * secs
    totalSeconds += secs
  }
  if (totalSeconds === 0) return 0
  return Math.round((totalWeightedRating / totalSeconds) * 10) / 10
}

function startCoachTimer() {
  stopCoachTimer()
  coachTimer = setInterval(() => {
    if (coachPlayers.value.length === 0) return
    // 暂停时不更新（但仍然保留定时器，恢复后自动继续）
    if (game.value?.is_paused) return
    for (const player of coachPlayers.value) {
      if (!player._lineupData) continue
      // 总上场时间 = 所有阶段有效时长之和
      let totalSec = 0
      for (const l of player._lineupData) {
        totalSec += getLineupDurationSec(l)
      }
      player.totalMinutes = formatSeconds(totalSec)
      // 更新每个阶段的时间并重算评分
      for (const stint of (player.stints || [])) {
        if (stint._lineupEntry) {
          const sec = getLineupDurationSec(stint._lineupEntry)
          stint.minutes = formatSeconds(sec)
          // 用该阶段的位置重算评分
          const pos = stint.stintPosition || player.position || 'FLEX'
          quickRecalcStintRating(stint, pos)
        }
      }
      // 重算全场评分（按时间加权平均）
      const allStints = player.stints || []
      player.rating = calcTimeWeightedRating(allStints)
    }
    // 重新排序
    coachPlayers.value.sort((a, b) => b.rating - a.rating)
  }, 10000)
}
function stopCoachTimer() {
  if (coachTimer) { clearInterval(coachTimer); coachTimer = null }
}

// 组件卸载时清理定时器
onUnmounted(() => {
  stopCoachTimer()
  // 清理实时订阅
  if (gameChannel.value) {
    supabase.removeChannel(gameChannel.value)
    gameChannel.value = null
  }
})

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

    // 订阅比赛实时更新（暂停状态同步等）
    subscribeGameUpdates()

    // 并行获取：两队所有球员 + 本场统计数据 + MVP + 当前场上阵容
    const [tpRes, statsRes, mvpQuery, lineupRes] = await Promise.allSettled([
      supabase.from('team_players')
        .select(`team_id, player_id, jersey_no, position, player:player_id(id, name)`)
        .in('team_id', [gameData.home_team_id, gameData.away_team_id])
        .eq('is_active', true),
      supabase.from('game_stats')
        .select(`*, player:player_id(id, name)`)
        .eq('game_id', gameId),
      supabase.from('game_mvp')
        .select('*, player:player_id(id, name)')
        .eq('game_id', gameId),
      supabase.from('game_lineup')
        .select('player_id, team_id, slot_no, on_at')
        .eq('game_id', gameId)
        .eq('is_current', true)
    ])

    // 当前场上阵容
    if (lineupRes.status === 'fulfilled' && lineupRes.value.data) {
      courtLineup.value = lineupRes.value.data
    }

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
          // 有统计数据：合并球衣号码和位置，同时把 NULL 字段默认为 0
          const normalized = { ...existing }
          for (const f of statFields) {
            if (normalized[f] == null) normalized[f] = 0
          }
          normalized.player = {
            ...existing.player,
            jersey_no: tp.jersey_no,
            // 优先使用球队位置（tp.position），如果没有则保留快照位置（player_position）
            team_position: tp.position || normalized.player_position || ''
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
            player_position: tp.position || '',
            player: {
              id:        tp.player_id,
              name:      tp.player?.name || '未知',
              jersey_no: tp.jersey_no,
              team_position: tp.position || ''
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
/* ── MVP 入场动画 ── */
@keyframes mvpEntrance {
  0% { transform: scale(0.8) translateY(20px); opacity: 0; }
  60% { transform: scale(1.02) translateY(-5px); opacity: 1; }
  100% { transform: scale(1) translateY(0); opacity: 1; }
}
.animate-mvp-entrance {
  animation: mvpEntrance 0.8s ease-out forwards;
}

/* ── MVP 奖杯动画 ── */
@keyframes mvpTrophy {
  0%, 100% { transform: scale(1) rotate(0deg); }
  25% { transform: scale(1.1) rotate(-5deg); }
  75% { transform: scale(1.1) rotate(5deg); }
}
.animate-mvp-trophy {
  animation: mvpTrophy 3s ease-in-out infinite;
}

/* ── MVP 光晕动画 ── */
@keyframes mvpGlow {
  0%, 100% { opacity: 0.3; transform: scale(1); }
  50% { opacity: 0.6; transform: scale(1.1); }
}
.animate-mvp-glow {
  animation: mvpGlow 2s ease-in-out infinite;
}

/* ── MVP 旋转光环 ── */
@keyframes mvpRing1 {
  0% { transform: rotate(0deg); opacity: 0.3; }
  100% { transform: rotate(360deg); opacity: 0.3; }
}
@keyframes mvpRing2 {
  0% { transform: rotate(180deg); opacity: 0.2; }
  100% { transform: rotate(540deg); opacity: 0.2; }
}
@keyframes mvpRing3 {
  0% { transform: rotate(0deg); opacity: 0.15; }
  100% { transform: rotate(-360deg); opacity: 0.15; }
}
.mvp-ring-1 {
  animation: mvpRing1 8s linear infinite;
}
.mvp-ring-2 {
  animation: mvpRing2 12s linear infinite;
}
.mvp-ring-3 {
  animation: mvpRing3 10s linear infinite;
}

/* ── MVP 粒子动画（增强） ── */
@keyframes particleFloatEnhanced {
  0% { transform: translateY(0) translateX(0) scale(1); opacity: 0.3; }
  25% { transform: translateY(-15px) translateX(5px) scale(1.5); opacity: 0.8; }
  50% { transform: translateY(-25px) translateX(-5px) scale(1.2); opacity: 1; }
  75% { transform: translateY(-15px) translateX(8px) scale(1.4); opacity: 0.7; }
  100% { transform: translateY(0) translateX(0) scale(1); opacity: 0.3; }
}
.mvp-particle-1 {
  animation: particleFloatEnhanced 3s ease-in-out infinite;
}
.mvp-particle-2 {
  animation: particleFloatEnhanced 2.5s ease-in-out infinite 0.7s;
}
.mvp-particle-3 {
  animation: particleFloatEnhanced 3.5s ease-in-out infinite 1.2s;
}
.mvp-particle-4 {
  animation: particleFloatEnhanced 4s ease-in-out infinite 0.3s;
}
.mvp-particle-5 {
  animation: particleFloatEnhanced 2.8s ease-in-out infinite 1.5s;
}

/* ── MVP 闪光效果 ── */
@keyframes mvpFlash {
  0%, 100% { opacity: 0; }
  50% { opacity: 0.3; }
}
.mvp-flash {
  animation: mvpFlash 3s ease-in-out infinite;
}
@keyframes mvpFlashReverse {
  0%, 100% { opacity: 0; }
  50% { opacity: 0.2; }
}
.mvp-flash-reverse {
  animation: mvpFlashReverse 4s ease-in-out infinite 1s;
}

/* ── MVP 姓名动画 ── */
@keyframes mvpName {
  0%, 100% { text-shadow: 0 0 10px rgba(250, 204, 21, 0.3); }
  50% { text-shadow: 0 0 20px rgba(250, 204, 21, 0.6), 0 0 40px rgba(249, 115, 22, 0.3); }
}
.animate-mvp-name {
  animation: mvpName 2s ease-in-out infinite;
}

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

/* ── 球员信息固定列 ── */
.sticky-th,
.sticky-player-info {
  position: sticky;
  left: 0;
  z-index: 10;
  background-color: #1a1d2e;
}
.sticky-player-info::after {
  content: '';
  position: absolute;
  top: -1px;
  right: -8px;
  bottom: -1px;
  width: 8px;
  background: linear-gradient(to right, rgba(0,0,0,0.25), transparent);
  pointer-events: none;
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
