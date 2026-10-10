<template>
  <div class="page-container">
    <!-- 返回 + 标题 -->
    <div class="flex items-center gap-3 mb-5">
      <router-link :to="backTo" class="text-dark-500 hover:text-white transition-colors p-1 flex-shrink-0">
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
    <div v-if="canRecord || auth.canScreen" class="flex gap-2 mb-5">
      <router-link v-if="canRecord" :to="`/games/${gameId}/record`"
        class="btn-accent btn-sm flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
        </svg>
        进入录入
      </router-link>
      <!-- 大屏模式（投屏权限） -->
      <button v-if="auth.canScreen && game"
        @click="screenMode = true"
        class="btn-primary btn-sm flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        大屏模式
      </button>
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
      <router-link :to="backTo" class="btn-primary btn-sm">返回赛事列表</router-link>
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
              <div class="relative inline-block max-w-full">
                <p class="font-black tabular-nums leading-none"
                  :class="scoreClass(game.home_score)"
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
              <!-- 下次球权提示（realtime 自动同步录入端的设置） -->
              <div v-if="game.possession_home != null"
                class="mt-2 px-3 py-1 rounded-full border text-[10px] font-bold flex items-center gap-1.5 whitespace-nowrap"
                :style="possessionStyle">
                <span class="text-sm leading-none">{{ game.possession_home ? '◀' : '▶' }}</span>
                <span>下次球权：{{ possessionTeamName }}</span>
              </div>
            </div>

            <!-- 客队 -->
            <div class="flex-1 text-center">
              <p class="text-sm font-bold mb-3 truncate px-2 tracking-wide"
                :style="{ color: awayColor }">
                {{ game.away_team?.name || '客队' }}
              </p>
              <div class="relative inline-block max-w-full">
                <p class="font-black tabular-nums leading-none"
                  :class="scoreClass(game.away_score)"
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
      <Teleport to="body" :disabled="!landscapeStats">
      <div v-show="activeTab === 'stats'" class="card mb-4"
        :class="landscapeStats ? (landscapeRotated ? 'landscape-overlay is-rotated' : 'landscape-overlay') : ''"
        :style="landscapeStats ? { width: landscapeStage.w + 'px', height: landscapeStage.h + 'px' } : undefined">
        <div class="card-header flex items-center justify-between gap-2">
          <div class="flex items-center gap-2 min-w-0">
            <h2 class="font-semibold text-white whitespace-nowrap">球员数据</h2>
            <span v-if="landscapeStats && landscapeRotated" class="text-[10px] text-dark-500 whitespace-nowrap">↻ 横握手机查看</span>
          </div>
          <div class="flex items-center gap-2">
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
            <!-- 手机端横屏全屏 -->
            <button v-if="!landscapeStats && !editMode" @click="openLandscapeStats"
              class="md:hidden px-2.5 py-1 rounded-lg text-xs font-semibold whitespace-nowrap
                     bg-primary-600/20 text-primary-300 border border-primary-500/40 active:scale-95">
              ⛶ 横屏
            </button>
            <button v-if="landscapeStats" @click="closeLandscapeStats"
              class="px-2.5 py-1 rounded-lg text-xs font-semibold whitespace-nowrap
                     bg-red-500/20 text-red-300 border border-red-500/40 active:scale-95">
              ✕ 退出横屏
            </button>
          </div>
        </div>

        <div class="stats-table-container">
          <table class="w-full" style="min-width: 620px;">
            <thead class="stats-table-header">
              <tr class="border-b border-dark-700/50">
                <!-- 评分列移到最左侧并固定（仅比赛结束后显示） -->
                <th v-if="game?.status === 'finished'" class="px-2 py-2.5 text-center text-xs font-bold uppercase tracking-wider whitespace-nowrap rating-col-header sticky-rating"
                    style="min-width: 48px; position: sticky; left: 0; z-index: 13; background: #1a1d2e;">评分</th>
                <th class="sticky-th text-left px-2 py-2.5 text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    :style="{ 'min-width': '90px', 'position': 'sticky', 'left': game?.status === 'finished' ? '48px' : '0', 'z-index': '12', 'background': '#1a1d2e' }">球员</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 44px;">得分</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 44px;">篮板</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 44px;">助攻</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 44px;">抢断</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 44px;">盖帽</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 44px;">犯规</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 60px;">2分%</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 60px;">3分%</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 60px;">罚球%</th>
                <th class="px-2 py-2.5 text-center text-xs font-bold text-dark-200 uppercase tracking-wider whitespace-nowrap"
                    style="min-width: 44px;">失误</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-dark-700/30">

              <!-- ── 主队区块 ── -->
              <template v-if="teamFilter !== 'away'">
                <!-- 主队标题行（仅全队模式显示） -->
                <tr v-if="teamFilter === 'all' && getTeamStats('home').length"
                  class="bg-dark-800/50">
                  <td colspan="12" class="px-3 py-1.5">
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: homeColor }"></div>
                      <span class="text-[11px] font-bold" :style="{ color: homeColor }">{{ game.home_team?.name }}</span>
                      <span class="text-[10px] text-dark-600">主队 · {{ game.home_score }} 分</span>
                    </div>
                  </td>
                </tr>
                <!-- 主队球员行 -->
                <tr v-for="stat in getTeamStats('home')" :key="stat.player_id"
                  class="hover:bg-dark-800/40 transition-all duration-200 text-xs cursor-pointer"
                  :class="[
                    isOnCourt(stat.player_id) ? 'bg-green-500/[0.04]' : '',
                    selectedPlayerId === stat.player_id ? 'bg-primary-600/30 ring-1 ring-primary-500/50 shadow-[0_0_15px_rgba(59,130,246,0.3)]' : ''
                  ]"
                  @click="selectedPlayerId = selectedPlayerId === stat.player_id ? null : stat.player_id">
                  <!-- 评分（移到最左侧并固定，仅比赛结束后显示） -->
                  <td v-if="game?.status === 'finished'" class="px-2 py-1.5 text-center sticky-rating-cell">
                    <template v-if="game?.status === 'finished'">
                      <div v-if="getPlayerRatingInfo(stat.player_id)" class="rating-badge" :class="getPlayerRatingInfo(stat.player_id).tier.cssClass"
                        :style="{
                          '--rating-color': getPlayerRatingInfo(stat.player_id).tier.color,
                          '--rating-shadow': getPlayerRatingInfo(stat.player_id).tier.shadow,
                          '--rating-text': getPlayerRatingInfo(stat.player_id).tier.textColor
                        }">
                        <span class="rating-grade">{{ getPlayerRatingInfo(stat.player_id).tier.grade }}</span>
                        <span class="rating-score">{{ getPlayerRatingInfo(stat.player_id).score.toFixed(1) }}</span>
                      </div>
                      <span v-else class="text-dark-600 text-[10px]">-</span>
                    </template>
                  </td>
                  <!-- 球员信息（固定列） -->
                  <td class="sticky-player-info px-2 py-1.5" :style="{ 'position': 'sticky', 'left': game?.status === 'finished' ? '48px' : '0' }">
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
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('fg2_pct', stat, 'home') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].fg2m" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fg2a" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ fg2Pct(stat) }}</span>
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
                  <!-- 罚球命中率 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('ft_pct', stat, 'home') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].ftm" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fta" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ ftPct(stat) }}</span>
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
                  <td colspan="12" class="px-3 py-1.5">
                    <div class="flex items-center gap-2">
                      <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: awayColor }"></div>
                      <span class="text-[11px] font-bold" :style="{ color: awayColor }">{{ game.away_team?.name }}</span>
                      <span class="text-[10px] text-dark-600">客队 · {{ game.away_score }} 分</span>
                    </div>
                  </td>
                </tr>
                <!-- 客队球员行 -->
                <tr v-for="stat in getTeamStats('away')" :key="stat.player_id"
                  class="hover:bg-dark-800/40 transition-all duration-200 text-xs cursor-pointer"
                  :class="[
                    isOnCourt(stat.player_id) ? 'bg-green-500/[0.04]' : '',
                    selectedPlayerId === stat.player_id ? 'bg-primary-600/30 ring-1 ring-primary-500/50 shadow-[0_0_15px_rgba(59,130,246,0.3)]' : ''
                  ]"
                  @click="selectedPlayerId = selectedPlayerId === stat.player_id ? null : stat.player_id">
                  <!-- 评分（移到最左侧并固定，仅比赛结束后显示） -->
                  <td v-if="game?.status === 'finished'" class="px-2 py-1.5 text-center sticky-rating-cell">
                    <template v-if="game?.status === 'finished'">
                      <div v-if="getPlayerRatingInfo(stat.player_id)" class="rating-badge" :class="getPlayerRatingInfo(stat.player_id).tier.cssClass"
                        :style="{
                          '--rating-color': getPlayerRatingInfo(stat.player_id).tier.color,
                          '--rating-shadow': getPlayerRatingInfo(stat.player_id).tier.shadow,
                          '--rating-text': getPlayerRatingInfo(stat.player_id).tier.textColor
                        }">
                        <span class="rating-grade">{{ getPlayerRatingInfo(stat.player_id).tier.grade }}</span>
                        <span class="rating-score">{{ getPlayerRatingInfo(stat.player_id).score.toFixed(1) }}</span>
                      </div>
                      <span v-else class="text-dark-600 text-[10px]">-</span>
                    </template>
                  </td>
                  <!-- 球员信息（固定列） -->
                  <td class="sticky-player-info px-2 py-1.5" :style="{ 'position': 'sticky', 'left': game?.status === 'finished' ? '48px' : '0' }">
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
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('fg2_pct', stat, 'away') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].fg2m" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fg2a" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ fg2Pct(stat) }}</span>
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
                  <!-- 罚球命中率 -->
                  <td class="px-2 py-2 text-center" :class="editMode ? '' : (isTopInColForTeam('ft_pct', stat, 'away') ? 'top-value' : 'text-dark-500')">
                    <template v-if="editMode">
                      <input v-model.number="editData[stat.player_id].ftm" type="number" min="0" placeholder="中"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                      <span class="text-dark-600">/</span>
                      <input v-model.number="editData[stat.player_id].fta" type="number" min="0" placeholder="投"
                        class="w-8 bg-dark-800 border border-dark-600 rounded px-1 py-0.5 text-center text-[10px] text-white" />
                    </template>
                    <span v-else>{{ ftPct(stat) }}</span>
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
                <td colspan="12" class="text-center py-8 text-dark-500 text-xs">暂无数据</td>
              </tr>
              <tr v-if="teamFilter === 'home' && getTeamStats('home').length === 0">
                <td colspan="12" class="text-center py-6 text-dark-500 text-xs">暂无主队数据</td>
              </tr>
              <tr v-if="teamFilter === 'away' && getTeamStats('away').length === 0">
                <td colspan="12" class="text-center py-6 text-dark-500 text-xs">暂无客队数据</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- 图例 -->
        <div class="px-4 py-2 border-t border-dark-700/30 flex flex-wrap gap-3 text-[10px] text-dark-600">
          <span><span class="text-orange-400 font-bold">高亮</span> 队内最高</span>
          <span><span class="text-warning">3+</span> / <span class="text-danger">5+</span> 犯规预警</span>
          <span><span class="text-dark-400">-</span> 无出手记录</span>
          <span v-if="game?.status === 'finished' && Object.keys(playerRatings).length > 0">
            <span class="inline-flex items-center gap-1">
              <span class="rating-badge" style="--rating-color: #FF4500; --rating-shadow: rgba(255,69,0,0.7); --rating-text: #FFF; padding: 0 4px;">
                <span class="rating-grade">SS</span>
              </span>
              ~
              <span class="rating-badge" style="--rating-color: #696969; --rating-shadow: rgba(105,105,105,0.3); --rating-text: #CCC; padding: 0 4px;">
                <span class="rating-grade">D</span>
              </span>
              综合评分
            </span>
          </span>
        </div>
      </div>
      </Teleport>

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
            class="card p-3 border transition-colors duration-300"
            :class="isOnCourt(p.player_id)
              ? 'border-green-500/40 bg-green-500/[0.07] border-l-2 border-l-green-500'
              : 'border-dark-700/30 bg-dark-800/30 opacity-70'">
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
            <div class="grid grid-cols-6 gap-1 mb-2">
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
                  <div class="flex-1 flex gap-1.5 flex-wrap">
                    <span class="text-dark-400">{{ s.pts }}分</span>
                    <span class="text-dark-500">{{ s.reb }}板</span>
                    <span class="text-dark-500">{{ s.ast }}助</span>
                    <span v-if="s.stl" class="text-dark-600">{{ s.stl }}断</span>
                    <span v-if="s.blk" class="text-dark-600">{{ s.blk }}帽</span>
                    <span v-if="s.tov" class="text-red-400/60">{{ s.tov }}误</span>
                    <span class="text-dark-600">{{ stintFg2(s) }}</span>
                    <span v-if="s.fg3m > 0 || s.fg3a > 0" class="text-dark-600">{{ stintFg3(s) }}</span>
                    <span v-if="s.ftm > 0 || s.fta > 0" class="text-dark-600">{{ stintFt(s) }}</span>
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
            class="card p-3 border transition-colors duration-300"
            :class="isOnCourt(p.player_id)
              ? 'border-green-500/40 bg-green-500/[0.07] border-l-2 border-l-green-500'
              : 'border-dark-700/30 bg-dark-800/30 opacity-70'">
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
                  <div class="flex-1 flex gap-1.5 flex-wrap">
                    <span class="text-dark-400">{{ s.pts }}分</span>
                    <span class="text-dark-500">{{ s.reb }}板</span>
                    <span class="text-dark-500">{{ s.ast }}助</span>
                    <span v-if="s.stl" class="text-dark-600">{{ s.stl }}断</span>
                    <span v-if="s.blk" class="text-dark-600">{{ s.blk }}帽</span>
                    <span v-if="s.tov" class="text-red-400/60">{{ s.tov }}误</span>
                    <span class="text-dark-600">{{ stintFg2(s) }}</span>
                    <span v-if="s.fg3m > 0 || s.fg3a > 0" class="text-dark-600">{{ stintFg3(s) }}</span>
                    <span v-if="s.ftm > 0 || s.fta > 0" class="text-dark-600">{{ stintFt(s) }}</span>
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
            class="card p-3 border transition-colors duration-300"
            :class="isOnCourt(p.player_id)
              ? 'border-green-500/40 bg-green-500/[0.07] border-l-2 border-l-green-500'
              : 'border-dark-700/30 bg-dark-800/30 opacity-70'">
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

    <!-- 大屏展示模式（仅投屏权限用户可见入口） -->
    <ScreenDisplay v-if="screenMode && game"
      :game="game"
      :stats="stats"
      :team-fouls="teamFouls"
      :court-lineup="courtLineup"
      @close="screenMode = false"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useGameStore } from '@/stores/game'
import { supabase } from '@/utils/supabase'
import { GAME_STATUS_LABELS, getInitials, fmtDateTime, quarterLabel } from '@/utils/helpers'
import { POSITION_WEIGHTS, POSITION_FOCUS } from '@/utils/efficiency'
import { useTeamFouls } from '@/composables/useTeamFouls'
import ScreenDisplay from '@/components/game/ScreenDisplay.vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const gameStore = useGameStore()
const gameId = route.params.id

// 返回目标：优先 from 参数（如从锦标赛进入则回锦标赛），否则赛事列表
const backTo = computed(() => {
  const from = route.query.from
  return typeof from === 'string' && from.startsWith('/') ? from : '/games'
})

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

// 缓存：观众数据查询结果，供教练数据复用
const cachedTeamPlayers = ref(null)  // team_players 查询结果
const cachedGameStats = ref(null)    // game_stats 查询结果

const editMode = ref(false)
const saving = ref(false)
const editData = ref({})
const selectedPlayerId = ref(null) // 数据统计表点击高亮的球员ID

// ── 大屏展示模式（投屏权限用户） ──
const screenMode = ref(false)

// ── 下次球权提示（VS 比分板中央展示） ──
const possessionTeamName = computed(() => {
  const g = game.value
  if (!g || g.possession_home == null) return ''
  const t = g.possession_home ? g.home_team : g.away_team
  return t?.short_name || t?.name || (g.possession_home ? '主队' : '客队')
})
const possessionStyle = computed(() => {
  const g = game.value
  if (!g || g.possession_home == null) return {}
  const color = g.possession_home ? (g.home_team?.color || '#ffffff') : (g.away_team?.color || '#ffffff')
  return { color, borderColor: color + '99', backgroundColor: color + '1a' }
})

// ── 队伍犯规（本节，与录入页共用逻辑，供大屏展示） ──
const { teamFouls, loadTeamFouls } = useTeamFouls(() => game.value, gameId)
let foulsDebounce = null
function debouncedLoadFouls() {
  clearTimeout(foulsDebounce)
  foulsDebounce = setTimeout(loadTeamFouls, 600)
}

// ── 超管编辑功能 ──
const statEditFields = ['pts', 'reb', 'ast', 'stl', 'blk', 'pf', 'tov', 'fg2m', 'fg2a', 'fg3m', 'fg3a', 'ftm', 'fta']

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

// ── 手机端横屏全屏查看球员数据 ──
// 竖屏时旋转90°模拟横屏（表格620px宽正好铺满手机高度方向）；物理横屏时直接铺满全屏
const landscapeStats = ref(false)
const landscapeRotated = ref(false)
const landscapeStage = ref({ w: 0, h: 0 })

function updateLandscapeStage() {
  const rotated = window.innerHeight > window.innerWidth
  landscapeRotated.value = rotated
  landscapeStage.value = rotated
    ? { w: window.innerHeight, h: window.innerWidth }
    : { w: window.innerWidth, h: window.innerHeight }
}

function openLandscapeStats() {
  updateLandscapeStage()
  landscapeStats.value = true
  document.body.style.overflow = 'hidden'
  window.addEventListener('resize', updateLandscapeStage)
}

function closeLandscapeStats() {
  landscapeStats.value = false
  document.body.style.overflow = ''
  window.removeEventListener('resize', updateLandscapeStage)
}

function teamColor(side) {
  return side === 'home' ? homeColor.value : awayColor.value
}

// 比分字号按位数自适应：三位数缩小，避免手机端溢出屏幕
function scoreClass(score) {
  return String(score ?? 0).length >= 3 ? 'text-5xl sm:text-6xl' : 'text-7xl'
}

// 按队伍过滤
function getTeamStats(side) {
  const teamId = side === 'home' ? game.value?.home_team_id : game.value?.away_team_id
  return stats.value.filter(s => s.team_id === teamId)
}

// MVP PER 评分算法（与教练面板一致）
const MVP_POSITION_WEIGHTS = {
  PG:  { pts: 0.9, reb: 0.9, ast: 1.8, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  SG:  { pts: 1.2, reb: 1.0, ast: 1.3, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  SF:  { pts: 1.1, reb: 1.2, ast: 1.1, stl: 1.0, blk: 0.9, tov: -0.8, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  PF:  { pts: 1.0, reb: 1.5, ast: 0.9, stl: 0.9, blk: 1.3, tov: -0.7, pf: -0.6, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  C:   { pts: 1.0, reb: 1.8, ast: 0.7, stl: 0.7, blk: 1.6, tov: -0.6, pf: -0.6, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  FLEX:{ pts: 1.0, reb: 1.2, ast: 1.2, stl: 1.0, blk: 1.0, tov: -0.7, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 }
}

function calcMvpRating(s, pos) {
  const w = MVP_POSITION_WEIGHTS[pos] || MVP_POSITION_WEIGHTS.FLEX
  const fg2Miss = (s.fg2a || 0) - (s.fg2m || 0)
  const fg3Miss = (s.fg3a || 0) - (s.fg3m || 0)
  const ftMiss = (s.fta || 0) - (s.ftm || 0)
  return Math.round((
    (s.pts || 0) * w.pts +
    (s.reb || 0) * w.reb +
    (s.ast || 0) * w.ast +
    (s.stl || 0) * w.stl +
    (s.blk || 0) * w.blk +
    (s.tov || 0) * w.tov +
    (s.pf || 0) * w.pf +
    fg2Miss * w.fg2_miss +
    fg3Miss * w.fg3_miss +
    ftMiss * w.ft_miss
  ) * 10) / 10
}

// ════════════════════════════════════════════════════════════
// 球员评分系统（0-16分，王者荣耀风格，SS-D等级）
// ════════════════════════════════════════════════════════════

// 各位置的权重因子（与MVP评分共用位置权重）
function calcRawPlayerScore(s, pos) {
  const w = MVP_POSITION_WEIGHTS[pos] || MVP_POSITION_WEIGHTS.FLEX
  const fg2Miss = (s.fg2a || 0) - (s.fg2m || 0)
  const fg3Miss = (s.fg3a || 0) - (s.fg3m || 0)
  const ftMiss = (s.fta || 0) - (s.ftm || 0)
  return (
    (s.pts || 0) * w.pts +
    (s.reb || 0) * w.reb +
    (s.ast || 0) * w.ast +
    (s.stl || 0) * w.stl +
    (s.blk || 0) * w.blk +
    (s.tov || 0) * w.tov +
    (s.pf || 0) * w.pf +
    fg2Miss * w.fg2_miss +
    fg3Miss * w.fg3_miss +
    ftMiss * w.ft_miss
  )
}

// 命中率加成（仅奖励高效、惩罚极低效，避免与基础投丢惩罚重复）
function calcShootingBonus(s) {
  let bonus = 0
  // 2分命中率加成（至少出手5次以上才计算，只奖励高效）
  const fg2a = s.fg2a || 0
  if (fg2a >= 5) {
    const fg2pct = (s.fg2m || 0) / fg2a
    if (fg2pct >= 0.65) bonus += 1.5
    else if (fg2pct >= 0.55) bonus += 0.8
    else if (fg2pct < 0.25) bonus -= 0.5
  }
  // 3分命中率加成（至少出手4次以上，只奖励高效）
  const fg3a = s.fg3a || 0
  if (fg3a >= 4) {
    const fg3pct = (s.fg3m || 0) / fg3a
    if (fg3pct >= 0.5) bonus += 2
    else if (fg3pct >= 0.38) bonus += 1
    else if (fg3pct < 0.2) bonus -= 0.5
  }
  // 罚球命中率加成（至少出手4次）
  const fta = s.fta || 0
  if (fta >= 4) {
    const ftpct = (s.ftm || 0) / fta
    if (ftpct >= 0.9) bonus += 1
    else if (ftpct >= 0.8) bonus += 0.5
    else if (ftpct < 0.4) bonus -= 0.5
  }
  return bonus
}

// 球员评分等级定义（6个等级：SS / S / A / B / C / D）
// 颜色方案：SS金橙、S紫红、A蓝、B绿、C灰蓝、D暗灰
const RATING_TIERS = [
  { min: 14,   grade: 'SS', cssClass: 'rating-ss', label: '绝世',   color: '#FF8C00', shadow: 'rgba(255,140,0,0.8)',   textColor: '#FFF' },
  { min: 11,   grade: 'S',  cssClass: 'rating-s',  label: '卓越',   color: '#E040FB', shadow: 'rgba(224,64,251,0.7)',  textColor: '#FFF' },
  { min: 8,    grade: 'A',  cssClass: 'rating-a',  label: '优秀',   color: '#448AFF', shadow: 'rgba(68,138,255,0.6)',  textColor: '#FFF' },
  { min: 5,    grade: 'B',  cssClass: 'rating-b',  label: '良好',   color: '#00E676', shadow: 'rgba(0,230,118,0.5)',   textColor: '#FFF' },
  { min: 2,    grade: 'C',  cssClass: 'rating-c',  label: '一般',   color: '#78909C', shadow: 'rgba(120,144,156,0.4)', textColor: '#FFF' },
  { min: 0,    grade: 'D',  cssClass: 'rating-d',  label: '需努力', color: '#546E7A', shadow: 'rgba(84,110,122,0.3)',  textColor: '#B0BEC5' },
]

function getGradeFromScore(score) {
  for (const tier of RATING_TIERS) {
    if (score >= tier.min) return tier
  }
  return RATING_TIERS[RATING_TIERS.length - 1]
}

// 评分算法说明（非线性，越往上越难）：
// 1. 基础分 = 位置加权得分（正负值）
// 2. 命中率加成（-2 ~ +6分）
// 3. 根据比赛类型使用不同的理论满分基准：
//    - 娱乐制（打到120/150分）：数据膨胀，基准高 → MAX=50
//      rawScore=10→5.3, 20→8.7, 30→11.5, 40→13.8, 50→16
//    - 正式制（4节不停表）：数据紧凑，基准低 → MAX=25
//      rawScore=5→5.5, 10→8.3, 15→10.7, 20→12.8, 25→16
// 4. 公式：score = 16 * (rawScore / MAX)^0.65
// 5. 无保底，最低0分，封顶16分

// 娱乐制理论满分（个人可能20-40分，加权后可达50+，调高门槛避免SS太容易）
const ENTERTAINMENT_MAX_RAW = 60
// 正式制理论满分（个人一般8-20分，加权后约25，调高门槛让高分更难）
const OFFICIAL_MAX_RAW = 30

function calcPlayerScore(rawScore, gameType) {
  // 根据比赛类型选择基准
  const maxRaw = gameType === 'official' ? OFFICIAL_MAX_RAW : ENTERTAINMENT_MAX_RAW
  
  // 非线性映射：指数 < 1，让高分更难获得
  let ratio = rawScore / maxRaw
  
  // 限制范围 0-1
  ratio = Math.min(1, Math.max(0, ratio))
  
  // 指数变换（0.65让高分段更陡峭）
  let normalized = 16 * Math.pow(ratio, 0.65)
  
  // 封顶16分，最低0分（无保底）
  normalized = Math.min(16, Math.max(0, normalized))
  
  // 保留1位小数
  const finalScore = Math.round(normalized * 10) / 10
  const tier = getGradeFromScore(finalScore)
  return { score: finalScore, tier }
}

// 计算所有球员的评分
const playerRatings = computed(() => {
  if (!game.value || game.value.status !== 'finished') return {}
  const gameType = game.value.game_type || 'entertainment'
  const result = {}
  for (const stat of stats.value) {
    const pos = stat.player?.team_position || stat.player_position || 'FLEX'
    const baseScore = calcRawPlayerScore(stat, pos)
    const shootingBonus = calcShootingBonus(stat)
    const rawScore = baseScore + shootingBonus
    result[stat.player_id] = calcPlayerScore(rawScore, gameType)
  }
  return result
})

function getPlayerRatingInfo(playerId) {
  return playerRatings.value[playerId] || null
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
// 2分命中率
function fg2Pct(stat) {
  const made = (stat.fg2m || 0)
  const attempted = (stat.fg2a || 0)
  if (attempted === 0) return '-'
  return `${made}/${attempted} ${(made / attempted * 100).toFixed(0)}%`
}

// 3分命中率（独立计算）
function fg3Pct(stat) {
  const made = (stat.fg3m || 0)
  const attempted = (stat.fg3a || 0)
  if (attempted === 0) return '-'
  return `${made}/${attempted} ${(made / attempted * 100).toFixed(0)}%`
}

// 罚球命中率（独立计算）
function ftPct(stat) {
  const made = (stat.ftm || 0)
  const attempted = (stat.fta || 0)
  if (attempted === 0) return '-'
  return `${made}/${attempted} ${(made / attempted * 100).toFixed(0)}%`
}

// stint 命中率显示
function stintFg2(s) {
  const made = s.fg2m || 0
  const attempted = s.fg2a || 0
  if (attempted === 0) return ''
  return '2P:' + Math.round(made / attempted * 100) + '%'
}
function stintFg3(s) {
  const made = s.fg3m || 0
  const attempted = s.fg3a || 0
  if (attempted === 0) return ''
  return '3P:' + Math.round(made / attempted * 100) + '%'
}
function stintFt(s) {
  const made = s.ftm || 0
  const attempted = s.fta || 0
  if (attempted === 0) return ''
  return 'FT:' + Math.round(made / attempted * 100) + '%'
}

// 用于比较的数值（'-' 视为 -1）
function fg2PctVal(stat) {
  const made = (stat.fg2m || 0)
  const attempted = (stat.fg2a || 0)
  if (attempted === 0) return -1
  return made / attempted
}
function fg3PctVal(stat) {
  const made = (stat.fg3m || 0)
  const attempted = (stat.fg3a || 0)
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
    fg2_pct: Math.max(...d.map(s => fg2PctVal(s))),
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
    fg2_pct: s => fg2PctVal(s),
    fg3_pct: s => fg3PctVal(s),
  }
  return (getVal[col]?.(stat) || 0) === tv[col]
}

function isMvpRow(stat) {
  return mvpWinner.value && stat.player_id === mvpWinner.value.player_id && game.value?.status === 'finished'
}

// 判断球员是否当前在场上
// 固定排序：上场球员优先，备战席在后，各自内部按球衣号/名字固定（不因数据变化重排）
function stableSortCoachPlayers(players) {
  return [...players].sort((a, b) => {
    const aOn = a._lineupData?.some(l => !l.off_at) ? 0 : 1
    const bOn = b._lineupData?.some(l => !l.off_at) ? 0 : 1
    if (aOn !== bOn) return aOn - bOn
    // 同组内按球衣号排序，无号码按名字
    const aNum = (a.jersey_no && !isNaN(a.jersey_no)) ? parseInt(a.jersey_no) : 999
    const bNum = (b.jersey_no && !isNaN(b.jersey_no)) ? parseInt(b.jersey_no) : 999
    if (aNum !== bNum) return aNum - bNum
    return (a.name || '').localeCompare(b.name || '')
  })
}

function isOnCourt(playerId) {
  return courtLineup.value.some(l => l.player_id === playerId)
}

// Tab 配置
const detailTabs = computed(() => {
  const tabs = [{ key: 'stats', label: '📊 数据统计' }]
  // 教练视角：比赛进行中或已结束时所有人可见
  if (['active', 'finished'].includes(game.value?.status)) {
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
  { key: 'tov', label: '失误' }
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
  const t0 = Date.now()
  coachLoading.value = true
  try {
    const teamIds = [game.value.home_team_id, game.value.away_team_id]
    
    // 辅助函数：合并同一球员在 game_stats 中的所有记录
    const gsData = cachedGameStats.value || []
    function sumStat(playerId, field) {
      let total = 0
      for (const row of gsData) {
        if (row.player_id === playerId) total += (row[field] || 0)
      }
      return total
    }
    
    // 优化：只查询观众数据没有的数据（game_lineup全部、action_logs、players）
    // game_stats 和 team_players 复用观众数据的缓存
    const [lineupRes, actionRes] = await Promise.all([
      supabase.from('game_lineup')
        .select('id, player_id, team_id, slot_no, quarter, on_at, off_at, paused_ms_at_on, paused_ms_at_off')
        .eq('game_id', gameId)
        .order('on_at', { ascending: true }),
      supabase.from('action_logs')
        .select('player_id, team_id, action_type, delta, quarter, created_at')
        .eq('game_id', gameId)
        .eq('is_voided', false)
    ])
    console.log('[loadCoachData] 查询完成(2个并行), 耗时:', Date.now() - t0, 'ms')

    const allLineup = lineupRes.data
    if (lineupRes.error) throw lineupRes.error
    const actionLogs = actionRes.data
    if (actionRes.error) throw actionRes.error
    
    // 复用缓存的 game_stats 和 team_players
    const gameStats = cachedGameStats.value || []
    const tpData = cachedTeamPlayers.value || []

    let jerseyMap = {}
    let positionMap = {}
    if (tpData) {
      jerseyMap = Object.fromEntries(tpData.map(t => [t.player_id, t]))
      positionMap = Object.fromEntries(tpData.map(t => [t.player_id, t.position]))
    }

    // 查询 players（这个无法避免，但可以和前两个并行）
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

      // 原始时长：统一公式（比赛时间域内计时，赛前上场从 started_at 起算）
      const rawDuration = calcStintSec(l)
      stintsMap[l.player_id].push({
        quarter: q,
        on_at: l.on_at,
        off_at: l.off_at || null,
        duration,           // 扣除暂停后的时长（用于显示）
        rawDuration,        // 累加式计时初始值
        team_id: l.team_id,
        lineup_id: l.id     // 用 id 匹配 _lineupEntry，替代时间戳比较
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
        lineup_id: stint.lineup_id,   // 传递 lineup_id，用于精确匹配 _lineupEntry
        on_at: stint.on_at,
        off_at: stint.off_at,
        teamPointsGained: 0,      // 该阶段己方球队总得分
        oppPointsGained: 0,       // 该阶段对方球队总得分
        netEfficiency: 0,         // 净效率（己方 - 对方，每分钟）
        beforeNetRate: 0,         // 上场前净得分速率（每分钟）
        stats: { pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0, fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0, ftm: 0, fta: 0 }
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
        case 'pts_2': stint.stats.pts += 2 * d; stint.stats.fg2m += 1 * d; stint.stats.fg2a += 1 * d; break
        case 'pts_3': stint.stats.pts += 3 * d; stint.stats.fg2m += 1 * d; stint.stats.fg2a += 1 * d; stint.stats.fg3m += 1 * d; stint.stats.fg3a += 1 * d; break
        case 'reb': stint.stats.reb += d; break
        case 'ast': stint.stats.ast += d; break
        case 'stl': stint.stats.stl += d; break
        case 'blk': stint.stats.blk += d; break
        case 'tov': stint.stats.tov += d; break
        case 'pf': stint.stats.pf += d; break
        case 'fga_miss': stint.stats.fg2a += d; break
        case 'fg3a_miss': stint.stats.fg3a += d; break
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

    // 位置权重 / 位置核心指标由 @/utils/efficiency 统一提供（与大屏高效榜同源）

    function calcRating(s, pos, minutes, teamPointsGained, oppPointsGained, netEfficiency, beforeNetRate) {
      const w = POSITION_WEIGHTS[pos] || POSITION_WEIGHTS.FLEX
      const fgaMiss = (s.fg2a || 0) - (s.fg2m || 0)
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

        // 净效率防守奖励（所有位置）
        if ((oppPointsGained || 0) === 0 && minutes >= 2) {
          impactBonus += 1.0
        }
        const defActions = (s.blk || 0) + (s.stl || 0)
        if (defActions >= 1 && netEff >= 0) {
          impactBonus += 0.8
        }

        // 第四步：时间补偿（减弱衰减）
        let timeModifier = 1.0
        if (minutes <= 2) timeModifier = 1.3
        else if (minutes <= 5) timeModifier = 1.15
        else if (minutes >= 15) timeModifier = 0.97

        // 第五步：去除底薪

        const finalScore = (rawScore + contextBonus + impactBonus) * timeModifier
        // 正分除以 minutes^0.4（温和衰减），负分乘以 minutes^0.3
        let rating
        // 时间衰减指数 0.2：0.4 时正常表现的球员评分被压得过低（实测全场无人达 8 分）
        if (finalScore >= 0) {
          rating = finalScore / Math.pow(minutes, 0.2)
        } else {
          rating = finalScore * Math.pow(minutes, 0.2)
        }
        // 注意：无贡献额外惩罚移到定时器中处理（每3分钟检查一次）
        return Math.round(rating * 10) / 10
      }

      return Math.round(rawScore * 10) / 10
    }

    // 组装教练面板数据（包含球队所有成员，即使没上场也显示）
    const allPlayerIds = [...new Set([
      ...teamPlayerIds,
      ...(allLineup || []).map(l => l.player_id),
      ...(gameStats || []).map(s => s.player_id)
    ])]

    const result = allPlayerIds.map(pid => {
      const pInfo = playerMap[pid] || {}
      const jInfo = jerseyMap[pid] || {}
      // 优先从 game_stats 快照获取名字（防止球员被删除后显示"未知"）
      const gsFirst = (gameStats || []).find(s => s.player_id === pid) || {}
      const snapshotName = gsFirst.player_name || null
      const snapshotAvatar = gsFirst.player_avatar_url || null
      const snapshotJersey = gsFirst.jersey_no || null
      const snapshotPosition = gsFirst.player_position || null
      const mins = minutesMap[pid] || { total: 0, quarters: {} }
      const stints = stintStatsMap[pid] || []

      // 计算总上场分钟数
      const totalMins = Math.ceil(mins.total / 60)
      // 优先使用教练手动调整的位置，其次用快照位置，最后用 team_players 位置
      const pos = coachPositionOverrides.value[pid] || snapshotPosition || positionMap[pid] || 'FLEX'

      // 按上场阶段计算评分
      const playerLineupData = (allLineup || []).filter(l => l.player_id === pid)
      const stintsData = stints.map((stint, idx) => {
        const stintMins = Math.ceil(stint.duration / 60) || 1
        // 通过 lineup_id 精确匹配对应的 lineup 记录（替代时间戳比较）
        const lineupEntry = playerLineupData.find(l => l.id === stint.lineup_id)
        if (!lineupEntry && stint.lineup_id) {
          console.warn('[loadCoachData] lineup_id 匹配失败! pid:', pid, 'stintIndex:', idx+1, 'lineup_id:', stint.lineup_id, 'playerLineupData IDs:', playerLineupData.map(l => l.id))
        }
        // 对于在场球员，用统一公式重算（比赛时间域内，暂停扣除）
        let effectiveRawDuration = stint.rawDuration || stint.duration || 0
        const entryForCalc = lineupEntry || {
          on_at: stint.on_at,
          off_at: stint.off_at || null,
          paused_ms_at_on: stint.paused_ms_at_on || 0,
          paused_ms_at_off: null
        }
        if (!stint.off_at || entryForCalc.on_at) {
          effectiveRawDuration = calcStintSec(entryForCalc)
        }
        return {
          stintIndex: idx + 1,
          quarter: stint.quarter,
          minutes: formatSeconds(effectiveRawDuration),
          on_at: stint.on_at,
          off_at: stint.off_at,
          ...stint.stats,
          rating: calcRating(stint.stats, pos, stintMins, stint.teamPointsGained, stint.oppPointsGained, stint.netEfficiency, stint.beforeNetRate),
          _lineupEntry: lineupEntry || null,
          rawDuration: effectiveRawDuration
        }
      })

      // 总上场时间 = 分段时间之和（确保一致）
      const totalSecFromStints = stintsData.reduce((sum, s) => sum + (s.rawDuration || 0), 0)
      const totalMinsFromStints = Math.ceil(totalSecFromStints / 60) || 0

      return {
        player_id: pid,
        team_id: (allLineup || []).find(l => l.player_id === pid)?.team_id
          || gsFirst.team_id
          || jerseyMap[pid]?.team_id,
        name: snapshotName || pInfo.name || '未知',
        avatar_url: snapshotAvatar || pInfo.avatar_url,
        jersey_no: snapshotJersey || jInfo.jersey_no,
        position: pos,
        totalMinutes: formatSeconds(totalSecFromStints),
        _lineupData: playerLineupData,
        _totalAccumulatedSec: totalSecFromStints,
        // 统计数据：合并同一球员的所有 game_stats 记录（不同位置可能有多条）
        pts: sumStat(pid, 'pts'),
        reb: sumStat(pid, 'reb'),
        ast: sumStat(pid, 'ast'),
        stl: sumStat(pid, 'stl'),
        blk: sumStat(pid, 'blk'),
        tov: sumStat(pid, 'tov'),
        pf: sumStat(pid, 'pf'),
        // 全场评分：按各阶段时间加权平均（含暂停扣除）
        rating: calcTimeWeightedRatingFromStints(stintsData),
        stints: stintsData
      }
    })
    // 固定排序（不因评分变化重排）
    coachPlayers.value = stableSortCoachPlayers(result)
    console.log('[loadCoachData] 全部完成, 总耗时:', Date.now() - t0, 'ms, 球员数:', result.length)
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
    PG:  { pts: 0.9, reb: 0.9, ast: 1.8, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fga_miss: -0.5, fta_miss: -0.3 },
    SG:  { pts: 1.2, reb: 1.0, ast: 1.3, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fga_miss: -0.6, fta_miss: -0.3 },
    SF:  { pts: 1.1, reb: 1.2, ast: 1.1, stl: 1.0, blk: 0.9, tov: -0.8, pf: -0.5, fga_miss: -0.6, fta_miss: -0.3 },
    PF:  { pts: 1.0, reb: 1.5, ast: 0.9, stl: 0.9, blk: 1.3, tov: -0.7, pf: -0.6, fga_miss: -0.5, fta_miss: -0.3 },
    C:   { pts: 1.0, reb: 1.8, ast: 0.7, stl: 0.7, blk: 1.6, tov: -0.6, pf: -0.6, fga_miss: -0.4, fta_miss: -0.3 },
    FLEX:{ pts: 1.0, reb: 1.2, ast: 1.2, stl: 1.0, blk: 1.0, tov: -0.7, pf: -0.5, fga_miss: -0.5, fta_miss: -0.3 }
  }
  const w = POSITION_WEIGHTS[newPosition] || POSITION_WEIGHTS.FLEX
  const stintMins = Math.ceil(parseInt(stint.minutes) / 60) || 1
  const fgaMiss = (stint.fg2a || 0) - (stint.fg2m || 0)
  const ftaMiss = (stint.fta || 0) - (stint.ftm || 0)
  const raw = (stint.pts||0)*w.pts + (stint.reb||0)*w.reb + (stint.ast||0)*w.ast + (stint.stl||0)*w.stl + (stint.blk||0)*w.blk + (stint.tov||0)*w.tov + (stint.pf||0)*w.pf + fgaMiss*w.fga_miss + ftaMiss*w.fta_miss
  stint.rating = Math.round((raw / Math.pow(stintMins, 0.2)) * 10) / 10

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
    // 低频状态同步兜底（realtime 断开时暂停/节次状态自愈）
    startStateSync()
  } else {
    stopCoachTimer()
  }
})

// 教练页定时器：累加式，暂停时停止，恢复时继续
let coachTimer = null
let lastTickTime = 0

// 从 game 记录获取累计暂停毫秒数（数据库持久化，跨页面可靠）
function getGamePausedMs() {
  const g = game.value
  if (!g) return 0
  let ms = g.total_paused_ms || 0
  // 如果当前暂停中，还要加上从 paused_at 到现在的时长
  if (g.is_paused && g.paused_at) {
    ms += Date.now() - new Date(g.paused_at).getTime()
  }
  // 只在暂停状态变化时打印（减少刷屏）
  // console.log('[getGamePausedMs] total_paused_ms:', g.total_paused_ms, 'is_paused:', g.is_paused, 'paused_at:', g.paused_at, 'result:', ms)
  return ms
}

// ══════════════════════════════════════════════════════════
// 统一在场时间计算（教练页唯一计时标准）
// 原则：只在比赛时间域内计时
//   窗口 = [max(on_at, started_at), min(off_at|now|paused_at, finished_at)]
//   再减去窗口内的暂停时间（total_paused_ms 快照差）
// - 比赛未开始（status 非 active|finished）：一律 0，
//   赛前上的场（排首发）不计时
// - 暂停 / 节间休息：窗口右端 clamp 到 paused_at，暂停期不走秒
// - 比赛结束：窗口右端 clamp 到 finished_at
// - 下场球员：用 paused_ms_at_off/on 快照差精确扣除
// ══════════════════════════════════════════════════════════
function calcStintSec(l) {
  if (!l || !l.on_at) return 0
  const g = game.value || {}
  // 比赛未开始：赛前上的场不计时间
  if (g.status !== 'active' && g.status !== 'finished') return 0

  let startMs = new Date(l.on_at).getTime()
  // 赛前上场：起点 clamp 到比赛开始时刻
  if (g.started_at) startMs = Math.max(startMs, new Date(g.started_at).getTime())

  let endMs
  if (l.off_at) {
    endMs = new Date(l.off_at).getTime()
  } else {
    endMs = Date.now()
    // 在场且当前暂停中（暂停/节间休息）：只计到暂停时刻
    if (g.is_paused && g.paused_at) {
      endMs = Math.min(endMs, new Date(g.paused_at).getTime())
    }
  }
  // 比赛已结束：右端 clamp 到结束时刻
  if (g.finished_at) endMs = Math.min(endMs, new Date(g.finished_at).getTime())
  if (endMs <= startMs) return 0

  // 窗口内暂停扣除
  let pausedMs = 0
  if (l.off_at) {
    if (l.paused_ms_at_off != null) {
      pausedMs = Math.max(0, l.paused_ms_at_off - (l.paused_ms_at_on || 0))
    }
  } else {
    pausedMs = Math.max(0, (g.total_paused_ms || 0) - (l.paused_ms_at_on || 0))
  }
  const elapsedMs = endMs - startMs
  return Math.max(0, Math.floor((elapsedMs - Math.min(pausedMs, elapsedMs)) / 1000))
}

// 已下场 stint 的有效秒数（统一公式）
function calcOffStintSec(l) {
  return calcStintSec(l)
}

function getLineupDurationSec(lineupEntry) {
  return calcStintSec(lineupEntry)
}

// 简化版评分函数（供定时器使用，与 changeStintPosition 一致）
const TIMER_POSITION_WEIGHTS = {
  PG:  { pts: 1.2, reb: 0.8, ast: 1.8, stl: 1.5, blk: 0.5, tov: -1.2, pf: -0.8, fga_miss: -0.6, fta_miss: -0.4 },
  SG:  { pts: 1.5, reb: 0.8, ast: 1.2, stl: 1.2, blk: 0.5, tov: -1.0, pf: -0.8, fga_miss: -0.7, fta_miss: -0.4 },
  SF:  { pts: 1.3, reb: 1.0, ast: 1.1, stl: 1.1, blk: 0.8, tov: -1.0, pf: -0.8, fga_miss: -0.7, fta_miss: -0.4 },
  PF:  { pts: 1.2, reb: 1.5, ast: 0.8, stl: 0.9, blk: 1.2, tov: -1.0, pf: -0.9, fga_miss: -0.6, fta_miss: -0.5 },
  C:   { pts: 1.2, reb: 1.8, ast: 0.6, stl: 0.7, blk: 1.6, tov: -0.8, pf: -0.9, fga_miss: -0.5, fta_miss: -0.5 },
  FLEX:{ pts: 1.2, reb: 1.2, ast: 1.2, stl: 1.2, blk: 1.2, tov: -1.0, pf: -0.8, fga_miss: -0.6, fta_miss: -0.4 }
}

function quickRecalcStintRating(stint, pos) {
  const w = TIMER_POSITION_WEIGHTS[pos] || TIMER_POSITION_WEIGHTS.FLEX
  // 解析时间 mm:ss → 分钟数
  const parts = (stint.minutes || '0:00').split(':')
  const stintMins = parseInt(parts[0]) * 60 + parseInt(parts[1] || 0)
  const mins = Math.max(Math.ceil(stintMins / 60), 1)
  const fgaMiss = (stint.fg2a || 0) - (stint.fg2m || 0)
  const ftaMiss = (stint.fta || 0) - (stint.ftm || 0)
  const raw = (stint.pts||0)*w.pts + (stint.reb||0)*w.reb + (stint.ast||0)*w.ast + (stint.stl||0)*w.stl + (stint.blk||0)*w.blk + (stint.tov||0)*w.tov + (stint.pf||0)*w.pf + fgaMiss*w.fga_miss + ftaMiss*w.fta_miss
  // 去除底薪
  let timeModifier = 1.0
  if (mins <= 2) timeModifier = 1.4
  else if (mins <= 5) timeModifier = 1.2
  else if (mins >= 15) timeModifier = 0.95
  const finalScore = raw * timeModifier
  // 正分除以 minutes^0.2（与 loadCoachData calcRating 一致），负分同指数
  let rating
  if (finalScore >= 0) {
    rating = finalScore / Math.pow(mins, 0.2)
  } else {
    rating = finalScore * Math.pow(mins, 0.2)
  }
  stint.rating = Math.round(rating * 10) / 10
}

// 防抖：避免短时间内多次录入触发过多 loadCoachData
let coachDataDebounce = null
function debouncedLoadCoachData() {
  if (coachDataDebounce) clearTimeout(coachDataDebounce)
  coachDataDebounce = setTimeout(() => {
    if (activeTab.value === 'coach') loadCoachData()
  }, 500)  // 缩短到0.5秒
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
        // 比分/节次变化时刷新全队犯规（娱乐赛虚拟节随比分切换）
        debouncedLoadFouls()
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
      console.log('[Realtime] action_logs 事件:', payload.eventType, payload.new?.action_type, 'player:', payload.new?.player_id)
      if (payload.new) {
        // 增量更新教练页数据
        if (activeTab.value === 'coach') {
          incrementalUpdatePlayerStats(payload.new)
        }
        // 增量更新数据统计页
        incrementalUpdateStats(payload.new)
        // 刷新全队犯规（大屏展示用）
        debouncedLoadFouls()
      }
    })
    // 监听 game_lineup 变化（换人时触发）- 阵容变化需要全量刷新
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'game_lineup',
      filter: `game_id=eq.${gameId}`
    }, async (payload) => {
      console.log('[Realtime] game_lineup 变化:', payload.eventType, '时间:', new Date().toISOString())
      // 刷新当前场上阵容（is_current=true），使 isOnCourt() 判断正确
      const { data: currentLineup } = await supabase
        .from('game_lineup')
        .select('player_id, team_id, slot_no, on_at')
        .eq('game_id', gameId)
        .eq('is_current', true)
      if (currentLineup) courtLineup.value = currentLineup
      console.log('[Realtime] courtLineup 更新完成, 在场人数:', currentLineup?.length, '时间:', new Date().toISOString())

      if (activeTab.value === 'coach') {
        // 第一步：快速增量更新，立即让新上场球员出现在 coachPlayers 并启动计时
        const t0 = Date.now()
        const { data: newLineup } = await supabase
          .from('game_lineup')
          .select('id, player_id, team_id, slot_no, quarter, on_at, off_at, paused_ms_at_on, paused_ms_at_off')
          .eq('game_id', gameId)
          .order('on_at', { ascending: true })
        console.log('[Realtime] 增量 lineup 查询完成, 耗时:', Date.now() - t0, 'ms, 记录数:', newLineup?.length)

        if (newLineup) {
          // 更新已有球员的下场状态（off_at），防止已下场球员继续计时
          const lineupMap = {}
          for (const l of newLineup) {
            if (!lineupMap[l.player_id]) lineupMap[l.player_id] = []
            lineupMap[l.player_id].push(l)
          }

          for (const player of coachPlayers.value) {
            const pLineup = lineupMap[player.player_id]
            if (!pLineup) continue
            // 检查每个 stint 的 off_at 是否需要更新
            for (const stint of (player.stints || [])) {
              if (stint.off_at) continue  // 已有 off_at，跳过
              // 在 lineup 数据中找到匹配的记录
              const matchedLineup = pLineup.find(l => l.id === (stint._lineupEntry?.id || stint.lineup_id))
              if (matchedLineup && matchedLineup.off_at) {
                // 球员已下场，更新 stint（用快照扣除暂停）
                stint.off_at = matchedLineup.off_at
                stint.rawDuration = calcOffStintSec(matchedLineup)
                stint.minutes = formatSeconds(stint.rawDuration)
                console.log('[Realtime] 下场更新: 球员', player.name, 'stint', stint.stintIndex, 'off_at 设为', stint.off_at)
              }
            }
          }

          // 找出当前在场但 coachPlayers 中没有的球员（新上场）
          const activeLineup = newLineup.filter(l => !l.off_at)
          const existingPlayerIds = new Set(coachPlayers.value.map(p => p.player_id))
          console.log('[Realtime] 增量分析: 在场人数', activeLineup.length, '已有球员数', existingPlayerIds.size)

          for (const al of activeLineup) {
            if (existingPlayerIds.has(al.player_id)) {
              // 球员已在 coachPlayers 中，检查是否有新的上场阶段
              const player = coachPlayers.value.find(p => p.player_id === al.player_id)
              if (player) {
                const playerLineup = newLineup.filter(l => l.player_id === al.player_id)
                // 按 lineup_id 去重：只添加 stints 中还不存在的新上场记录
                // （避免事件重复/顺序错乱时索引错位导致的漏加或重复）
                const existingLineupIds = new Set(
                  (player.stints || []).map(s => s._lineupEntry?.id || s.lineup_id)
                )
                const newStints = playerLineup.filter(l => !existingLineupIds.has(l.id))
                console.log('[Realtime] 已有球员:', player.name, 'lineup记录数:', playerLineup.length,
                  '已有stint数:', (player.stints || []).length, '新增:', newStints.length)
                // 只在有新阶段时才添加（避免覆盖已有统计数据）
                if (newStints.length > 0) {
                  // 只添加新增的阶段，保留已有的
                  for (const l of newStints) {
                    const duration = calcStintSec(l)
                    player.stints.push({
                      stintIndex: (player.stints || []).length + 1,
                      quarter: l.quarter || 1,
                      minutes: formatSeconds(duration),
                      on_at: l.on_at,
                      off_at: l.off_at || null,
                      pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
                      fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0, ftm: 0, fta: 0,
                      rating: 0,
                      _lineupEntry: l,
                      rawDuration: duration,
                      team_id: l.team_id
                    })
                  }
                  // 触发响应式更新
                  coachPlayers.value = [...coachPlayers.value]
                }
              }
            } else {
              // 新球员不在 coachPlayers 中，快速添加一个简版记录
              const playerLineup = newLineup.filter(l => l.player_id === al.player_id)
              const calcStintDuration = (l) => calcStintSec(l)
              const totalDuration = playerLineup.reduce((sum, l) => sum + calcStintDuration(l), 0)

              const stints = playerLineup.map((l, idx) => {
                const dur = calcStintDuration(l)
                return {
                  stintIndex: idx + 1,
                  quarter: l.quarter || 1,
                  minutes: formatSeconds(dur),
                  on_at: l.on_at,
                  off_at: l.off_at || null,
                  pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
                  fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0, ftm: 0, fta: 0,
                  rating: 0,
                  _lineupEntry: l,
                  rawDuration: dur,
                  team_id: l.team_id
                }
              })

              coachPlayers.value.push({
                player_id: al.player_id,
                team_id: al.team_id,
                name: '加载中...',
                avatar_url: null,
                jersey_no: null,
                position: 'FLEX',
                totalMinutes: formatSeconds(totalDuration),
                pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
                rating: 0,
                stints
              })
              // 触发响应式更新
              coachPlayers.value = [...coachPlayers.value]
            }
          }

          // 立即重启定时器，确保新上场球员马上开始计时
          console.log('[Realtime] 增量更新完成, 重启定时器, coachPlayers数:', coachPlayers.value.length)
          if (game.value?.status === 'active' && !game.value.is_paused) {
            startCoachTimer()
            console.log('[Realtime] 定时器已重启')
          }
        }

        // 后台全量刷新（会替换简版数据为完整数据）
        console.log('[Realtime] 开始 loadCoachData 全量刷新, 时间:', new Date().toISOString())
        await loadCoachData()
        console.log('[Realtime] loadCoachData 完成, 时间:', new Date().toISOString())
        // 全量数据加载后，如果定时器未运行则启动（不重启已有的定时器，避免1秒空白）
        if (game.value?.status === 'active' && !game.value.is_paused && !coachTimer) {
          startCoachTimer()
        }
      }
    })
    // 订阅失败/断开时自动重连，避免 games 暂停状态与 game_lineup 变化静默丢失
    .subscribe((status, err) => {
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.warn('[GameDetail] Realtime订阅异常，5秒后重连...', status, err)
        setTimeout(() => {
          if (isUnmounted.value) return
          subscribeGameUpdates()
        }, 5000)
      }
    })
}

// 增量更新数据统计页（避免全量刷新）
function incrementalUpdateStats(actionLog) {
  const playerId = actionLog.player_id
  const stat = stats.value.find(s => s.player_id === playerId)
  if (!stat) return
  const d = actionLog.delta || 1
  switch (actionLog.action_type) {
    case 'pts_1': stat.pts = (stat.pts||0) + 1*d; stat.ftm = (stat.ftm||0) + 1*d; stat.fta = (stat.fta||0) + 1*d; break
    case 'pts_2': stat.pts = (stat.pts||0) + 2*d; stat.fg2m = (stat.fg2m||0) + 1*d; stat.fg2a = (stat.fg2a||0) + 1*d; break
    case 'pts_3': stat.pts = (stat.pts||0) + 3*d; stat.fg3m = (stat.fg3m||0) + 1*d; stat.fg3a = (stat.fg3a||0) + 1*d; break
    case 'reb': stat.reb = (stat.reb||0) + d; break
    case 'ast': stat.ast = (stat.ast||0) + d; break
    case 'stl': stat.stl = (stat.stl||0) + d; break
    case 'blk': stat.blk = (stat.blk||0) + d; break
    case 'tov': stat.tov = (stat.tov||0) + d; break
    case 'pf': stat.pf = (stat.pf||0) + d; break
    case 'fga_miss': stat.fg2a = (stat.fg2a||0) + d; break
    case 'fg3a_miss': stat.fg3a = (stat.fg3a||0) + d; break
    case 'fta_miss': stat.fta = (stat.fta||0) + d; break
  }
}

// 增量更新球员统计数据（避免全量刷新）
function incrementalUpdatePlayerStats(actionLog) {
  console.log('[增量更新] 收到事件:', actionLog.action_type, '球员:', actionLog.player_id)
  const playerId = actionLog.player_id
  const player = coachPlayers.value.find(p => p.player_id === playerId)
  if (!player || !player.stints) {
    console.log('[增量更新] 未找到球员或无 stints 数据')
    return
  }

  const actionTime = new Date(actionLog.created_at)
  const delta = actionLog.delta || 1

  // 找到包含该 action 的上场阶段
  // 优先匹配当前在场阶段（off_at 为 null），否则按时间匹配
  let stint = player.stints.find(s => !s.off_at)
  if (!stint) {
    const actionTime = new Date(actionLog.created_at)
    stint = player.stints.find(s => {
      if (!s.on_at) return false
      const start = new Date(s.on_at)
      const end = s.off_at ? new Date(s.off_at) : new Date()
      return actionTime >= start && actionTime <= end
    })
  }
  if (!stint) {
    console.log('[增量更新] 未找到匹配的上场阶段, stints数量:', player.stints.length)
    return
  }
  console.log('[增量更新] 匹配成功，更新数据')

  // 更新阶段统计数据
  switch (actionLog.action_type) {
    case 'pts_1':
      stint.pts = (stint.pts || 0) + 1 * delta
      stint.ftm = (stint.ftm || 0) + 1 * delta
      stint.fta = (stint.fta || 0) + 1 * delta
      break
    case 'pts_2':
      stint.pts = (stint.pts || 0) + 2 * delta
      stint.fg2m = (stint.fg2m || 0) + 1 * delta
      stint.fg2a = (stint.fg2a || 0) + 1 * delta
      break
    case 'pts_3':
      stint.pts = (stint.pts || 0) + 3 * delta
      stint.fg3m = (stint.fg3m || 0) + 1 * delta
      stint.fg3a = (stint.fg3a || 0) + 1 * delta
      break
    case 'reb': stint.reb = (stint.reb || 0) + delta; break
    case 'ast': stint.ast = (stint.ast || 0) + delta; break
    case 'stl': stint.stl = (stint.stl || 0) + delta; break
    case 'blk': stint.blk = (stint.blk || 0) + delta; break
    case 'tov': stint.tov = (stint.tov || 0) + delta; break
    case 'pf': stint.pf = (stint.pf || 0) + delta; break
    case 'fga_miss': stint.fg2a = (stint.fg2a || 0) + delta; break
    case 'fg3a_miss': stint.fg3a = (stint.fg3a || 0) + delta; break
    case 'fta_miss': stint.fta = (stint.fta || 0) + delta; break
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
  quickRecalcStintRating(stint, pos)

  // 重新计算全场评分
  player.rating = calcTimeWeightedRating(player.stints)

  // 注意：不实时排序，避免整个列表重渲染。排序只在切换tab或定时器触发时进行
}

// 按时间加权平均计算总评分
// 使用 rawDuration（已由 loadCoachData/定时器维护，扣除暂停时间），与计时器显示完全一致
function calcTimeWeightedRating(stints) {
  if (!stints || stints.length === 0) return 0
  let totalWeightedRating = 0
  let totalSeconds = 0
  for (const stint of stints) {
    const secs = Math.max(0, stint.rawDuration || 0)
    if (secs <= 0) continue
    totalWeightedRating += (stint.rating || 0) * secs
    totalSeconds += secs
  }
  if (totalSeconds === 0) return 0
  return Math.round((totalWeightedRating / totalSeconds) * 10) / 10
}

// 同 calcTimeWeightedRating，但 loadCoachData 阶段（rawDuration 还没被定时器走动）也能正确算出评分
// 使用 stintsData 中已经正确计算的 rawDuration（由 loadCoachData 计算，已扣除暂停）
function calcTimeWeightedRatingFromStints(stints) {
  return calcTimeWeightedRating(stints)
}

// 累加式计时器：每个在场球员独立计时，暂停时停止
const CHECK_INTERVAL_MS = 2 * 60 * 1000  // 2分钟
const PENALTY_PER_MINUTE = 0.3

function startCoachTimer() {
  // 如果定时器已运行，不要重复启动
  if (coachTimer) return
  coachTimer = setInterval(() => {
    // 比赛结束或暂停时停止计时
    if (game.value?.status !== 'active' || game.value?.is_paused) {
      stopCoachTimer()
      return
    }
    if (coachPlayers.value.length === 0) return
    let hasUpdate = false
    
    for (const player of coachPlayers.value) {
      // 只更新在场球员（有未结束的上场阶段）
      const activeStints = (player.stints || []).filter(s => !s.off_at)
      if (activeStints.length === 0) continue  // 备战席球员跳过

      hasUpdate = true
      // 统一公式重算每个在场阶段（比赛时间域内，跨端一致）
      for (const stint of activeStints) {
        if (!stint._lineupEntry?.on_at && !stint.on_at) {
          console.warn('[Timer] stint 跳过: 无 on_at, 球员:', player.name, 'stintIndex:', stint.stintIndex, '_lineupEntry:', stint._lineupEntry)
          continue
        }
        const rawSec = calcStintSec(stint._lineupEntry || stint)
        stint.rawDuration = rawSec
        stint.minutes = formatSeconds(rawSec)
        
        // 用该阶段的位置重算评分
        const pos = stint.stintPosition || player.position || 'FLEX'
        quickRecalcStintRating(stint, pos)
        
        // 3分钟无贡献检查
        const now = Date.now()
        const hasPositive = (stint.pts||0) > 0 || (stint.reb||0) > 0 || (stint.ast||0) > 0 || 
                            (stint.stl||0) > 0 || (stint.blk||0) > 0
        if (hasPositive) {
          stint._lastPositiveAt = now
          stint._penaltyStartAt = null
          stint._penaltyMinutes = 0
        } else {
          const lastPositive = stint._lastPositiveAt || (now - CHECK_INTERVAL_MS)
          const elapsedSinceCheck = now - lastPositive
          if (elapsedSinceCheck >= CHECK_INTERVAL_MS) {
            stint._penaltyMinutes = Math.floor((elapsedSinceCheck - CHECK_INTERVAL_MS) / 60000)
          } else {
            stint._penaltyMinutes = 0
          }
        }
      }
      
      // 重算总上场时间（所有阶段累加）
      const totalSec = (player.stints || []).reduce((sum, s) => sum + (s.rawDuration || 0), 0)
      player.totalMinutes = formatSeconds(totalSec)
      
      // 重算全场评分（包含惩罚）
      player.rating = calcTimeWeightedRatingWithPenalty(player.stints)
    }
    
    // 强制触发Vue响应式更新
    if (hasUpdate) {
      coachPlayers.value = [...coachPlayers.value]
    }
  }, 1000)
}

// 计算加权评分，包含无贡献惩罚
// 使用 rawDuration（已扣除暂停），保证暂停时评分不变
function calcTimeWeightedRatingWithPenalty(stints) {
  if (!stints || stints.length === 0) return 0
  let totalWeightedRating = 0
  let totalSeconds = 0
  for (const stint of stints) {
    const secs = Math.max(0, stint.rawDuration || 0)
    if (secs <= 0) continue
    // 基础评分
    let rating = stint.rating || 0
    // 添加无贡献惩罚（每分钟-0.3）
    const penaltyMin = stint._penaltyMinutes || 0
    rating = rating - (penaltyMin * PENALTY_PER_MINUTE)
    totalWeightedRating += rating * secs
    totalSeconds += secs
  }
  if (totalSeconds === 0) return 0
  return Math.round((totalWeightedRating / totalSeconds) * 10) / 10
}
function stopCoachTimer() {
  if (coachTimer) { clearInterval(coachTimer); coachTimer = null }
}

// 低频状态同步（每15秒）：realtime 断开期间不补发事件，
// 兜底同步暂停/节次/结束状态，避免"节次结束不停表"和"暂停恢复后不启动"
let stateSyncTimer = null
function startStateSync() {
  if (stateSyncTimer) return
  stateSyncTimer = setInterval(async () => {
    if (isUnmounted.value || !game.value) return
    try {
      const { data: gRow, error: gErr } = await supabase
        .from('games')
        .select('status, is_paused, paused_at, total_paused_ms, current_quarter, finished_at, started_at')
        .eq('id', gameId)
        .maybeSingle()
      if (gErr || !gRow) return
      const prevPaused = !!game.value?.is_paused
      game.value = { ...game.value, ...gRow }
      if (gRow.is_paused || gRow.status !== 'active') {
        stopCoachTimer()
      } else if (prevPaused && !gRow.is_paused && gRow.status === 'active') {
        // 从暂停恢复：重启计时（coachTimer 为空时才生效）
        startCoachTimer()
      }
    } catch (e) {
      console.warn('[StateSync] games 状态同步失败:', e)
    }
  }, 15000)
}

// 组件卸载时清理定时器
const isUnmounted = ref(false)
onUnmounted(() => {
  isUnmounted.value = true
  stopCoachTimer()
  if (stateSyncTimer) { clearInterval(stateSyncTimer); stateSyncTimer = null }
  clearTimeout(foulsDebounce)
  if (landscapeStats.value) {
    document.body.style.overflow = ''
    window.removeEventListener('resize', updateLandscapeStage)
  }
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

    // 全队犯规（大屏展示用）
    loadTeamFouls()

    // 订阅比赛实时更新（暂停状态同步等）
    subscribeGameUpdates()

    // 并行获取：两队所有球员 + 本场统计数据 + MVP + 当前场上阵容
    const [tpRes, statsRes, mvpQuery, lineupRes] = await Promise.allSettled([
      supabase.from('team_players')
        .select(`team_id, player_id, jersey_no, position, player:player_id(id, name, avatar_url)`)
        .in('team_id', [gameData.home_team_id, gameData.away_team_id])
        .eq('is_active', true),
      supabase.from('game_stats')
        .select(`id, game_id, player_id, team_id, game_type, pts, reb, oreb, dreb, ast, stl, blk, tov, pf, fg2m, fg2a, fg3m, fg3a, ftm, fta, min_played, player_name, player_avatar_url, player_position, jersey_no, team_name, team_color`)
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
    // 注意：使用新字段 fg2m/fg2a（2分），fg3m/fg3a（3分），ftm/fta（罚球）
    const statFields = ['pts', 'reb', 'oreb', 'dreb', 'ast', 'stl', 'blk', 'tov', 'pf', 'fg2m', 'fg2a', 'fg3m', 'fg3a', 'ftm', 'fta', 'min_played']
    const statFieldsOld = ['pts', 'reb', 'oreb', 'dreb', 'ast', 'stl', 'blk', 'tov', 'pf', 'fgm', 'fga', 'fg3m', 'fg3a', 'ftm', 'fta', 'min_played']
    const merged = []
    const homeColorVal = gameData.home_team?.color || '#3b82f6'
    const awayColorVal = gameData.away_team?.color || '#f97316'
    const homeName = gameData.home_team?.name || '主队'
    const awayName = gameData.away_team?.name || '客队'

    // 已结束的比赛：从 game_stats 获取数据，同时确保所有报名球员都显示
    if (gameData.status === 'finished' && tpRes.status === 'fulfilled' && tpRes.value.data) {
      // 先添加所有报名球员（从 team_players）
      for (const tp of tpRes.value.data) {
        const existing = statsMap[tp.player_id]
        if (existing) {
          // 有统计数据：合并数据
          const normalized = { ...existing }
          for (const f of statFields) {
            if (normalized[f] == null) normalized[f] = 0
          }
          normalized.player = {
            id: tp.player_id,
            name: existing.player_name || tp.player?.name || '未知',
            jersey_no: existing.jersey_no || tp.jersey_no || '',
            team_position: existing.player_position || tp.position || '',
            avatar_url: existing.player_avatar_url || tp.player?.avatar_url || null
          }
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
            pf: 0, tov: 0, fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0,
            ftm: 0, fta: 0,
            player_position: tp.position || '',
            player: {
              id:        tp.player_id,
              name:      tp.player?.name || '未知',
              jersey_no: tp.jersey_no,
              team_position: tp.position || '',
              avatar_url: tp.player?.avatar_url || null
            },
            team: {
              id:    tp.team_id,
              name:  isHome ? homeName : awayName,
              color: isHome ? homeColorVal : awayColorVal
            }
          })
        }
      }
      // 再添加可能已经被移出球队但有数据的球员（保留历史数据）
      if (statsRes.status === 'fulfilled' && statsRes.value.data) {
        for (const s of statsRes.value.data) {
          // 跳过已经添加的球员
          if (merged.find(m => m.player_id === s.player_id)) continue
          const normalized = { ...s }
          for (const f of statFields) {
            if (normalized[f] == null) normalized[f] = 0
          }
          normalized.player = {
            id: s.player_id,
            name: s.player_name || '未知',
            jersey_no: s.jersey_no || '',
            team_position: s.player_position || '',
            avatar_url: s.player_avatar_url || null
          }
          merged.push(normalized)
        }
      }
    } else if (tpRes.status === 'fulfilled' && tpRes.value.data) {
      // 进行中/未开始的比赛：使用 team_players 获取当前阵容
      for (const tp of tpRes.value.data) {
        const existing = statsMap[tp.player_id]
        if (existing) {
          // 有统计数据：合并球衣号码和位置，同时把 NULL 字段默认为 0
          const normalized = { ...existing }
          // 兼容旧字段 fgm/fga → 映射到新字段 fg2m/fg2a
          if (normalized.fgm != null && normalized.fg2m == null) {
            normalized.fg2m = normalized.fgm
          }
          if (normalized.fga != null && normalized.fg2a == null) {
            normalized.fg2a = normalized.fga
          }
          for (const f of statFields) {
            if (normalized[f] == null) normalized[f] = 0
          }
          normalized.player = {
            id: existing.player_id,
            name: existing.player_name || tp.player?.name || '未知',
            jersey_no: tp.jersey_no,
            // 优先使用球队位置（tp.position），如果没有则保留快照位置（player_position）
            team_position: tp.position || normalized.player_position || '',
            avatar_url: tp.player?.avatar_url || null
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
            pf: 0, tov: 0, fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0,
            ftm: 0, fta: 0,
            player_position: tp.position || '',
            player: {
            id:        tp.player_id,
            name:      tp.player?.name || '未知',
            jersey_no: tp.jersey_no,
            team_position: tp.position || '',
            avatar_url: tp.player?.avatar_url || null
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

    // 缓存查询结果，供教练数据复用
    if (tpRes.status === 'fulfilled') cachedTeamPlayers.value = tpRes.value.data
    if (statsRes.status === 'fulfilled') cachedGameStats.value = statsRes.value.data

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

/* ── 球员评分徽章 ── */
.rating-col-header {
  color: #fbbf24;
  text-shadow: 0 0 10px rgba(251, 191, 36, 0.4);
  position: sticky;
  right: 0;
  z-index: 12;
  background: #1a1d2e;
}

/* 评分徽章 - 游戏风格 */
.rating-badge {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3px 6px;
  border-radius: 6px;
  font-weight: 800;
  line-height: 1;
  background: linear-gradient(145deg, var(--rating-color), color-mix(in srgb, var(--rating-color) 60%, #000));
  color: var(--rating-text);
  box-shadow: 
    0 2px 4px rgba(0,0,0,0.4),
    0 0 10px var(--rating-shadow),
    inset 0 1px 0 rgba(255,255,255,0.3),
    inset 0 -1px 0 rgba(0,0,0,0.2);
  position: relative;
  overflow: hidden;
  transition: all 0.2s ease;
  cursor: default;
  white-space: nowrap;
  min-width: 32px;
  border: 1px solid rgba(255,255,255,0.1);
}
.rating-badge:hover {
  transform: translateY(-2px) scale(1.05);
  box-shadow: 
    0 4px 8px rgba(0,0,0,0.5),
    0 0 20px var(--rating-shadow),
    inset 0 1px 0 rgba(255,255,255,0.4),
    inset 0 -1px 0 rgba(0,0,0,0.2);
}

/* 徽章顶部高光 */
.rating-badge::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 50%;
  background: linear-gradient(to bottom, rgba(255,255,255,0.25), transparent);
  pointer-events: none;
}

/* 徽章底部暗角 */
.rating-badge::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 40%;
  background: linear-gradient(to top, rgba(0,0,0,0.2), transparent);
  pointer-events: none;
}

.rating-grade {
  font-size: 11px;
  font-weight: 900;
  letter-spacing: 0.5px;
  text-shadow: 
    0 0 4px rgba(0,0,0,0.5),
    0 1px 2px rgba(0,0,0,0.3);
  z-index: 1;
}

.rating-score {
  font-size: 8px;
  font-weight: 700;
  opacity: 0.95;
  margin-top: 1px;
  text-shadow: 0 1px 1px rgba(0,0,0,0.3);
  z-index: 1;
}

/* SS 等级 - 传说品质（金橙色+脉动光效+旋转光环） */
.rating-ss {
  animation: ssPulse 2s ease-in-out infinite;
  border: 1.5px solid rgba(255,200,100,0.6);
  background: linear-gradient(145deg, #FF8C00, #FF5722, #E65100) !important;
}
.rating-ss::before {
  background: linear-gradient(to bottom, rgba(255,255,200,0.5), transparent);
}
.rating-ss::after {
  background: linear-gradient(to top, rgba(0,0,0,0.3), transparent);
}
@keyframes ssPulse {
  0%, 100% { 
    box-shadow: 
      0 2px 4px rgba(0,0,0,0.4),
      0 0 12px rgba(255,140,0,0.8),
      0 0 30px rgba(255,140,0,0.4),
      inset 0 1px 0 rgba(255,255,255,0.5);
  }
  50% { 
    box-shadow: 
      0 2px 4px rgba(0,0,0,0.4),
      0 0 20px rgba(255,140,0,0.9),
      0 0 50px rgba(255,140,0,0.5),
      inset 0 1px 0 rgba(255,255,255,0.6);
  }
}

/* S 等级 - 史诗品质（紫红色+强光晕） */
.rating-s {
  border: 1.5px solid rgba(224,64,251,0.5);
  background: linear-gradient(145deg, #E040FB, #AB47BC, #7B1FA2) !important;
  box-shadow: 
    0 2px 4px rgba(0,0,0,0.4),
    0 0 12px rgba(224,64,251,0.7),
    0 0 24px rgba(224,64,251,0.3),
    inset 0 1px 0 rgba(255,255,255,0.35);
}
.rating-s::before {
  background: linear-gradient(to bottom, rgba(255,200,255,0.4), transparent);
}

/* A 等级 - 精良品质（蓝色+光晕） */
.rating-a {
  border: 1px solid rgba(68,138,255,0.5);
  background: linear-gradient(145deg, #448AFF, #2962FF, #1565C0) !important;
  box-shadow: 
    0 2px 4px rgba(0,0,0,0.4),
    0 0 10px rgba(68,138,255,0.6),
    inset 0 1px 0 rgba(255,255,255,0.3);
}
.rating-a::before {
  background: linear-gradient(to bottom, rgba(180,210,255,0.35), transparent);
}

/* B 等级 - 良好品质（绿色） */
.rating-b {
  border: 1px solid rgba(0,230,118,0.4);
  background: linear-gradient(145deg, #00E676, #00C853, #009624) !important;
  box-shadow: 
    0 2px 4px rgba(0,0,0,0.3),
    0 0 8px rgba(0,230,118,0.4),
    inset 0 1px 0 rgba(255,255,255,0.25);
}
.rating-b::before {
  background: linear-gradient(to bottom, rgba(200,255,220,0.3), transparent);
}

/* C 等级 - 一般品质（灰蓝色） */
.rating-c {
  border: 1px solid rgba(120,144,156,0.3);
  background: linear-gradient(145deg, #78909C, #607D8B, #455A64) !important;
  box-shadow: 
    0 2px 4px rgba(0,0,0,0.3),
    inset 0 1px 0 rgba(255,255,255,0.15);
}

/* D 等级 - 需努力（暗灰色） */
.rating-d {
  border: 1px solid rgba(84,110,122,0.2);
  background: linear-gradient(145deg, #546E7A, #37474F, #263238) !important;
  opacity: 0.85;
  box-shadow: 
    0 2px 4px rgba(0,0,0,0.3),
    inset 0 1px 0 rgba(255,255,255,0.08);
}

/* ── 数据表最高值强化样式（无背景色，不影响列宽） ── */
.top-value {
  font-weight: 800;
  color: #f97316;
  text-shadow: 0 0 8px rgba(249, 115, 22, 0.5);
}

/* ── 数据统计表独立滚动容器 ── */
.stats-table-container {
  overflow-x: auto;
  overflow-y: auto;
  max-height: 480px;
  /* 创建层叠上下文：sticky 表头的 z-index 只在容器内生效，避免覆盖底部导航栏 */
  isolation: isolate;
  scrollbar-width: thin;
  scrollbar-color: rgba(75, 85, 99, 0.5) transparent;
}
.stats-table-container::-webkit-scrollbar {
  width: 5px;
  height: 5px;
}
.stats-table-container::-webkit-scrollbar-track {
  background: transparent;
}
.stats-table-container::-webkit-scrollbar-thumb {
  background-color: rgba(75, 85, 99, 0.5);
  border-radius: 3px;
}
.stats-table-container::-webkit-scrollbar-thumb:hover {
  background-color: rgba(75, 85, 99, 0.8);
}

/* ── 手机端横屏全屏（竖屏时旋转90°模拟横屏） ── */
.landscape-overlay {
  position: fixed;
  top: 50%;
  left: 50%;
  margin: 0;
  z-index: 90;
  transform: translate(-50%, -50%);
  border: none;
  border-radius: 0;
  box-shadow: none;
  transition: none;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: #11141f;
}
.landscape-overlay.is-rotated {
  transform: translate(-50%, -50%) rotate(90deg);
}
.landscape-overlay .card-header {
  flex-shrink: 0;
}
.landscape-overlay .stats-table-container {
  flex: 1;
  min-height: 0;
  max-height: none;
}

/* ── 数据统计表固定表头 ── */
.stats-table-header {
  position: sticky;
  top: 0;
  z-index: 100;
}
.stats-table-header th {
  background: #1a1d2e;
  border-bottom: 2px solid rgba(148, 163, 184, 0.2);
}
/* 评分和球员表头需要更高的 z-index，确保不被单元格覆盖 */
.stats-table-header .sticky-rating,
.stats-table-header .sticky-th {
  z-index: 101;
}

/* ── 球员信息固定列 ── */
.sticky-th {
  position: sticky;
  left: 48px;
  z-index: 101;
  background-color: #1a1d2e;
}
.sticky-player-info {
  position: sticky;
  left: 48px;
  z-index: 10;
  background-color: #1a1d2e;
  border-right: 1px solid rgba(148, 163, 184, 0.15);
}
/* 评分列固定 */
.sticky-rating-cell {
  position: sticky;
  left: 0;
  z-index: 10;
  background-color: #1a1d2e;
  border-right: 1px solid rgba(148, 163, 184, 0.15);
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
