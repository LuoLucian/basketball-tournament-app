<template>
  <div class="page-container max-w-5xl mx-auto">
    <!-- 加载中 -->
    <div v-if="loading" class="space-y-3">
      <div class="skeleton h-28 rounded-2xl"></div>
      <div class="skeleton h-40 rounded-2xl"></div>
      <div class="skeleton h-40 rounded-2xl"></div>
    </div>

    <div v-else-if="loadError" class="text-center py-20">
      <div class="text-4xl mb-4">⚠️</div>
      <p class="text-dark-400 mb-2">{{ loadError }}</p>
      <button @click="load" class="mt-4 btn-primary btn-sm">重新加载</button>
    </div>

    <template v-else>
      <!-- 前三名横幅 -->
      <div v-if="t.status === 'finished' && podium.champion" class="card card-body mb-5 text-center
                  bg-gradient-to-br from-accent-600/20 via-dark-850 to-dark-900 border border-accent-500/30">
        <div class="grid grid-cols-3 gap-2 items-end">
          <div>
            <p class="text-2xl">🥈</p>
            <p class="text-xs text-dark-400 mt-1">亚军</p>
            <p class="text-sm font-bold text-dark-200 mt-0.5 truncate">{{ podium.runnerUp || '—' }}</p>
          </div>
          <div class="pb-1">
            <p class="text-4xl">🏆</p>
            <p class="text-xs text-dark-400 mt-1">冠军</p>
            <p class="text-xl font-bold text-accent-400 mt-0.5 truncate">{{ podium.champion }}</p>
          </div>
          <div>
            <p class="text-2xl">🥉</p>
            <p class="text-xs text-dark-400 mt-1">季军</p>
            <p class="text-sm font-bold text-dark-200 mt-0.5 truncate">{{ podium.third || '—' }}</p>
          </div>
        </div>
      </div>

      <!-- 头部 -->
      <div class="card card-body mb-5">
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-center gap-3 min-w-0">
            <router-link to="/tournaments" class="text-dark-500 hover:text-white transition-colors p-1 flex-shrink-0">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
              </svg>
            </router-link>
            <div class="min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <h1 class="text-xl font-bold text-white truncate">{{ t.name }}</h1>
                <span class="badge" :class="statusClass(t.status)">{{ statusLabel(t.status) }}</span>
              </div>
              <p class="text-sm text-dark-500 mt-1.5 flex items-center gap-3 flex-wrap">
                <span>📅 {{ t.start_date || '日期待定' }}</span>
                <span v-if="t.venue">📍 {{ t.venue }}</span>
                <span>👥 {{ teams.length }} 支球队</span>
                <span>⏱ {{ t.quarters }}节 × {{ Math.round((t.quarter_seconds || 600) / 60) }}分钟</span>
                <span class="text-primary-400/80">{{ stageModeLabel }}</span>
              </p>
            </div>
          </div>
        </div>

        <!-- 小组赛进度条 -->
        <div v-if="t.status === 'group_stage'" class="mt-3">
          <div class="flex items-center justify-between text-xs mb-1.5">
            <span class="text-primary-400">{{ t.group_count === 1 ? '循环赛' : '小组赛' }}进度</span>
            <span class="text-dark-400">{{ groupDoneCount }} / {{ groupTotal }} 场已结束</span>
          </div>
          <div class="h-1.5 rounded-full bg-dark-800 overflow-hidden">
            <div class="h-full rounded-full bg-gradient-to-r from-primary-500 to-primary-400 transition-all duration-500"
              :style="{ width: groupTotal ? (groupDoneCount / groupTotal * 100) + '%' : '0%' }"></div>
          </div>
        </div>

        <!-- 操作 -->
        <div class="flex items-center gap-2 mt-4 flex-wrap">
          <router-link to="/regulation"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold
                   bg-gradient-to-r from-amber-600/25 to-orange-500/15 text-amber-300
                   border border-amber-500/40 hover:from-amber-600/40 hover:to-orange-500/25
                   hover:border-amber-400/60 transition-all duration-200">
            📜 赛事规程
          </router-link>
          <button @click="load" class="btn-secondary btn-sm" :disabled="busy">刷新</button>
          <button v-if="auth.isSuperAdmin && t.status === 'draft' && undrawnTeams.length > 0" @click="drawAllForTeams"
            class="btn-primary btn-sm" :disabled="busy">
            🎲 超管一键代抽（{{ undrawnTeams.length }} 队）
          </button>
          <button v-if="canManage && allGroupDone && !hasPlayoffs" @click="createPlayoffs" class="btn-primary btn-sm" :disabled="busy">
            生成淘汰赛对阵
          </button>
          <span v-else-if="canManage && t.status === 'group_stage' && !allGroupDone" class="text-xs text-dark-600">
            小组赛全部结束后可生成淘汰赛
          </span>
          <button v-if="auth.isAdmin" @click="removeTournament" class="btn-danger btn-sm !py-1.5" :disabled="busy">删除</button>
        </div>
      </div>

      <!-- ═══ 公告栏（实时播报）═══ -->
      <div class="card card-body mb-5 border-purple-500/25 bg-gradient-to-br from-purple-950/30 to-dark-900">
        <div class="flex items-center justify-between mb-3">
          <h2 class="section-title flex items-center gap-2">
            📢 赛事公告
            <span class="flex items-center gap-1 text-[10px] text-success font-medium">
              <span class="w-1.5 h-1.5 rounded-full bg-success animate-pulse"></span>实时
            </span>
          </h2>
          <span class="text-xs text-dark-600">{{ announcements.length }} 条播报</span>
        </div>
        <div v-if="announcements.length" class="max-h-64 overflow-y-auto space-y-1.5 pr-1">
          <div v-for="(a, idx) in announcements" :key="a.id"
            class="flex items-start gap-2.5 px-3 py-2 rounded-xl text-sm transition-colors"
            :class="idx === 0 && a._new
              ? 'bg-purple-500/15 border border-purple-500/30 text-white animate-fade-in-up'
              : 'bg-dark-800/40 text-dark-300'">
            <span class="flex-shrink-0 mt-0.5">{{ annIcon(a.type) }}</span>
            <span class="flex-1 leading-relaxed">{{ a.content }}</span>
            <span class="text-[10px] text-dark-600 flex-shrink-0 mt-1">{{ fmtClock(a.created_at) }}</span>
          </div>
        </div>
        <p v-else class="text-sm text-dark-500 py-4 text-center">
          暂无播报 —— 抽签开始后，抽签结果与赛况将在这里实时播报 🎙️
        </p>
      </div>

      <!-- ═══ 抽签仪式（draft 阶段）═══ -->
      <div v-if="t.status === 'draft'" class="card card-body mb-5">
        <div class="flex items-center justify-between mb-1">
          <h2 class="section-title">🎲 抽签仪式</h2>
          <span class="text-xs text-dark-500">{{ drawnCount }} / {{ teams.length }} 已抽</span>
        </div>
        <p class="text-sm text-dark-500 mb-4">
          各球队管理员登录后点击本队卡片的「抽签」按钮，随机抽取
          {{ t.group_count === 1 ? '出场序号' : '所在小组与号位' }}，结果将在上方公告栏实时播报。
          超管可为任意未抽球队代抽。全部抽签完成后自动生成{{ t.group_count === 1 ? '单循环' : '小组赛' }}赛程。
        </p>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
          <div v-for="tt in teams" :key="tt.team.id"
            class="rounded-2xl border p-3.5 transition-all duration-300"
            :class="tt.group_name
              ? 'border-success/40 bg-success/5'
              : 'border-dark-700 bg-dark-800/50 hover:border-purple-500/50 hover:bg-purple-950/20'">
            <div class="flex items-center gap-2 mb-2.5">
              <span class="w-3 h-3 rounded-full flex-shrink-0" :style="{ background: tt.team.color || '#1565c0' }"></span>
              <span class="font-bold text-white text-sm truncate">{{ tt.team.name }}</span>
            </div>
            <!-- 已抽：显示结果 -->
            <div v-if="tt.group_name" class="text-center">
              <p class="text-lg font-black text-success">
                {{ t.group_count === 1 ? tt.draw_order + ' 号位' : tt.group_name + ' 组 · ' + slotNo(tt) + '号位' }}
              </p>
              <p class="text-[10px] text-dark-600 mt-0.5">{{ tt.drawn_at ? '抽签于 ' + fmtClock(tt.drawn_at) : '' }}</p>
            </div>
            <!-- 未抽：抽签按钮（仅本队队员 / 超管代抽） -->
            <button v-else-if="drawingTeamId === tt.team.id" disabled
              class="w-full py-2 rounded-xl text-sm font-bold bg-purple-500/20 text-purple-300 border border-purple-500/40">
              <span class="inline-block animate-bounce">🎲</span> 抽签中…
            </button>
            <button v-else-if="canDrawFor(tt)" @click="drawLottery(tt)"
              class="w-full py-2 rounded-xl text-sm font-bold
                     bg-gradient-to-r from-purple-600 to-indigo-600 text-white
                     hover:from-purple-500 hover:to-indigo-500
                     shadow-lg shadow-purple-600/25
                     transition-all duration-200 hover:scale-[1.03] active:scale-95">
              🎲 {{ auth.isSuperAdmin && !myTeamIds.has(tt.team.id) ? '超管代抽' : '抽签' }}
            </button>
            <p v-else-if="!auth.isLoggedIn" class="text-center text-xs text-dark-600 py-2">
              <router-link to="/login" class="text-primary-400 hover:underline">登录</router-link>后可抽签
            </p>
            <p v-else class="text-center text-xs text-dark-600 py-2">
              等待本队管理员抽签
            </p>
          </div>
        </div>
      </div>

      <!-- ═══ 淘汰赛对阵图（专业 Bracket）═══ -->
      <div v-if="bracketCols.length" class="card card-body mb-5">
        <h2 class="section-title mb-4">🗺️ 淘汰赛对阵图</h2>
        <div class="overflow-x-auto pb-1">
          <div class="flex items-stretch min-w-max">
            <div v-for="(col, ci) in bracketCols" :key="col.key" class="flex flex-col" :class="ci > 0 ? 'pl-4' : ''">
              <p class="text-center text-[10px] font-bold tracking-[0.25em] text-dark-500 mb-3 flex-shrink-0 uppercase">{{ col.title }}</p>
              <div class="flex-1 flex flex-col">
                <div v-for="(m, mi) in col.matches" :key="m.id" class="relative flex-1 flex items-center min-h-[108px]">
                  <!-- 连接线：左入 / 右出 / 竖线汇合 -->
                  <span v-if="ci > 0" class="bk-line bk-line-l"></span>
                  <span v-if="ci < bracketCols.length - 1 || podium.champion" class="bk-line bk-line-r"></span>
                  <span v-if="ci < bracketCols.length - 1 && mi % 2 === 0" class="bk-line bk-line-v"></span>
                  <!-- 对阵卡片 -->
                  <component :is="m.game_id ? 'router-link' : 'div'"
                    :to="m.game_id ? `/games/${m.game_id}?from=/tournaments/${id}` : undefined"
                    class="block w-full">
                    <div class="rounded-xl border overflow-hidden transition-all"
                      :class="m.stage === 'final'
                        ? 'border-accent-500/50 bg-gradient-to-br from-accent-950/40 to-dark-900 shadow-lg shadow-accent-600/10'
                        : m.game?.status === 'active'
                          ? 'border-danger/50 bg-dark-850'
                          : 'border-dark-700 bg-dark-850 hover:border-dark-500'">
                      <div class="flex items-center justify-between px-2.5 py-1 text-[10px] text-dark-500 bg-dark-900/70">
                        <span class="font-bold">#{{ m.match_order }}</span>
                        <span :class="m.game?.status === 'active' ? 'text-danger font-bold' : ''">
                          {{ m.game?.status === 'finished' ? '终' : m.game?.status === 'active' ? '进行中' : m.scheduled_at ? formatTime(m.scheduled_at) : '待定' }}
                        </span>
                      </div>
                      <div class="px-2.5 py-1.5">
                        <!-- 主队 -->
                        <div class="flex items-center justify-between gap-2">
                          <span class="flex items-center gap-1.5 min-w-0">
                            <span class="w-1.5 h-1.5 rounded-full flex-shrink-0" :style="{ background: m.home_team_id ? teamColor(m.home_team_id) : '#475569' }"></span>
                            <span class="text-sm truncate"
                              :class="m.game?.status === 'finished' && m.game.home_score > m.game.away_score ? 'text-success font-bold'
                                : m.home_team_id ? 'text-white' : 'text-dark-600 italic'">
                              {{ teamName(m.home_team_id) || feederLabel(m.home_from) }}
                            </span>
                          </span>
                          <span class="text-sm font-black tabular-nums flex-shrink-0"
                            :class="m.game?.status === 'finished' && m.game.home_score > m.game.away_score ? 'text-success' : 'text-dark-400'">
                            {{ m.game?.status === 'finished' || m.game?.status === 'active' ? m.game.home_score : '–' }}
                          </span>
                        </div>
                        <div class="border-t border-dashed border-dark-700/60 my-1"></div>
                        <!-- 客队 -->
                        <div class="flex items-center justify-between gap-2">
                          <span class="flex items-center gap-1.5 min-w-0">
                            <span class="w-1.5 h-1.5 rounded-full flex-shrink-0" :style="{ background: m.away_team_id ? teamColor(m.away_team_id) : '#475569' }"></span>
                            <span class="text-sm truncate"
                              :class="m.game?.status === 'finished' && m.game.away_score > m.game.home_score ? 'text-success font-bold'
                                : m.away_team_id ? 'text-white' : 'text-dark-600 italic'">
                              {{ teamName(m.away_team_id) || feederLabel(m.away_from) }}
                            </span>
                          </span>
                          <span class="text-sm font-black tabular-nums flex-shrink-0"
                            :class="m.game?.status === 'finished' && m.game.away_score > m.game.home_score ? 'text-success' : 'text-dark-400'">
                            {{ m.game?.status === 'finished' || m.game?.status === 'active' ? m.game.away_score : '–' }}
                          </span>
                        </div>
                      </div>
                    </div>
                  </component>
                </div>
              </div>
            </div>
            <!-- 冠军列 -->
            <div v-if="podium.champion" class="flex flex-col pl-4">
              <p class="text-center text-[10px] font-bold tracking-[0.25em] text-accent-400/80 mb-3 flex-shrink-0 uppercase">冠军</p>
              <div class="relative flex-1 flex items-center">
                <span class="bk-line bk-line-l"></span>
                <div class="text-center px-2">
                  <p class="text-4xl drop-shadow-[0_0_15px_rgba(251,191,36,0.5)]">🏆</p>
                  <p class="text-[9px] tracking-[0.3em] text-dark-500 mt-1.5">CHAMPION</p>
                  <p class="text-sm font-black text-accent-400 mt-1 max-w-28 mx-auto leading-tight">{{ podium.champion }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- 季军争夺战（半决赛败者，独立于主线对阵） -->
        <div v-if="thirdPlaceMatch" class="mt-3 rounded-xl border border-orange-700/40 bg-orange-950/10 px-3.5 py-2.5 flex items-center gap-3 flex-wrap">
          <span class="text-lg flex-shrink-0">🥉</span>
          <span class="text-xs text-orange-300/90 font-bold flex-shrink-0">季军争夺战</span>
          <span class="text-sm text-white flex-1 min-w-0 text-center truncate">
            <span :class="isWinner(thirdPlaceMatch, 'home') ? 'text-success font-bold' : ''">{{ teamName(thirdPlaceMatch.home_team_id) || feederLabel(thirdPlaceMatch.home_from, true) }}</span>
            <template v-if="thirdPlaceMatch.game?.status === 'finished' || thirdPlaceMatch.game?.status === 'active'">
              <span class="mx-2 font-black tabular-nums text-base">{{ thirdPlaceMatch.game.home_score }} : {{ thirdPlaceMatch.game.away_score }}</span>
            </template>
            <span v-else class="mx-2 text-dark-600 text-xs font-bold">VS</span>
            <span :class="isWinner(thirdPlaceMatch, 'away') ? 'text-success font-bold' : ''">{{ teamName(thirdPlaceMatch.away_team_id) || feederLabel(thirdPlaceMatch.away_from, true) }}</span>
          </span>
          <router-link v-if="thirdPlaceMatch.game_id" :to="`/games/${thirdPlaceMatch.game_id}?from=/tournaments/${id}`"
            class="btn-secondary btn-sm !py-1 !text-[11px] flex-shrink-0">查看</router-link>
        </div>
      </div>

      <!-- ═══ 分组积分榜（含胜率可视化，全阶段常显）═══ -->
      <div v-if="groupNames.length" class="grid gap-4 mb-5" :class="groupNames.length > 1 ? 'sm:grid-cols-2' : ''">
        <div v-for="g in groupNames" :key="g" class="card card-body">
          <div class="flex items-center justify-between mb-3">
            <h2 class="section-title">{{ t.group_count === 1 ? '循环赛积分榜' : g + ' 组' }}</h2>
            <span v-if="t.group_count === 1" class="text-xs text-dark-500">前 {{ t.advance_per_group }} 名出线</span>
          </div>

          <table v-if="standingsByGroup[g]?.length" class="w-full text-sm">
            <thead>
              <tr class="text-dark-500 text-xs">
                <th class="text-left py-1.5 pr-2">#</th>
                <th class="text-left py-1.5 pr-2">球队</th>
                <th class="text-center py-1.5 px-1">赛</th>
                <th class="text-center py-1.5 px-1">胜</th>
                <th class="text-center py-1.5 px-1">负</th>
                <th class="text-center py-1.5 px-1">净胜</th>
                <th class="text-center py-1.5 pl-1">积分</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, idx) in standingsByGroup[g]" :key="row.team_id"
                class="border-t border-dark-800"
                :class="idx < t.advance_per_group ? 'text-white' : 'text-dark-400'">
                <td class="py-2 pr-2">
                  <span v-if="idx < t.advance_per_group" class="inline-flex w-5 h-5 rounded-full bg-success/20 text-success text-xs items-center justify-center font-bold">{{ idx + 1 }}</span>
                  <span v-else class="text-dark-600">{{ idx + 1 }}</span>
                </td>
                <td class="py-2 pr-2">
                  <div class="flex items-center gap-1.5">
                    <span class="w-2 h-2 rounded-full flex-shrink-0" :style="{ background: row.team_color || '#1565c0' }"></span>
                    <span class="font-medium truncate">{{ row.team_name }}</span>
                  </div>
                  <!-- 胜率条 -->
                  <div class="h-1 rounded-full bg-dark-800 mt-1 overflow-hidden flex" style="width: 72px">
                    <div class="h-full bg-success/80" :style="{ width: (row.played ? row.wins / row.played * 100 : 0) + '%' }"></div>
                  </div>
                </td>
                <td class="text-center py-2 px-1">{{ row.played }}</td>
                <td class="text-center py-2 px-1 text-success font-medium">{{ row.wins }}</td>
                <td class="text-center py-2 px-1">{{ row.losses }}</td>
                <td class="text-center py-2 px-1">{{ row.diff > 0 ? '+' + row.diff : row.diff }}</td>
                <td class="text-center py-2 pl-1 font-bold text-accent-400">{{ row.points }}</td>
              </tr>
            </tbody>
          </table>

          <!-- 无完赛场次：显示成员 -->
          <div v-else class="space-y-2">
            <div v-for="(tt, idx) in teamsByGroup[g]" :key="tt.team.id"
              class="flex items-center gap-2.5 text-sm">
              <span class="text-dark-600 w-4 text-xs">{{ idx + 1 }}</span>
              <span class="w-2.5 h-2.5 rounded-full" :style="{ background: tt.team.color || '#1565c0' }"></span>
              <span class="text-white font-medium">{{ tt.team.name }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 抽签前（draft）：参赛球队总览 -->
      <div v-else-if="teams.length" class="card card-body mb-5">
        <div class="flex items-center justify-between mb-3">
          <h2 class="section-title">🏀 参赛球队（{{ teams.length }}）</h2>
          <span class="text-xs text-dark-500">完成抽签后显示分组积分榜</span>
        </div>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
          <div v-for="(tt, idx) in teams" :key="tt.team.id"
            class="flex items-center gap-2.5 text-sm">
            <span class="text-dark-600 w-4 text-xs">{{ idx + 1 }}</span>
            <span class="w-2.5 h-2.5 rounded-full" :style="{ background: tt.team.color || '#1565c0' }"></span>
            <span class="text-white font-medium truncate">{{ tt.team.name }}</span>
          </div>
        </div>
      </div>

      <!-- ═══ 开启赛程引导（管理员 · 小组赛未排完/未建完时）═══ -->
      <div v-if="canManage && t.status === 'group_stage' && (uncreatedGroupMatches.length || untimedPendingMatches.length)"
        class="card card-body mb-5 border-primary-500/30 bg-gradient-to-r from-primary-950/40 to-dark-900">
        <div class="flex items-center justify-between gap-3 flex-wrap">
          <div class="min-w-0">
            <p class="font-bold text-white flex items-center gap-2">
              📣 开启赛程
            </p>
            <p class="text-xs text-dark-400 mt-1.5 leading-relaxed">
              <template v-if="uncreatedGroupMatches.length">还有 {{ uncreatedGroupMatches.length }} 场未创建比赛、</template><template v-if="untimedPendingMatches.length">{{ untimedPendingMatches.length }} 场未安排时间。</template>
              建议先「快速排期」批量设置开赛时间，再一键创建比赛（自动带上时间，场地默认德泰科技园篮球场）。
            </p>
          </div>
          <div class="flex gap-2 flex-shrink-0">
            <button @click="openSched" class="btn-secondary btn-sm" :disabled="busy">⚡ 快速排期</button>
            <button v-if="uncreatedGroupMatches.length" @click="createAllGroupGames" class="btn-primary btn-sm" :disabled="busy">
              一键创建全部比赛
            </button>
          </div>
        </div>
      </div>

      <!-- ═══ 小组赛对阵图（按组 · 按轮次）═══ -->
      <div v-if="groupVs.length" class="mb-5">
        <div class="flex items-center justify-between mb-3">
          <h2 class="section-title">📋 {{ t.group_count === 1 ? '循环赛对阵表' : '小组赛对阵图' }}</h2>
          <button v-if="canManage && schedTargets.length && t.status === 'group_stage'" @click="openSched"
            class="btn-secondary btn-sm !py-1.5">⚡ 快速排期</button>
        </div>

        <!-- 快速排期面板 -->
        <div v-if="schedOpen" id="quick-schedule" class="card card-body mb-4 border-primary-500/30">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-bold text-white text-sm">⚡ 快速排期 · {{ schedRows.length }} 场未开赛</h3>
            <button @click="schedOpen = false" class="text-dark-500 hover:text-white text-xs transition-colors">✕ 关闭</button>
          </div>
          <div class="flex items-end gap-2 flex-wrap mb-3">
            <div>
              <label class="text-[10px] text-dark-500 block mb-1">开始日期</label>
              <input v-model="schedDate" type="date" :disabled="schedSaving"
                class="bg-dark-800 border border-dark-700 rounded-lg px-2 py-1.5 text-xs text-white focus:border-primary-500 outline-none" />
            </div>
            <div>
              <label class="text-[10px] text-dark-500 block mb-1">首场时间</label>
              <input v-model="schedStart" type="time" :disabled="schedSaving"
                class="bg-dark-800 border border-dark-700 rounded-lg px-2 py-1.5 text-xs text-white focus:border-primary-500 outline-none" />
            </div>
            <div>
              <label class="text-[10px] text-dark-500 block mb-1">每场间隔</label>
              <select v-model.number="schedInterval" :disabled="schedSaving"
                class="bg-dark-800 border border-dark-700 rounded-lg px-2 py-1.5 text-xs text-white focus:border-primary-500 outline-none">
                <option :value="60">60 分钟</option>
                <option :value="90">90 分钟</option>
                <option :value="120">120 分钟</option>
              </select>
            </div>
            <button @click="fillSchedPreview" class="btn-secondary btn-sm" :disabled="schedSaving">自动生成时间</button>
          </div>
          <p class="text-[10px] text-dark-600 mb-2.5">
            按场次顺序自动排：12:00–14:00 跳过午休，21:00 后顺延至次日 10:00。生成后可逐场修改再保存；已创建的比赛会同步更新时间。
          </p>
          <div class="space-y-1.5 max-h-72 overflow-y-auto pr-1">
            <div v-for="r in schedRows" :key="r.id" class="flex items-center gap-2">
              <span class="text-[10px] text-dark-400 w-28 sm:w-52 truncate flex-shrink-0">{{ r.label }}</span>
              <input v-model="r.local" type="datetime-local" :disabled="schedSaving"
                class="bg-dark-800 border border-dark-700 rounded-lg px-2 py-1 text-[11px] text-white focus:border-primary-500 outline-none flex-1 min-w-[145px]" />
            </div>
          </div>
          <div class="flex justify-end gap-2 mt-3">
            <button @click="saveAllSched" class="btn-primary btn-sm" :disabled="schedSaving || !schedRows.length">
              {{ schedSaving ? '保存中…' : `💾 保存全部（${schedRows.length} 场）` }}
            </button>
          </div>
        </div>

        <div class="grid gap-4" :class="groupVs.length > 1 ? 'sm:grid-cols-2' : ''">
          <div v-for="g in groupVs" :key="g.group" class="card card-body">
            <div class="flex items-center justify-between mb-2">
              <h3 class="font-bold text-white text-sm">{{ t.group_count === 1 ? '出场顺序' : g.group + ' 组' }}</h3>
              <span class="text-[10px] text-dark-600">{{ g.rounds.length }} 轮 · {{ g.rounds.reduce((s, r) => s + r.matches.length, 0) }} 场</span>
            </div>
            <div v-for="r in g.rounds" :key="r.round">
              <p class="text-[10px] text-dark-600 font-bold tracking-wider mt-2.5 mb-1 px-1">第 {{ r.round }} 轮</p>
              <div v-for="m in r.matches" :key="m.id">
                <!-- 对阵行 -->
                <component :is="m.game_id ? 'router-link' : 'div'"
                  :to="m.game_id ? `/games/${m.game_id}?from=/tournaments/${id}` : undefined"
                  class="flex items-center gap-2 px-2 py-2 rounded-lg transition-colors"
                  :class="m.game_id ? 'hover:bg-dark-800/60 cursor-pointer' : ''">
                  <span class="flex-1 flex items-center justify-end gap-1.5 min-w-0">
                    <span class="text-sm truncate" :class="isWinner(m, 'home') ? 'text-success font-bold' : 'text-dark-200'">{{ teamName(m.home_team_id) }}</span>
                    <span class="w-1.5 h-1.5 rounded-full flex-shrink-0" :style="{ background: teamColor(m.home_team_id) }"></span>
                  </span>
                  <span class="flex-shrink-0 text-center min-w-[68px]">
                    <template v-if="m.game?.status === 'finished' || m.game?.status === 'active'">
                      <span class="text-sm font-black tabular-nums" :class="isWinner(m, 'home') ? 'text-success' : 'text-white'">{{ m.game.home_score }}</span>
                      <span class="text-dark-600 mx-1">:</span>
                      <span class="text-sm font-black tabular-nums" :class="isWinner(m, 'away') ? 'text-success' : 'text-white'">{{ m.game.away_score }}</span>
                    </template>
                    <span v-else class="text-[10px] text-dark-600 font-bold">VS</span>
                  </span>
                  <span class="flex-1 flex items-center gap-1.5 min-w-0">
                    <span class="w-1.5 h-1.5 rounded-full flex-shrink-0" :style="{ background: teamColor(m.away_team_id) }"></span>
                    <span class="text-sm truncate" :class="isWinner(m, 'away') ? 'text-success font-bold' : 'text-dark-200'">{{ teamName(m.away_team_id) }}</span>
                  </span>
                  <span class="text-[10px] text-dark-600 flex-shrink-0 w-14 text-right hidden sm:block">
                    {{ m.scheduled_at ? formatTime(m.scheduled_at) : '' }}
                  </span>
                  <button v-if="canManage && (!m.game_id || m.game?.status === 'pending')" @click.prevent="toggleEdit(m)"
                    class="flex-shrink-0 px-2 py-1 rounded-lg text-[10px] font-bold border border-primary-500/40 text-primary-300 bg-primary-500/10 hover:bg-primary-500/25 transition-colors"
                    :title="m.game_id ? '调整时间 / 场地' : '设置时间 / 创建比赛'">
                    ⚙️ {{ m.game_id ? '改时间' : '设置' }}
                  </button>
                </component>
                <!-- 管理员：行内编辑时间 / 场地（已创建的比赛保存后同步更新） -->
                <div v-if="editingMatchId === m.id" class="flex flex-wrap items-center gap-2 px-2 pb-2">
                  <input v-model="m._local" type="datetime-local" @change="m._dirty = true" :disabled="busy"
                    class="bg-dark-800 border border-dark-700 rounded-lg px-2 py-1 text-[11px] text-white focus:border-primary-500 outline-none min-w-[145px] flex-1" />
                  <input v-model="m._venue" type="text" placeholder="场地（默认 德泰科技园篮球场）" @change="m._dirty = true" :disabled="busy"
                    class="bg-dark-800 border border-dark-700 rounded-lg px-2 py-1 text-[11px] text-white focus:border-primary-500 outline-none w-full sm:w-auto sm:flex-1 min-w-[120px]" />
                  <div class="flex gap-1.5 ml-auto">
                    <button v-if="m._dirty" @click="saveSchedule(m)" class="btn-primary btn-sm !py-1 !text-[11px] whitespace-nowrap" :disabled="busy">保存</button>
                    <button v-if="!m.game_id && m.home_team_id && m.away_team_id" @click="createGame(m)" class="btn-accent btn-sm !py-1 !text-[11px] whitespace-nowrap" :disabled="busy">创建比赛</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ═══ 球员数据榜 ═══ -->
      <div v-if="topPlayers.length" class="card card-body mb-5">
        <div class="flex items-center justify-between mb-4 flex-wrap gap-2">
          <h2 class="section-title">⭐ 球员数据榜</h2>
          <div class="flex gap-1 flex-wrap bg-dark-800 rounded-xl p-1">
            <button v-for="k in statKeys" :key="k.key" @click="statTab = k.key"
              class="px-3 py-1 rounded-lg text-xs font-bold transition-all whitespace-nowrap"
              :class="statTab === k.key ? 'bg-primary-600 text-white shadow' : 'text-dark-400 hover:text-white'">
              {{ k.label }}
            </button>
          </div>
        </div>
        <div class="space-y-2.5">
          <div v-for="(p, idx) in topPlayers" :key="p.player_id"
            class="flex items-center gap-3">
            <!-- 排名 -->
            <span class="w-6 h-6 rounded-lg flex items-center justify-center text-xs font-black flex-shrink-0"
              :class="idx === 0 ? 'bg-gradient-to-br from-amber-400 to-orange-500 text-dark-900'
                : idx === 1 ? 'bg-dark-400/60 text-white'
                : idx === 2 ? 'bg-orange-800/60 text-orange-300'
                : 'bg-dark-800 text-dark-500'">
              {{ idx + 1 }}
            </span>
            <span class="w-2 h-2 rounded-full flex-shrink-0" :style="{ background: teamColor(p.team_id) }"></span>
            <span class="text-sm font-semibold text-white truncate w-20 sm:w-28 flex-shrink-0">{{ p.name }}</span>
            <div class="flex-1 h-6 rounded-lg bg-dark-800 overflow-hidden flex items-center">
              <div class="h-full rounded-lg transition-all duration-700 flex items-center justify-end pr-2"
                :class="statTab === 'pts' ? 'bg-gradient-to-r from-accent-600/50 to-accent-500/80'
                  : statTab === 'reb' ? 'bg-gradient-to-r from-primary-700/50 to-primary-500/80'
                  : statTab === 'ast' ? 'bg-gradient-to-r from-purple-700/50 to-purple-500/80'
                  : 'bg-gradient-to-r from-emerald-700/50 to-emerald-500/80'"
                :style="{ width: Math.max(12, p[statTab] / topPlayers[0][statTab] * 100) + '%' }">
                <span class="text-xs font-black text-white">{{ p[statTab] }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ═══ 淘汰赛赛程（管理 / 详情入口）═══ -->
      <div v-if="sections.length" class="mb-6">
        <h2 class="section-title mb-3">⚔️ 淘汰赛赛程</h2>
        <div class="grid gap-3" :class="sections.length > 2 ? 'sm:grid-cols-2' : ''">
          <div v-for="sec in sections" :key="sec.key" class="card card-body">
            <div class="flex items-center justify-between mb-3">
              <h3 class="font-bold text-white text-sm">{{ sec.title }}</h3>
              <span class="text-[10px] text-dark-600">{{ sec.matches.length }} 场</span>
            </div>
            <div class="space-y-2">
              <div v-for="m in sec.matches" :key="m.id"
                class="rounded-xl border border-dark-800 bg-dark-850/60 px-3 py-2.5">
                <!-- 场次信息 -->
                <div class="flex items-center justify-between gap-3 flex-wrap">
                  <div class="flex items-center gap-2 text-xs text-dark-500">
                    <span class="w-6 h-6 rounded-lg bg-dark-800 text-dark-300 flex items-center justify-center font-bold">#{{ m.match_order }}</span>
                  </div>
                  <span class="badge" :class="gameBadgeClass(m)">{{ gameBadge(m) }}</span>
                </div>

                <!-- 对阵 -->
                <div class="flex items-center justify-center gap-4 mt-2.5">
                  <div class="flex-1 text-right min-w-0">
                    <span class="font-bold truncate inline-block max-w-full" :class="isWinner(m, 'home') ? 'text-success' : 'text-white'">
                      {{ teamName(m.home_team_id) || feederLabel(m.home_from, m.stage === 'third_place') }}
                    </span>
                  </div>
                  <div class="text-center flex-shrink-0">
                    <template v-if="m.game?.status === 'finished' || m.game?.status === 'active'">
                      <span class="text-2xl font-black tabular-nums" :class="isWinner(m, 'home') ? 'text-success' : 'text-white'">{{ m.game.home_score }}</span>
                      <span class="text-dark-600 mx-1.5">:</span>
                      <span class="text-2xl font-black tabular-nums" :class="isWinner(m, 'away') ? 'text-success' : 'text-white'">{{ m.game.away_score }}</span>
                    </template>
                    <template v-else>
                      <span class="text-dark-600 font-bold">VS</span>
                    </template>
                  </div>
                  <div class="flex-1 text-left min-w-0">
                    <span class="font-bold truncate inline-block max-w-full" :class="isWinner(m, 'away') ? 'text-success' : 'text-white'">
                      {{ teamName(m.away_team_id) || feederLabel(m.away_from, m.stage === 'third_place') }}
                    </span>
                  </div>
                </div>

                <!-- 时间 / 场地（管理） -->
                <div class="flex flex-wrap items-center gap-2 mt-2.5" v-if="canManage && !m.game">
                  <input v-model="m._local" type="datetime-local" @change="m._dirty = true" :disabled="busy"
                    class="bg-dark-800 border border-dark-700 rounded-xl px-2.5 py-1.5 text-xs text-white focus:border-primary-500 outline-none min-w-[150px] flex-1" />
                  <input v-model="m._venue" type="text" placeholder="场地（默认锦标赛场地）" @change="m._dirty = true" :disabled="busy"
                    class="bg-dark-800 border border-dark-700 rounded-xl px-2.5 py-1.5 text-xs text-white focus:border-primary-500 outline-none w-full sm:w-auto sm:flex-1 min-w-[130px]" />
                  <button v-if="m._dirty" @click="saveSchedule(m)" class="btn-primary btn-sm !py-1.5 !text-xs whitespace-nowrap">保存</button>
                </div>
                <p v-else-if="m.scheduled_at || m.venue" class="text-xs text-dark-500 mt-2.5 text-center">
                  <span v-if="m.scheduled_at">⏰ {{ formatTime(m.scheduled_at) }}</span>
                  <span v-if="m.venue" class="ml-2">📍 {{ m.venue }}</span>
                </p>

                <!-- 操作 -->
                <div class="flex justify-center gap-2 mt-2.5">
                  <button v-if="canManage && !m.game_id && m.home_team_id && m.away_team_id"
                    @click="createGame(m)" class="btn-primary btn-sm" :disabled="busy">
                    创建比赛
                  </button>
                  <router-link v-if="m.game_id" :to="`/games/${m.game_id}?from=/tournaments/${id}`" class="btn-secondary btn-sm">查看比赛</router-link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <p v-if="msg" class="text-sm px-3 py-2 rounded-xl"
        :class="msgType === 'success' ? 'bg-success/10 text-success border border-success/20' : 'bg-danger/10 text-danger-light border border-danger/20'">
        {{ msg }}
      </p>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/utils/supabase'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const id = route.params.id
const t = ref({})
const teams = ref([])
const matches = ref([])
const standings = ref([])
const announcements = ref([])
const statRows = ref([])
const loading = ref(true)
const loadError = ref('')
const busy = ref(false)
const drawingTeamId = ref(null)
const msg = ref('')
const msgType = ref('error')
const statTab = ref('pts')
const statKeys = [
  { key: 'pts', label: '得分' },
  { key: 'reb', label: '篮板' },
  { key: 'ast', label: '助攻' },
  { key: 'stl', label: '抢断' }
]

const canManage = computed(() => auth.isAdmin || auth.role === 'recorder')

// 当前登录用户所属球队（与后端 draw_lottery 校验口径一致：
// players.user_id 直接绑定，或球员姓名 = 账号用户名/显示名）
const myTeamIds = ref(new Set())
async function loadMyTeams() {
  if (!auth.user?.id) { myTeamIds.value = new Set(); return }
  try {
    const conds = [`user_id.eq.${auth.user.id}`]
    for (const n of [auth.user.username, auth.user.display_name]) {
      if (n && !n.includes(',') && !n.includes('(')) conds.push(`name.eq.${n}`)
    }
    const { data } = await supabase
      .from('players')
      .select('team_players(team_id)')
      .or(conds.join(','))
    myTeamIds.value = new Set((data || []).flatMap(p => (p.team_players || []).map(x => x.team_id)))
  } catch (e) {
    console.warn('[TournamentDetail] 查询所属球队失败:', e)
    myTeamIds.value = new Set()
  }
}
const canDrawFor = tt => auth.isSuperAdmin || myTeamIds.value.has(tt.team.id)

const STATUS = {
  draft: { label: '待抽签', class: 'bg-dark-700 text-dark-300' },
  group_stage: { label: '小组赛', class: 'bg-primary-600/20 text-primary-400 border border-primary-600/30' },
  playoffs: { label: '淘汰赛', class: 'bg-accent-600/20 text-accent-400 border border-accent-600/30' },
  finished: { label: '已结束', class: 'bg-success/10 text-success border border-success/20' }
}
const statusLabel = s => {
  if (s === 'group_stage' && t.value.group_count === 1) return '循环赛'
  return STATUS[s]?.label || s
}
const statusClass = s => STATUS[s]?.class || ''

const GAME_STATUS = {
  pending: { label: '未开始', class: 'bg-dark-700 text-dark-300' },
  active: { label: '进行中', class: 'bg-danger/15 text-danger-light border border-danger/30 animate-pulse' },
  halftime: { label: '中场', class: 'bg-warning/15 text-warning border border-warning/30' },
  finished: { label: '已结束', class: 'bg-success/10 text-success border border-success/20' },
  cancelled: { label: '已取消', class: 'bg-dark-700 text-dark-500' }
}
const gameBadge = m => m.game ? (GAME_STATUS[m.game.status]?.label || m.game.status) : '未创建'
const gameBadgeClass = m => m.game ? (GAME_STATUS[m.game.status]?.class || '') : 'bg-dark-800 text-dark-500 border border-dark-700'

const groupNames = computed(() =>
  [...new Set(teams.value.map(x => x.group_name).filter(Boolean))].sort())

const teamsByGroup = computed(() => {
  const map = {}
  for (const g of groupNames.value) {
    map[g] = teams.value.filter(x => x.group_name === g).sort((a, b) => (a.draw_order || 0) - (b.draw_order || 0))
  }
  return map
})

const standingsByGroup = computed(() => {
  const map = {}
  for (const g of groupNames.value) {
    // 用分组成员打底（确保未开赛也有积分榜），再用视图统计覆盖
    const base = teams.value
      .filter(x => x.group_name === g)
      .sort((a, b) => (a.draw_order || 0) - (b.draw_order || 0))
      .map(tt => ({
        team_id: tt.team.id,
        team_name: tt.team.name,
        team_color: tt.team.color || '#1565c0',
        played: 0, wins: 0, losses: 0,
        pts_for: 0, pts_against: 0, diff: 0, points: 0
      }))
    const byId = {}
    for (const s of standings.value.filter(x => x.group_name === g)) byId[s.team_id] = s
    map[g] = base.map(row => ({ ...row, ...(byId[row.team_id] || {}) }))
      .sort((a, b) => b.points - a.points || b.diff - a.diff || b.pts_for - a.pts_for)
  }
  return map
})

// 抽签进度
const drawnCount = computed(() => teams.value.filter(x => x.group_name).length)
const undrawnTeams = computed(() => teams.value.filter(x => !x.group_name))
const slotNo = tt => teamsByGroup.value[tt.group_name]?.findIndex(x => x.team.id === tt.team.id) + 1 || tt.draw_order

const groupMatches = computed(() => matches.value.filter(m => m.stage === 'group'))
const groupTotal = computed(() => groupMatches.value.length)
const groupDoneCount = computed(() => groupMatches.value.filter(m => m.game?.status === 'finished').length)
const allGroupDone = computed(() => groupTotal.value > 0 && groupDoneCount.value === groupTotal)
const hasPlayoffs = computed(() => matches.value.some(m => m.stage !== 'group'))
const uncreatedGroupMatches = computed(() => groupMatches.value.filter(m => !m.game_id))
// 可排期对象：未创建比赛 或 比赛尚未开始
const schedTargets = computed(() =>
  groupMatches.value
    .filter(m => !m.game_id || m.game?.status === 'pending')
    .sort((a, b) => a.match_order - b.match_order))
const untimedPendingMatches = computed(() => schedTargets.value.filter(m => !m.scheduled_at))

// ── 快速排期 ──
const schedOpen = ref(false)
const schedDate = ref('')
const schedStart = ref('10:00')
const schedInterval = ref(90)
const schedRows = ref([])
const schedSaving = ref(false)

function schedLabel(m) {
  const stage = t.value.group_count === 1
    ? `第${m.round}轮`
    : `${m.group_name || ''}组第${m.round}轮`
  return `#${m.match_order} ${stage} ${teamName(m.home_team_id)} vs ${teamName(m.away_team_id)}`
}

function openSched() {
  if (!schedDate.value) {
    schedDate.value = t.value.start_date || toLocalInput(new Date().toISOString()).slice(0, 10)
  }
  fillSchedPreview()
  schedOpen.value = true
  nextTick(() => {
    document.getElementById('quick-schedule')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  })
}

// 自动预填：从开始日期+首场时间起，按间隔顺排；
// 12:00–14:00 跳过午休，21:00 后顺延至次日 10:00
function fillSchedPreview() {
  let cur = new Date(`${schedDate.value}T${schedStart.value || '10:00'}:00`)
  if (isNaN(cur.getTime())) cur = new Date()
  schedRows.value = schedTargets.value.map(m => {
    const local = toLocalInput(cur.toISOString())
    const next = new Date(cur.getTime() + schedInterval.value * 60000)
    if (next.getHours() >= 21) {
      next.setDate(next.getDate() + 1)
      next.setHours(10, 0, 0, 0)
    } else if (next.getHours() >= 12 && next.getHours() < 14) {
      next.setHours(14, 0, 0, 0)
    }
    cur = next
    return { id: m.id, label: schedLabel(m), local }
  })
}

async function saveAllSched() {
  if (!schedRows.value.length) return
  if (!confirm(`确认保存 ${schedRows.value.length} 场比赛时间？已创建的比赛将同步更新。`)) return
  schedSaving.value = true
  let ok = 0, fail = 0
  try {
    for (const r of schedRows.value) {
      if (!r.local) continue
      const { error } = await supabase.rpc('update_match_schedule', {
        p_match_id: r.id,
        p_scheduled_at: new Date(r.local).toISOString(),
        p_venue: null
      })
      if (error) { fail++; console.warn('[TournamentDetail] 排期失败:', r.id, error.message) }
      else ok++
    }
    if (fail) {
      msg.value = `⚠️ ${ok} 场已保存，${fail} 场失败，请重试`
      msgType.value = 'error'
    } else {
      msg.value = `✅ ${ok} 场比赛时间已保存`
      msgType.value = 'success'
      schedOpen.value = false
    }
    await load()
  } finally {
    schedSaving.value = false
  }
}

// 淘汰赛对阵图（列式 Bracket：四分之一决赛 → 半决赛 → 决赛 → 冠军）
const bracketCols = computed(() => {
  if (!hasPlayoffs.value) return []
  const cols = []
  const qf = matches.value.filter(m => m.stage === 'quarterfinal')
  const sf = matches.value.filter(m => m.stage === 'semifinal')
  const final = matches.value.find(m => m.stage === 'final')
  if (qf.length) cols.push({ key: 'qf', title: '四分之一决赛', matches: qf })
  if (sf.length) cols.push({ key: 'sf', title: '半决赛', matches: sf })
  if (final) cols.push({ key: 'final', title: '决赛', matches: [final] })
  return cols
})
// 季军赛独立于主线对阵（半决赛败者参加）
const thirdPlaceMatch = computed(() => matches.value.find(m => m.stage === 'third_place'))

// 小组赛对阵图（按组 → 按轮次）
const groupVs = computed(() => {
  if (!groupMatches.value.length) return []
  const out = []
  const groups = [...new Set(groupMatches.value.map(m => m.group_name).filter(Boolean))].sort()
  for (const g of groups) {
    const rounds = []
    for (const m of groupMatches.value.filter(x => x.group_name === g)) {
      let r = rounds.find(x => x.round === m.round)
      if (!r) { r = { round: m.round, matches: [] }; rounds.push(r) }
      r.matches.push(m)
    }
    rounds.sort((a, b) => a.round - b.round)
    for (const r of rounds) r.matches.sort((a, b) => a.match_order - b.match_order)
    out.push({ group: g, rounds })
  }
  return out
})

// 对阵图行内编辑
const editingMatchId = ref(null)
function toggleEdit(m) {
  editingMatchId.value = editingMatchId.value === m.id ? null : m.id
}

const podium = computed(() => {
  const out = { champion: null, runnerUp: null, third: null }
  if (t.value.status !== 'finished') return out
  const final = matches.value.find(m => m.stage === 'final')
  if (final?.game?.status === 'finished') {
    if (final.game.home_score > final.game.away_score) {
      out.champion = teamName(final.home_team_id)
      out.runnerUp = teamName(final.away_team_id)
    } else if (final.game.away_score > final.game.home_score) {
      out.champion = teamName(final.away_team_id)
      out.runnerUp = teamName(final.home_team_id)
    }
  }
  const tp = matches.value.find(m => m.stage === 'third_place')
  if (tp?.game?.status === 'finished') {
    if (tp.game.home_score > tp.game.away_score) out.third = teamName(tp.home_team_id)
    else if (tp.game.away_score > tp.game.home_score) out.third = teamName(tp.away_team_id)
  }
  return out
})

const stageModeLabel = computed(() => {
  if (t.value.group_count === 1) {
    return t.value.advance_per_group === 4 ? '循环赛 · 前4名进淘汰赛' : '循环赛 · 前2名争冠'
  }
  if (t.value.group_count === 4) return '4小组 · 前8进淘汰赛'
  return t.value.advance_per_group === 1
    ? '2小组 · 头名争冠'
    : '2小组 · 前4名进淘汰赛'
})

// 球员数据榜（TOP5）
const topPlayers = computed(() => {
  const byPlayer = {}
  for (const r of statRows.value) {
    if (!byPlayer[r.player_id]) {
      byPlayer[r.player_id] = {
        player_id: r.player_id,
        name: r.player?.name || '未知',
        team_id: r.team_id,
        pts: 0, reb: 0, ast: 0, stl: 0
      }
    }
    const b = byPlayer[r.player_id]
    b.pts += r.pts || 0
    b.reb += r.reb || 0
    b.ast += r.ast || 0
    b.stl += r.stl || 0
  }
  return Object.values(byPlayer)
    .sort((a, b) => b[statTab.value] - a[statTab.value])
    .slice(0, 5)
})

// 淘汰赛赛程分组（小组赛由对阵图承载）
const sections = computed(() => {
  const out = []
  for (const m of matches.value.filter(x => x.stage !== 'group')) {
    let sec = out.find(s => s.key === m.stage)
    if (!sec) {
      const title = { quarterfinal: '四分之一决赛', semifinal: '半决赛', third_place: '季军赛', final: '决赛' }[m.stage] || m.stage
      sec = { key: m.stage, title, matches: [] }
      out.push(sec)
    }
    sec.matches.push(m)
  }
  return out
})

function teamName(teamId) {
  if (!teamId) return ''
  return teams.value.find(x => x.team.id === teamId)?.team?.name || '未知球队'
}
function teamColor(teamId) {
  return teams.value.find(x => x.team.id === teamId)?.team?.color || '#1565c0'
}
function feederLabel(feederId, isLoser = false) {
  const f = matches.value.find(x => x.id === feederId)
  return f ? `第 ${f.match_order} 场${isLoser ? '负者' : '胜者'}` : '待定'
}
function isWinner(m, side) {
  if (m.game?.status !== 'finished') return false
  return side === 'home'
    ? m.game.home_score > m.game.away_score
    : m.game.away_score > m.game.home_score
}
function annIcon(type) {
  return { draw: '🎲', schedule: '📅', match: '📋', result: '🏁', playoff: '🔥', info: '🏆' }[type] || '📣'
}
function toLocalInput(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  const p = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}
function formatTime(iso) {
  const d = new Date(iso)
  const p = n => String(n).padStart(2, '0')
  return `${d.getMonth() + 1}/${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}
function fmtClock(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  const p = n => String(n).padStart(2, '0')
  return `${p(d.getHours())}:${p(d.getMinutes())}`
}

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    // 淘汰赛对阵同步（前序比赛结束后填入胜者）
    if (t.value.status === 'playoffs' || hasPlayoffs.value) {
      await supabase.rpc('sync_playoff_teams', { p_tournament_id: id })
    }
    const [rT, rTeams, rMatches, rStandings, rAnn] = await Promise.all([
      supabase.from('tournaments').select('*').eq('id', id).single(),
      supabase.from('tournament_teams')
        .select('group_name, draw_order, drawn_at, team:teams(id, name, color)')
        .eq('tournament_id', id),
      supabase.from('tournament_matches')
        .select('*, game:games(id, status, home_score, away_score)')
        .eq('tournament_id', id)
        .order('match_order'),
      supabase.from('v_tournament_standings').select('*').eq('tournament_id', id),
      supabase.from('tournament_announcements')
        .select('id, type, content, created_at')
        .eq('tournament_id', id)
        .order('created_at', { ascending: false })
        .limit(30)
    ])
    if (rT.error) throw rT.error
    t.value = rT.data
    teams.value = rTeams.data || []
    matches.value = (rMatches.data || []).map(m => ({
      ...m,
      _local: toLocalInput(m.scheduled_at),
      _venue: m.venue || '',
      _dirty: false
    }))
    standings.value = rStandings.data || []
    announcements.value = (rAnn.data || []).map(a => ({ ...a, _new: false }))

    // 球员数据榜（锦标赛内所有比赛的 game_stats）
    const gameIds = matches.value.filter(m => m.game_id).map(m => m.game_id)
    if (gameIds.length) {
      const { data: gs } = await supabase
        .from('game_stats')
        .select('player_id, team_id, pts, reb, ast, stl, player:players(id, name)')
        .in('game_id', gameIds)
      statRows.value = gs || []
    } else {
      statRows.value = []
    }
  } catch (e) {
    loadError.value = e.message || '加载失败'
  } finally {
    loading.value = false
  }
}

// 实时公告订阅
let annChannel = null
function subscribeAnnouncements() {
  if (annChannel) supabase.removeChannel(annChannel)
  annChannel = supabase
    .channel(`tournament-ann:${id}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'tournament_announcements',
      filter: `tournament_id=eq.${id}`
    }, (payload) => {
      if (payload.new) {
        announcements.value = [{ ...payload.new, _new: true }, ...announcements.value].slice(0, 30)
        setTimeout(() => {
          const first = announcements.value[0]
          if (first) first._new = false
        }, 4000)
        // 抽签/赛程变化 → 静默刷新主数据
        if (['draw', 'schedule', 'playoff'].includes(payload.new.type)) {
          refreshCore()
        }
      }
    })
    .subscribe()
}

// 静默刷新核心数据（不显示 loading）
async function refreshCore() {
  try {
    const [rT, rTeams, rMatches, rStandings] = await Promise.all([
      supabase.from('tournaments').select('*').eq('id', id).single(),
      supabase.from('tournament_teams')
        .select('group_name, draw_order, drawn_at, team:teams(id, name, color)')
        .eq('tournament_id', id),
      supabase.from('tournament_matches')
        .select('*, game:games(id, status, home_score, away_score)')
        .eq('tournament_id', id)
        .order('match_order'),
      supabase.from('v_tournament_standings').select('*').eq('tournament_id', id)
    ])
    if (rT.data) t.value = rT.data
    if (rTeams.data) teams.value = rTeams.data
    if (rMatches.data) {
      matches.value = rMatches.data.map(m => ({
        ...m,
        _local: toLocalInput(m.scheduled_at),
        _venue: m.venue || '',
        _dirty: false
      }))
    }
    if (rStandings.data) standings.value = rStandings.data
  } catch (e) {
    console.warn('[TournamentDetail] 静默刷新失败:', e)
  }
}

// 单队抽签（本队队员或超管代抽，后端校验身份）
async function drawLottery(tt) {
  drawingTeamId.value = tt.team.id
  msg.value = ''
  try {
    const drawer = auth.user?.username || null
    const { data, error } = await supabase.rpc('draw_lottery', {
      p_tournament_id: id,
      p_team_id: tt.team.id,
      p_drawer_name: drawer,
      p_user_id: auth.user?.id || null
    })
    if (error) throw error
    msg.value = `✅ ${tt.team.name} 抽中 ${t.value.group_count === 1 ? data.slot_no + ' 号位' : data.group_name + ' 组 ' + data.slot_no + ' 号位'}`
    msgType.value = 'success'
    await refreshCore()
  } catch (e) {
    msg.value = '❌ ' + (e.message || '抽签失败')
    msgType.value = 'error'
  } finally {
    drawingTeamId.value = null
  }
}

// 超管一键代抽（后端仅放行 super_admin）
async function drawAllForTeams() {
  if (!confirm(`确认由超管代抽剩余 ${undrawnTeams.value.length} 支球队？抽签结果不可重做。`)) return
  busy.value = true
  msg.value = ''
  try {
    const { error } = await supabase.rpc('draw_groups', {
      p_tournament_id: id,
      p_user_id: auth.user?.id || null
    })
    if (error) throw error
    msg.value = '✅ 代抽完成，赛程已生成'
    msgType.value = 'success'
    await load()
  } catch (e) {
    msg.value = '❌ ' + (e.message || '抽签失败')
    msgType.value = 'error'
  } finally {
    busy.value = false
  }
}

async function createPlayoffs() {
  if (!confirm('确认生成淘汰赛？将按小组积分交叉对阵（小组第1 对 相邻组第2）。')) return
  busy.value = true
  msg.value = ''
  try {
    const { error } = await supabase.rpc('create_playoffs', { p_tournament_id: id })
    if (error) throw error
    msg.value = '✅ 淘汰赛对阵已生成'
    msgType.value = 'success'
    await load()
  } catch (e) {
    msg.value = '❌ ' + (e.message || '生成失败')
    msgType.value = 'error'
  } finally {
    busy.value = false
  }
}

async function saveSchedule(m) {
  busy.value = true
  try {
    const { error } = await supabase.rpc('update_match_schedule', {
      p_match_id: m.id,
      p_scheduled_at: m._local ? new Date(m._local).toISOString() : null,
      p_venue: m._venue || null
    })
    if (error) throw error
    m.scheduled_at = m._local ? new Date(m._local).toISOString() : null
    m.venue = m._venue || null
    m._dirty = false
    msg.value = '✅ 赛程时间已保存'
    msgType.value = 'success'
  } catch (e) {
    msg.value = '❌ ' + (e.message || '保存失败')
    msgType.value = 'error'
  } finally {
    busy.value = false
  }
}

async function createGame(m) {
  busy.value = true
  msg.value = ''
  try {
    const { data, error } = await supabase.rpc('create_match_game', { p_match_id: m.id })
    if (error) throw error
    router.push(`/games/${data.game_id}?from=/tournaments/${id}`)
  } catch (e) {
    msg.value = '❌ ' + (e.message || '创建失败')
    msgType.value = 'error'
    busy.value = false
  }
}

// 一键为本锦标赛全部未创建的小组赛创建比赛
async function createAllGroupGames() {
  const list = uncreatedGroupMatches.value
  if (!confirm(`将批量创建 ${list.length} 场${t.value.group_count === 1 ? '循环赛' : '小组赛'}比赛，创建后可在比赛页设置时间并开始记分。确认？`)) return
  busy.value = true
  msg.value = ''
  let ok = 0, fail = 0
  try {
    for (const m of list) {
      const { error } = await supabase.rpc('create_match_game', { p_match_id: m.id })
      if (error) { fail++; console.warn('[TournamentDetail] 创建失败:', m.id, error.message) }
      else ok++
    }
    if (ok) {
      msg.value = `✅ 已创建 ${ok} 场比赛${fail ? `，${fail} 场失败` : ''}，点击对阵表中的球队卡片即可进入比赛`
      msgType.value = 'success'
    } else {
      msg.value = '❌ 创建失败，请稍后重试'
      msgType.value = 'error'
    }
    await load()
  } finally {
    busy.value = false
  }
}

async function removeTournament() {
  if (!confirm('确认删除该锦标赛？分组和赛程将一并删除（已创建的比赛不受影响）。')) return
  if (!confirm('再次确认：删除后无法恢复。')) return
  busy.value = true
  try {
    const { error } = await supabase.rpc('delete_tournament', {
      p_tournament_id: id,
      p_user_id: auth.user?.id || null
    })
    if (error) throw error
    router.push('/tournaments')
  } catch (e) {
    msg.value = '❌ ' + (e.message || '删除失败')
    msgType.value = 'error'
    busy.value = false
  }
}

onMounted(() => {
  load()
  loadMyTeams()
  subscribeAnnouncements()
})

onUnmounted(() => {
  if (annChannel) {
    supabase.removeChannel(annChannel)
    annChannel = null
  }
})
</script>

<style scoped>
/* ── 淘汰赛对阵图连接线（专业 Bracket）──
   每轮等高分区 flex-1 居中放置卡片：
   - 横线（左入/右出）：从卡片中心水平延伸
   - 竖线：配对第一区中心 → 第二区中心（等高区时 top:50% + height:100%） */
.bk-line {
  position: absolute;
  pointer-events: none;
  border-color: rgba(100, 116, 139, 0.35);
}
.bk-line-l {
  left: -16px;
  top: 50%;
  width: 16px;
  border-top: 2px solid;
}
.bk-line-r {
  right: -16px;
  top: 50%;
  width: 16px;
  border-top: 2px solid;
}
.bk-line-v {
  right: -16px;
  top: 50%;
  height: 100%;
  border-right: 2px solid;
}
</style>
