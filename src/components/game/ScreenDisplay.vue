<template>
  <Teleport to="body">
    <div ref="rootEl" class="sc-root" :style="bgVars">
      <!-- 背景：队色呼吸灯 + 球场线稿（仅比分页显示，数据页保持纯净不干扰） -->
      <div v-if="page === 'score'" class="sc-bg" aria-hidden="true">
        <div class="scbg-clash"></div>
        <div class="scbg-breathe scbg-breathe-home"></div>
        <div class="scbg-breathe scbg-breathe-away"></div>
        <svg class="scbg-court" viewBox="0 0 1920 1080" preserveAspectRatio="xMidYMid slice" fill="none">
          <rect x="60" y="60" width="1800" height="960" rx="24" />
          <line x1="960" y1="60" x2="960" y2="1020" />
          <rect x="60" y="390" width="380" height="300" />
          <circle class="accent" cx="440" cy="540" r="95" />
          <path d="M 60 140 L 280 140 A 400 400 0 0 1 280 940 L 60 940" />
          <rect x="1480" y="390" width="380" height="300" />
          <circle class="accent" cx="1480" cy="540" r="95" />
          <path d="M 1860 140 L 1640 140 A 400 400 0 0 0 1640 940 L 1860 940" />
        </svg>
        <div class="scbg-vignette"></div>
        <!-- 漂浮粒子：左半场主队色、右半场客队色，缓慢上升 -->
        <div class="sc-particles" aria-hidden="true">
          <i v-for="(p, i) in particles" :key="i" class="sc-pt"
            :style="{ left: p.left, '--dur': p.dur, '--delay': p.delay, '--sz': p.size, '--pc': p.home ? homeColor : awayColor }"></i>
        </div>
      </div>

      <!-- 得分/犯规瞬间：对应半场色光闪 -->
      <div v-if="announce?.side === 'home'" :key="'fh' + announce.key" class="sc-flash"
        :style="{ background: `radial-gradient(ellipse 55% 95% at 0% 50%, ${announce.kind === 'foul' ? foulColor : homeColor}4d 0%, transparent 72%)` }"></div>
      <div v-if="announce?.side === 'away'" :key="'fa' + announce.key" class="sc-flash"
        :style="{ background: `radial-gradient(ellipse 55% 95% at 100% 50%, ${announce.kind === 'foul' ? foulColor : awayColor}4d 0%, transparent 72%)` }"></div>

      <!-- 顶部：轮播页签（暂停时）+ 比赛状态 -->
      <header class="sc-header">
        <div class="sc-header-left">
          <template v-if="isBreak">
            <span v-for="p in pages" :key="p" class="sc-header-page" :class="page === p ? 'sc-header-page-active' : ''">
              {{ pageLabels[p] }}
            </span>
          </template>
        </div>
        <div class="sc-header-right">
          <span v-if="game?.venue" class="sc-venue">{{ game.venue }}</span>
          <span class="sc-status" :class="statusClass">{{ statusText }}</span>
        </div>
      </header>

      <!-- ══ 比分页（进行中常驻）══ -->
      <main v-if="page === 'score'" class="sc-main">
        <!-- 主队 -->
        <div class="sc-team">
          <div class="sc-team-name" :style="{ color: homeColor }">{{ homeName }}</div>
          <div class="sc-score" :style="{ color: homeColor, textShadow: `0 0 60px ${homeColor}55` }">
            <span :key="scoreFxKey('home')" class="sc-score-num" :class="{ 'sc-score-pop': scoreFx?.side === 'home' }">{{ game?.home_score ?? 0 }}</span>
          </div>
          <div class="sc-fouls">
            <span class="sc-fouls-label">全队犯规</span>
            <span class="sc-foul-boxes">
              <i v-for="n in 5" :key="n" class="sc-foul-box" :class="foulBoxClass(teamFouls.home, n)"></i>
            </span>
            <span v-if="teamFouls.home >= 5" class="sc-foul-penalty">加罚</span>
          </div>
          <div v-if="showTimeouts" class="sc-timeouts">
            <span class="sc-timeouts-label">剩余暂停</span>
            <span class="sc-timeouts-num" :class="homeTimeouts <= 0 ? 'sc-timeouts-empty' : ''">{{ homeTimeouts }}</span>
            <span class="sc-timeouts-max">/ {{ timeoutsMax }}</span>
          </div>
        </div>

        <!-- 中间：节/时钟/分差/球权 -->
        <div class="sc-center">
          <template v-if="isOfficial">
            <div v-if="isBreak" class="sc-break-badge">⏸ 暂停中</div>
            <template v-else>
              <div class="sc-quarter">{{ quarterLabel(game?.current_quarter || 1, game?.quarters) }}</div>
              <div class="sc-clock" :class="remainingSecs <= 60 ? 'sc-clock-danger' : ''">{{ fmtClock(remainingSecs) }}</div>
            </template>
          </template>
          <template v-else>
            <div v-if="isBreak" class="sc-break-badge">⏸ 暂停中</div>
            <div v-else class="sc-target">目标 {{ game?.target_score || 120 }} 分</div>
          </template>

          <!-- 下次球权指示：单个箭头指向获球权方 -->
          <div v-if="possessionSet" class="sc-possession">
            <svg class="sc-possession-arrow" :class="{ 'sc-arrow-flip': !possessionHome }" viewBox="0 0 24 24"
              fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"
              :style="{ color: possessionHome ? homeColor : awayColor }">
              <path d="M20 12H5" />
              <path d="M11 6l-6 6 6 6" />
            </svg>
            <span>下次球权</span>
          </div>
          <div v-else class="sc-possession sc-possession-unset">球权未设置</div>
        </div>

        <!-- 客队 -->
        <div class="sc-team">
          <div class="sc-team-name" :style="{ color: awayColor }">{{ awayName }}</div>
          <div class="sc-score" :style="{ color: awayColor, textShadow: `0 0 60px ${awayColor}55` }">
            <span :key="scoreFxKey('away')" class="sc-score-num" :class="{ 'sc-score-pop': scoreFx?.side === 'away' }">{{ game?.away_score ?? 0 }}</span>
          </div>
          <div class="sc-fouls">
            <span class="sc-fouls-label">全队犯规</span>
            <span class="sc-foul-boxes">
              <i v-for="n in 5" :key="n" class="sc-foul-box" :class="foulBoxClass(teamFouls.away, n)"></i>
            </span>
            <span v-if="teamFouls.away >= 5" class="sc-foul-penalty">加罚</span>
          </div>
          <div v-if="showTimeouts" class="sc-timeouts">
            <span class="sc-timeouts-label">剩余暂停</span>
            <span class="sc-timeouts-num" :class="awayTimeouts <= 0 ? 'sc-timeouts-empty' : ''">{{ awayTimeouts }}</span>
            <span class="sc-timeouts-max">/ {{ timeoutsMax }}</span>
          </div>
        </div>
      </main>

      <!-- ══ 本节高效球员页（暂停/节间首屏，只播一次）══ -->
      <main v-else-if="page === 'hot'" :key="'hot' + hotAnim" class="sc-hot">
        <div class="sc-hot-head">
          <span class="sc-hot-title">🔥 本节高效球员</span>
          <span class="sc-hot-sub">{{ quarterLabel(hotData.quarter || 1, game?.quarters) }} · 效率评分</span>
        </div>
        <div class="sc-hot-cols">
          <section v-for="(col, ci) in hotCols" :key="col.key" class="sc-hot-col" :style="{ '--ci': ci }">
            <header class="sc-hot-col-head">
              <span class="sc-hot-team" :style="{ color: col.color }">{{ col.name }}</span>
              <span class="sc-hot-role">{{ col.key === 'home' ? '主队' : '客队' }}</span>
            </header>
            <div class="sc-hot-list">
              <div v-for="(p, i) in col.list" :key="p.player_id" class="sc-hot-item"
                :class="i === 0 ? 'sc-hot-item-top' : ''" :style="{ '--i': i, '--tc': col.color }">
                <span class="sc-hot-rank" :class="i === 0 ? 'sc-hot-rank-top' : ''">
                  <span v-if="i === 0">👑</span><span v-else>{{ i + 1 }}</span>
                </span>
                <span class="sc-avatar sc-hot-avatar" :style="{ '--tc': col.color }">
                  <img v-if="hAvatar(p.player_id)" :src="hAvatar(p.player_id)" alt="" />
                  <span v-else class="sc-avatar-fb">{{ hJersey(p.player_id) ?? (hName(p.player_id)?.[0] || '球') }}</span>
                </span>
                <span class="sc-hot-info">
                  <span class="sc-hot-name"><span v-if="hJersey(p.player_id) != null" class="sc-hot-jersey">#{{ hJersey(p.player_id) }}</span>{{ hName(p.player_id) }}</span>
                  <span class="sc-hot-line">得分 {{ p.pts }} · 篮板 {{ p.reb }} · 助攻 {{ p.ast }}</span>
                </span>
                <span class="sc-hot-eff">
                  <b>{{ p.eff }}</b>
                  <em>效率</em>
                </span>
              </div>
              <p v-if="!col.list.length" class="sc-hot-empty">本节暂无数据</p>
            </div>
          </section>
        </div>
      </main>

      <!-- ══ 本场 MVP + 评分页（比赛结束后，与详情页同源算法）══ -->
      <main v-else-if="page === 'mvp'" :key="'mvp' + mvpAnim" class="sc-mvp">
        <!-- MVP 英雄区 -->
        <div v-if="mvpWinner" class="sc-mvp-hero">
          <span class="sc-mvp-glow" aria-hidden="true"></span>
          <span class="sc-mvp-trophy">🏆</span>
          <div class="sc-mvp-hero-main">
            <span class="sc-mvp-label">本场 MVP</span>
            <span class="sc-mvp-name">
              <span v-if="mvpWinner.jersey_no != null" class="sc-mvp-jersey">#{{ mvpWinner.jersey_no }}</span>{{ mvpName }}
            </span>
            <span class="sc-mvp-team" :style="{ color: mvpColor }">{{ mvpTeamName }}</span>
          </div>
          <div class="sc-mvp-score">
            <b>{{ mvpWinner.mvp_score }}</b>
            <em>综合评分</em>
          </div>
          <div class="sc-mvp-stats">
            <span><b>{{ mvpWinner.pts || 0 }}</b>分</span>
            <span><b>{{ mvpWinner.reb || 0 }}</b>板</span>
            <span><b>{{ mvpWinner.ast || 0 }}</b>助</span>
            <span v-if="mvpWinner.stl"><b>{{ mvpWinner.stl }}</b>断</span>
            <span v-if="mvpWinner.blk"><b>{{ mvpWinner.blk }}</b>帽</span>
          </div>
        </div>
        <div v-else class="sc-mvp-nomvp">本场平局 · 暂无 MVP</div>

        <!-- 两队评分榜（与详情页评分口径一致）-->
        <div class="sc-mvp-cols">
          <section v-for="(col, ci) in ratingCols" :key="col.key" class="sc-mvp-col" :style="{ '--ci': ci }">
            <header class="sc-mvp-col-head">
              <span class="sc-mvp-col-name" :style="{ color: col.color }">{{ col.name }}</span>
              <span class="sc-mvp-col-tag">{{ col.key === 'home' ? '主队' : '客队' }} · 评分</span>
            </header>
            <div class="sc-mvp-list">
              <div v-for="(p, i) in col.list" :key="p.player_id" class="sc-mvp-row"
                :class="isMvpPlayer(p) ? 'sc-mvp-row-mvp' : ''" :style="{ '--i': i, '--tc': col.color }">
                <span class="sc-mvp-rank">{{ i + 1 }}</span>
                <span class="sc-avatar sc-mvp-avatar">
                  <img v-if="hAvatar(p.player_id)" :src="hAvatar(p.player_id)" alt="" />
                  <span v-else class="sc-avatar-fb">{{ hJersey(p.player_id) ?? (hName(p.player_id)?.[0] || '球') }}</span>
                </span>
                <span class="sc-mvp-pname">
                  <span v-if="hJersey(p.player_id) != null" class="sc-mvp-pjersey">#{{ hJersey(p.player_id) }}</span>{{ hName(p.player_id) }}
                  <span v-if="isMvpPlayer(p)" class="sc-mvp-crown">👑</span>
                </span>
                <span class="sc-rating-badge" :style="{ '--rc': p.r.tier.color, '--rs': p.r.tier.shadow, '--rt': p.r.tier.textColor }">
                  <span class="sc-rating-grade">{{ p.r.tier.grade }}</span>
                  <span class="sc-rating-score">{{ p.r.score.toFixed(1) }}</span>
                </span>
              </div>
              <p v-if="!col.list.length" class="sc-mvp-empty">暂无评分</p>
            </div>
          </section>
        </div>
      </main>

      <!-- ══ 球员数据页（暂停/节间/结束轮播，顶部带比分条）══ -->
      <main v-else class="sc-stats">
        <!-- 顶部比分条：两队比分 + 节次/时钟 -->
        <div class="sc-strip">
          <div class="sc-strip-side">
            <span class="sc-strip-name" :style="{ color: homeColor }">{{ homeName }}</span>
            <span class="sc-strip-score" :style="{ color: homeColor }">
              <span :key="scoreFxKey('home')" class="sc-score-num" :class="{ 'sc-score-pop': scoreFx?.side === 'home' }">{{ game?.home_score ?? 0 }}</span>
            </span>
          </div>
          <div class="sc-strip-center">
            <template v-if="game?.status === 'finished'">
              <span class="sc-strip-status">已结束</span>
            </template>
            <template v-else-if="isOfficial">
              <span class="sc-strip-quarter">{{ quarterLabel(game?.current_quarter || 1, game?.quarters) }}</span>
              <span v-if="isBreak" class="sc-strip-badge">暂停</span>
              <span v-else class="sc-strip-clock" :class="remainingSecs <= 60 ? 'sc-strip-clock-danger' : ''">{{ fmtClock(remainingSecs) }}</span>
            </template>
            <template v-else>
              <span v-if="isBreak" class="sc-strip-badge">暂停中</span>
              <span v-else class="sc-strip-status">目标 {{ game?.target_score || 120 }} 分</span>
            </template>
          </div>
          <div class="sc-strip-side sc-strip-right">
            <span class="sc-strip-score" :style="{ color: awayColor }">
              <span :key="scoreFxKey('away')" class="sc-score-num" :class="{ 'sc-score-pop': scoreFx?.side === 'away' }">{{ game?.away_score ?? 0 }}</span>
            </span>
            <span class="sc-strip-name" :style="{ color: awayColor }">{{ awayName }}</span>
          </div>
        </div>

        <!-- 队伍条 -->
        <div class="sc-teambar">
          <span class="sc-teambar-accent" :style="{ background: pageColor }"></span>
          <span class="sc-teambar-name" :style="{ color: pageColor }">{{ page === 'home' ? homeName : awayName }}</span>
          <span class="sc-teambar-tag">{{ page === 'home' ? '主队' : '客队' }} · 球员数据</span>
          <div class="sc-teambar-fouls">
            <span>全队犯规</span>
            <span class="sc-foul-boxes sc-foul-boxes-sm">
              <i v-for="n in 5" :key="n" class="sc-foul-box"
                :class="foulBoxClass(page === 'home' ? teamFouls.home : teamFouls.away, n)"></i>
            </span>
            <span v-if="(page === 'home' ? teamFouls.home : teamFouls.away) >= 5" class="sc-foul-penalty">加罚</span>
            <span v-if="showTimeouts" class="sc-teambar-to">
              剩余暂停 <b>{{ page === 'home' ? homeTimeouts : awayTimeouts }}</b>
            </span>
          </div>
        </div>

        <!-- 数据表（按可用高度铺满，超出屏幕时循环滚动） -->
        <div ref="tableWrap" class="sc-table-wrap"
          :style="{ '--row-h': rowH + 'px', fontSize: tableFont ? tableFont + 'px' : '' }">
          <table class="sc-table">
            <thead>
              <tr>
                <th class="sc-col-no">#</th>
                <th class="sc-col-name">球员</th>
                <th>得分</th>
                <th>篮板</th>
                <th>助攻</th>
                <th>抢断</th>
                <th>盖帽</th>
                <th>犯规</th>
                <th>失误</th>
                <th v-if="isFinished" class="sc-col-rating">评分</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in displayStats" :key="p.player_id"
                :class="isTopScorer(p) ? 'sc-row-top' : ''">
                <td class="sc-col-no">{{ jerseyOf(p) ?? '-' }}</td>
                <td class="sc-col-name">
                  <div class="sc-player">
                    <span class="sc-avatar">
                      <img v-if="avatarOf(p)" :src="avatarOf(p)" alt="" />
                      <span v-else class="sc-avatar-fb">{{ jerseyOf(p) ?? (nameOf(p)?.[0] || '球') }}</span>
                    </span>
                    <span v-if="showOnCourt && isOnCourt(p.player_id)" class="sc-oncourt"></span>
                    <span class="sc-pname">{{ nameOf(p) }}</span>
                  </div>
                </td>
                <td class="sc-cell-pts">{{ p.pts || 0 }}</td>
                <td>{{ p.reb || 0 }}</td>
                <td>{{ p.ast || 0 }}</td>
                <td>{{ p.stl || 0 }}</td>
                <td>{{ p.blk || 0 }}</td>
                <td :class="(p.pf || 0) >= 5 ? 'sc-cell-danger' : ''">{{ p.pf || 0 }}</td>
                <td>{{ p.tov || 0 }}</td>
                <td v-if="isFinished" class="sc-cell-rating">
                  <span v-if="ratingOf(p.player_id)" class="sc-rating-badge"
                    :style="{ '--rc': ratingOf(p.player_id).tier.color, '--rs': ratingOf(p.player_id).tier.shadow, '--rt': ratingOf(p.player_id).tier.textColor }">
                    <span class="sc-rating-grade">{{ ratingOf(p.player_id).tier.grade }}</span>
                    <span class="sc-rating-score">{{ ratingOf(p.player_id).score.toFixed(1) }}</span>
                  </span>
                  <span v-else class="sc-rating-na">-</span>
                </td>
              </tr>
              <tr v-if="displayStats.length === 0">
                <td :colspan="isFinished ? 10 : 9" class="sc-empty">暂无数据</td>
              </tr>
            </tbody>
          </table>
        </div>
      </main>

      <!-- 得分/犯规播报：球员头像 + 姓名 + 特效 -->
      <Transition name="sc-ann">
        <div v-if="announceShow && announce" :key="announce.key" class="sc-announce"
          :class="announce.kind === 'foul' ? 'sc-announce-foul' : ''" :style="annVars">
          <!-- 粒子迸发 -->
          <span class="sc-burst" aria-hidden="true">
            <i v-for="(b, i) in burstParts" :key="i" class="sc-burst-dot"
              :style="{ '--bx': b.x, '--by': b.y, '--bd': b.d }"></i>
          </span>
          <span class="sc-ann-avatar">
            <img v-if="announce.avatar" :src="announce.avatar" alt="" />
            <span v-else class="sc-ann-avatar-fb">{{ announce.jersey != null ? announce.jersey : (announce.name?.[0] || '球') }}</span>
          </span>
          <span class="sc-ann-mid">
            <span class="sc-ann-name">
              <span v-if="announce.jersey != null" class="sc-ann-jersey">#{{ announce.jersey }}</span>{{ announce.name }}
            </span>
            <span class="sc-ann-team">{{ announce.teamName }}</span>
          </span>
          <span class="sc-ann-pts">
            <template v-if="announce.kind === 'foul'">
              <span class="sc-ann-foul-txt">犯规</span>
              <span class="sc-ann-pts-label">个人犯规 {{ foulCountOf(announce.playerId) }} 次</span>
            </template>
            <template v-else>
              <span class="sc-ann-pts-num">+{{ announce.pts }}</span>
              <span class="sc-ann-pts-label">{{ announce.label }}</span>
            </template>
          </span>
        </div>
      </Transition>

      <!-- 退出按钮（鼠标移动时显示） -->
      <button class="sc-exit" :class="controlsVisible ? 'sc-exit-visible' : ''" @click="exit" title="退出大屏模式">✕</button>
      <div v-if="showHint" class="sc-exit-hint">ESC 退出全屏 · 再按 ESC 或点右上角 ✕ 退出大屏</div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { supabase } from '@/utils/supabase'
import { fmtClock, quarterLabel, periodSeconds } from '@/utils/helpers'
import { timeoutsRemaining, timeoutMax as timeoutMaxOf } from '@/composables/useTimeouts'
import { weightedEfficiency, calcRawPlayerScore, calcShootingBonus, calcPlayerScore, calcMvpRating } from '@/utils/efficiency'

// 大屏展示组件：比分 + 全队犯规 + 下次球权 + 球员得分播报
// 暂停/节间休息/已结束时自动轮播：主队数据 → 客队数据（比分显示在数据页顶部）
const props = defineProps({
  game: { type: Object, required: true },
  stats: { type: Array, default: () => [] },
  teamFouls: { type: Object, default: () => ({ home: 0, away: 0 }) },
  courtLineup: { type: Array, default: () => [] }
})
const emit = defineEmits(['close'])

const ROTATE_MS = 10000
// 轮播页签：结束态用「MVP / 主队 / 客队」，其余用「本节高效 / 主队 / 客队」
const pages = computed(() => props.game?.status === 'finished' ? ['mvp', 'home', 'away'] : ['hot', 'home', 'away'])
const pageLabels = { hot: '本节高效', mvp: 'MVP', home: '主队数据', away: '客队数据' }
const ANN_LABELS = { pts_1: '罚球命中', pts_2: '两分命中', pts_3: '三分命中' }
const ANN_PTS = { pts_1: 1, pts_2: 2, pts_3: 3 }
const foulColor = '#f59e0b'

const rootEl = ref(null)
const page = ref('score')
const controlsVisible = ref(false)
const showHint = ref(true)
const nowTs = ref(Date.now())
let rotateTimer = null
let ticker = null
let hideControlsTimer = null

const homeColor = computed(() => props.game?.home_team?.color || '#3b82f6')
const awayColor = computed(() => props.game?.away_team?.color || '#f97316')
// 背景呼吸灯配色（队色：静态底 + 呼吸强光），仅比分页使用
const bgVars = computed(() => {
  const h = homeColor.value, a = awayColor.value
  return {
    '--ch': h + '2b', '--chp': h + '52',
    '--ca': a + '2b', '--cap': a + '52'
  }
})
// 比分页漂浮粒子：位置/时长按索引确定性生成，避免重渲染时跳动
const particles = computed(() => Array.from({ length: 26 }, (_, i) => {
  const r1 = ((i * 9301 + 49297) % 233280) / 233280
  const r2 = ((i * 4523 + 12345) % 20000) / 20000
  const r3 = ((i * 7919 + 104729) % 15000) / 15000
  return {
    left: `${(r1 * 100).toFixed(1)}%`,
    delay: `${(r2 * 9).toFixed(2)}s`,
    dur: `${(7 + r3 * 7).toFixed(2)}s`,
    size: `${(2 + r1 * 3.5).toFixed(1)}px`,
    home: i % 2 === 0
  }
}))
const homeName = computed(() => props.game?.home_team?.name || '主队')
const awayName = computed(() => props.game?.away_team?.name || '客队')
const isOfficial = computed(() => props.game?.game_type === 'official')

// ── 暂停次数（FIBA：上半场 2 次 / 下半场 3 次）──
const showTimeouts = computed(() => isOfficial.value)
const homeTimeouts = computed(() => timeoutsRemaining(props.game, 'home'))
const awayTimeouts = computed(() => timeoutsRemaining(props.game, 'away'))
const timeoutsMax = computed(() => timeoutMaxOf(props.game?.current_quarter, props.game?.quarters))

// 全队犯规格子：单节 5 格，满 5 次进入加罚状态
function foulBoxClass(count, n) {
  if (n > (count || 0)) return ''
  return (count || 0) >= 5 ? 'sc-foul-box-danger' : 'sc-foul-box-on'
}

const isBreak = computed(() =>
  (props.game?.status === 'active' && !!props.game?.is_paused) ||
  props.game?.status === 'halftime' ||
  props.game?.status === 'finished'
)

// 节间休息 / 中场 / 结束：数据页不显示上场球员呼吸灯，保持全员状态一致
// 判定依据：节切换会把 quarter_clock 重置为满节时长，普通暂停只冻结当前剩余秒数
const isQuarterBreak = computed(() => {
  const g = props.game
  if (!g) return false
  if (g.status === 'halftime' || g.status === 'finished') return true
  if (g.status === 'active' && g.is_paused && isOfficial.value) {
    const full = periodSeconds(g)
    return (g.quarter_clock ?? 0) >= full - 1
  }
  return false
})
const showOnCourt = computed(() => !isQuarterBreak.value)

const statusText = computed(() => {
  const g = props.game
  if (!g) return ''
  if (g.status === 'finished') return '已结束'
  if (g.status === 'halftime') return '中场休息'
  if (g.status === 'active') return g.is_paused ? '暂停中' : 'LIVE'
  if (g.status === 'cancelled') return '已取消'
  return '未开始'
})
const statusClass = computed(() => {
  const g = props.game
  if (g?.status === 'active') return g.is_paused ? 'sc-status-paused' : 'sc-status-live'
  if (g?.status === 'finished') return 'sc-status-done'
  return 'sc-status-idle'
})

// 正式制倒计时（与录入页同规则：暂停期间不走秒）
const clockRunning = computed(() => isOfficial.value && props.game?.status === 'active' && !props.game?.is_paused)
const remainingSecs = computed(() => {
  const g = props.game
  if (!g || !isOfficial.value) return 0
  const base = g.quarter_clock ?? 0
  if (!clockRunning.value) return base
  if (!g.clock_updated_at) return base
  const anchor = new Date(g.clock_updated_at).getTime()
  if (!anchor || Number.isNaN(anchor)) return base
  const elapsed = Math.max(0, Math.floor((nowTs.value - anchor) / 1000))
  return Math.max(0, base - elapsed)
})

// 球权
const possessionSet = computed(() => props.game?.possession_home != null)
const possessionHome = computed(() => props.game?.possession_home === true)

// ── 比分数字弹跳（仅弹跳，无飘字）──
const scoreFx = ref(null) // { side: 'home'|'away', pts, key }
let scoreFxTimer = null
watch(() => [props.game?.home_score, props.game?.away_score], ([nh, na], [oh, oa]) => {
  const dh = (nh ?? 0) - (oh ?? 0)
  const da = (na ?? 0) - (oa ?? 0)
  let side = null, pts = 0
  if (dh > 0 && dh <= 3 && da === 0) { side = 'home'; pts = dh }
  else if (da > 0 && da <= 3 && dh === 0) { side = 'away'; pts = da }
  if (!side) return
  scoreFx.value = { side, pts, key: Date.now() }
  clearTimeout(scoreFxTimer)
  scoreFxTimer = setTimeout(() => { scoreFx.value = null }, 1200)
})
function scoreFxKey(side) {
  return scoreFx.value?.side === side ? `fx-${scoreFx.value.key}` : 'idle'
}

// ── 球员得分播报（订阅 action_logs 实时事件）──
const announce = ref(null)
const announceShow = ref(false)
let annHideT = null
let annClearT = null
let annChannel = null

const annVars = computed(() => {
  const c = announce.value?.kind === 'foul' ? foulColor
    : announce.value?.side === 'home' ? homeColor.value
    : announce.value?.side === 'away' ? awayColor.value : '#3b82f6'
  return { '--ac': c, '--ac-glow': c + '66', '--ac-dim': c + '2e' }
})

// 播报时从横幅中心迸发的粒子
const burstParts = ref([])
function makeBurst() {
  return Array.from({ length: 18 }, (_, i) => {
    const ang = (i / 18) * Math.PI * 2 + Math.random() * 0.35
    const dist = 70 + Math.random() * 120
    return {
      x: `${(Math.cos(ang) * dist).toFixed(0)}px`,
      y: `${(Math.sin(ang) * dist).toFixed(0)}px`,
      d: `${(Math.random() * 0.28).toFixed(2)}s`
    }
  })
}

function showAnnounce(data) {
  announce.value = data
  announceShow.value = true
  burstParts.value = makeBurst()
  clearTimeout(annHideT)
  clearTimeout(annClearT)
  annHideT = setTimeout(() => { announceShow.value = false }, 3400)
  annClearT = setTimeout(() => { announce.value = null }, 3900)
}

function subscribeAnnounce() {
  unsubscribeAnnounce()
  const gid = props.game?.id
  if (!gid) return
  annChannel = supabase
    .channel(`screen-ann:${gid}`)
    .on('postgres_changes', {
      event: 'INSERT', schema: 'public', table: 'action_logs', filter: `game_id=eq.${gid}`
    }, (payload) => {
      const row = payload.new
      if (!row || (row.delta ?? 1) < 0) return
      const side = row.team_id === props.game?.home_team_id ? 'home'
        : (row.team_id === props.game?.away_team_id ? 'away' : null)
      const st = props.stats.find(s => s.player_id === row.player_id)
      const base = {
        key: row.id || `k${Date.now()}`,
        side,
        name: st?.player_name || st?.player?.name || '球员',
        jersey: st?.jersey_no ?? st?.player?.jersey_no ?? null,
        avatar: st?.player_avatar_url || st?.player?.avatar_url || null,
        teamName: side === 'home' ? homeName.value : side === 'away' ? awayName.value : (st?.team_name || '')
      }
      // 犯规同样播报（个人犯规），与得分播报区分样式
      if (row.action_type === 'pf') {
        showAnnounce({ ...base, kind: 'foul', pts: 0, label: '犯规', playerId: row.player_id })
        return
      }
      const pts = ANN_PTS[row.action_type]
      if (!pts) return
      showAnnounce({ ...base, kind: 'score', pts, label: ANN_LABELS[row.action_type] || '得分' })
    })
    .subscribe()
}

function unsubscribeAnnounce() {
  if (annChannel) { supabase.removeChannel(annChannel); annChannel = null }
}

watch(() => props.game?.id, () => subscribeAnnounce(), { immediate: true })

// ── 数据页 ──
const pageColor = computed(() => page.value === 'home' ? homeColor.value : awayColor.value)
const displayStats = computed(() => {
  if (page.value !== 'home' && page.value !== 'away') return []
  if (!props.game) return []
  const teamId = page.value === 'home' ? props.game.home_team_id : props.game.away_team_id
  // 普通暂停时把在场球员排到最前（节间休息不调整，保持全员一致）
  const onCourtFirst = isBreak.value && !isQuarterBreak.value
  return props.stats
    .filter(s => s.team_id === teamId)
    .slice()
    .sort((a, b) => {
      if (onCourtFirst) {
        const ca = isOnCourt(a.player_id) ? 0 : 1
        const cb = isOnCourt(b.player_id) ? 0 : 1
        if (ca !== cb) return ca - cb
      }
      return (b.pts || 0) - (a.pts || 0) || (b.reb || 0) - (a.reb || 0) || String(a.jersey_no ?? '999').localeCompare(String(b.jersey_no ?? '999'))
    })
})

const nameOf = (p) => p.player_name || p.player?.name || '未知'
const jerseyOf = (p) => p.jersey_no ?? p.player?.jersey_no ?? null
const avatarOf = (p) => p.player_avatar_url || p.player?.avatar_url || null
const isTopScorer = (p) => displayStats.value[0]?.player_id === p.player_id && (p.pts || 0) > 0

function isOnCourt(playerId) {
  return props.courtLineup.some(l => l.player_id === playerId)
}

// 犯规播报显示该球员累计犯规次数（实时取自 stats，随增量更新自动修正）
function foulCountOf(playerId) {
  if (!playerId) return 1
  const s = props.stats.find(x => x.player_id === playerId)
  return Math.max(s?.pf ?? 0, 1)
}

// ── 本节高效球员（普通暂停 / 节间休息时播放，只播一次）──
const hotData = ref({ quarter: 0, home: [], away: [] })
const EFF_MAX = 3
const hotAnim = ref(0)   // 每次进入高效页自增，用于重放入场动画
let hotToken = 0

// 高效榜球员信息实时取自 stats（避免查询时 stats 尚未加载导致姓名/头像为空）
const statOf = (pid) => props.stats.find(x => x.player_id === pid)
const hName = (pid) => { const s = statOf(pid); return s?.player_name || s?.player?.name || '球员' }
const hJersey = (pid) => { const s = statOf(pid); return s?.jersey_no ?? s?.player?.jersey_no ?? null }
const hAvatar = (pid) => { const s = statOf(pid); return s?.player_avatar_url || s?.player?.avatar_url || null }

async function loadHot() {
  const gid = props.game?.id
  if (!gid) return
  const token = ++hotToken
  const { data, error } = await supabase
    .from('action_logs')
    .select('player_id, team_id, action_type, delta, quarter')
    .eq('game_id', gid)
    .eq('is_voided', false)
  if (error || !data || token !== hotToken) return
  // 取有数据的最新一节（避免节切换后 current_quarter 已递增导致取错节）
  // 若整场都没有节次（娱乐制），则统计全场
  let latest = 0
  let hasQuarter = false
  for (const r of data) {
    const q = r.quarter || 0
    if (q > 0) hasQuarter = true
    if (q > latest) latest = q
  }
  const q = latest || (props.game?.current_quarter || 1)
  const agg = {}
  for (const r of data) {
    if (hasQuarter && (r.quarter || 0) !== q) continue
    const d = r.delta ?? 1
    if (!d) continue
    const a = agg[r.player_id] || (agg[r.player_id] = {
      player_id: r.player_id, team_id: r.team_id,
      pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
      fg2a: 0, fg2m: 0, fg3a: 0, fg3m: 0, fta: 0, ftm: 0
    })
    // 统计口径与教练面板一致（pts_3 同时计入 fg2a/fg3a）
    switch (r.action_type) {
      case 'pts_1': a.pts += d; a.ftm += d; a.fta += d; break
      case 'pts_2': a.pts += 2 * d; a.fg2m += d; a.fg2a += d; break
      case 'pts_3': a.pts += 3 * d; a.fg2m += d; a.fg2a += d; a.fg3m += d; a.fg3a += d; break
      case 'reb': a.reb += d; break
      case 'ast': a.ast += d; break
      case 'stl': a.stl += d; break
      case 'blk': a.blk += d; break
      case 'tov': a.tov += d; break
      case 'pf': a.pf += d; break
      case 'fga_miss': a.fg2a += d; break
      case 'fg3a_miss': a.fg3a += d; break
      case 'fta_miss': a.fta += d; break
    }
  }
  // 效率评分采用教练面板的位置加权算法（见 @/utils/efficiency）
  const rank = (tid) => Object.values(agg)
    .filter(a => a.team_id === tid)
    .map(a => ({ ...a, eff: weightedEfficiency(a, statOf(a.player_id)?.player_position) }))
    .filter(a => a.eff > 0)
    .sort((x, y) => y.eff - x.eff || y.pts - x.pts || y.reb - x.reb)
    .slice(0, EFF_MAX)
  hotData.value = {
    quarter: q,
    home: rank(props.game?.home_team_id),
    away: rank(props.game?.away_team_id)
  }
}

watch(isBreak, (v) => { if (v) loadHot() }, { immediate: true })
watch(() => props.game?.id, () => { if (isBreak.value) loadHot() })

const hotCols = computed(() => [
  { key: 'home', name: homeName.value, color: homeColor.value, list: hotData.value.home },
  { key: 'away', name: awayName.value, color: awayColor.value, list: hotData.value.away }
])

// ── 结束态：评分与 MVP（与赛事详情页同源算法，见 @/utils/efficiency）──
const mvpAnim = ref(0)   // 每次进入 MVP 页自增，重放入场动画
const isFinished = computed(() => props.game?.status === 'finished')

// 球员评分表（0~16，SS~D 等级）——仅比赛结束后计算
const ratingMap = computed(() => {
  if (!isFinished.value) return {}
  const m = {}
  for (const s of props.stats) {
    const raw = calcRawPlayerScore(s, s.player_position || 'FLEX') + calcShootingBonus(s)
    m[s.player_id] = calcPlayerScore(raw, props.game?.game_type || 'entertainment')
  }
  return m
})
function ratingOf(playerId) {
  return ratingMap.value[playerId] || null
}

// 本场 MVP：胜方中 MVP 评分最高者；平局无 MVP
const mvpWinner = computed(() => {
  if (!isFinished.value || !props.stats.length) return null
  const g = props.game
  const hs = g?.home_score || 0, as = g?.away_score || 0
  let winId = null
  if (hs > as) winId = g.home_team_id
  else if (as > hs) winId = g.away_team_id
  else return null
  let best = null, bestScore = -Infinity
  for (const s of props.stats.filter(x => x.team_id === winId)) {
    const sc = calcMvpRating(s, s.player_position || 'FLEX')
    if (sc > bestScore) { bestScore = sc; best = { ...s, mvp_score: sc } }
  }
  return best
})
const mvpIsHome = computed(() => mvpWinner.value?.team_id === props.game?.home_team_id)
const mvpColor = computed(() => mvpIsHome.value ? homeColor.value : awayColor.value)
const mvpTeamName = computed(() => mvpIsHome.value ? homeName.value : awayName.value)
const mvpName = computed(() => {
  const m = mvpWinner.value
  if (!m) return ''
  return m.player_name || statOf(m.player_id)?.player_name || '球员'
})
const isMvpPlayer = (p) => !!mvpWinner.value && p.player_id === mvpWinner.value.player_id

// 两队评分榜（按评分降序），供结束态 MVP 页展示
const ratingCols = computed(() => {
  const mk = (tid) => props.stats
    .filter(s => s.team_id === tid)
    .map(s => ({ ...s, r: ratingOf(s.player_id) }))
    .filter(s => s.r)
    .sort((a, b) => b.r.score - a.r.score)
  return [
    { key: 'home', name: homeName.value, color: homeColor.value, list: mk(props.game?.home_team_id) },
    { key: 'away', name: awayName.value, color: awayColor.value, list: mk(props.game?.away_team_id) }
  ]
})

// ── 数据表：按可用高度动态铺满（8 人满屏），超出则循环滚动 ──
const tableWrap = ref(null)
const rowH = ref(0)        // 每行高度（px），由可用高度 / 显示行数算出
const tableFont = ref(0)   // 随行高联动的字号
let scrollRaf = null
let scrollWait = 0
let tableRO = null

// 每屏最多铺满 8 行；不足 8 人时按实际人数铺满
const MAX_FILL_ROWS = 8
const ROW_MIN = 36
const ROW_MAX = 160

let measureKey = ''

function measureAndApply() {
  const el = tableWrap.value
  if (!el) return
  const n = displayStats.value.length
  if (!n) { rowH.value = 0; tableFont.value = 0; measureKey = ''; stopTableScroll(); return }
  const cs = getComputedStyle(el)
  const padY = parseFloat(cs.paddingTop || '0') + parseFloat(cs.paddingBottom || '0')
  const avail = el.clientHeight - padY
  if (avail <= 0) return
  // 仅在页面或人数变化时回到顶部，避免实时数据刷新打断滚动
  const key = `${page.value}:${n}`
  const resetScroll = key !== measureKey
  measureKey = key
  const shown = Math.min(n, MAX_FILL_ROWS)
  // 先按“表头约等于一行”估算，用于确定字号
  const est = Math.max(ROW_MIN, Math.min(ROW_MAX, avail / (shown + 1)))
  tableFont.value = Math.round(Math.max(14, Math.min(44, est * 0.42)))
  rowH.value = Math.round(est)
  // 字号应用后按真实表头高度精算行高，使整表正好铺满
  nextTick(() => {
    const e2 = tableWrap.value
    if (!e2) return
    const head = e2.querySelector('thead')?.offsetHeight || 0
    rowH.value = Math.round(Math.max(ROW_MIN, Math.min(ROW_MAX, (avail - head) / shown)))
    nextTick(() => {
      const e3 = tableWrap.value
      if (!e3) return
      if (resetScroll) { e3.scrollTop = 0; scrollWait = 0 }
      if (e3.scrollHeight - e3.clientHeight > 8) startTableScroll()
      else stopTableScroll()
    })
  })
}

function startTableScroll() {
  if (scrollRaf) return
  let last = performance.now()
  let dir = 1
  const step = (t) => {
    const el = tableWrap.value
    if (!el) { scrollRaf = null; return }
    const dt = Math.min(64, t - last)
    last = t
    if (scrollWait > 0) {
      scrollWait -= dt
    } else {
      el.scrollTop += dt * 0.06 * dir
      const maxTop = el.scrollHeight - el.clientHeight
      if (dir === 1 && el.scrollTop >= maxTop - 1) { scrollWait = 2600; dir = -1 }
      else if (dir === -1 && el.scrollTop <= 1) { scrollWait = 1400; dir = 1 }
    }
    scrollRaf = requestAnimationFrame(step)
  }
  scrollRaf = requestAnimationFrame(step)
}

function stopTableScroll() {
  if (scrollRaf) { cancelAnimationFrame(scrollRaf); scrollRaf = null }
}

// 表格容器尺寸变化（全屏切换/窗口缩放）时重新铺排
watch(tableWrap, (el) => {
  if (tableRO) { tableRO.disconnect(); tableRO = null }
  if (el && typeof ResizeObserver !== 'undefined') {
    tableRO = new ResizeObserver(() => measureAndApply())
    tableRO.observe(el)
  }
}, { flush: 'post' })
watch([page, displayStats], () => measureAndApply(), { flush: 'post' })

// ── 轮播控制：暂停/结束时自动轮播，恢复进行中则回到比分页 ──
// 同时监听 status：比赛从「暂停」直接变为「已结束」时也要重建队列，切换到 MVP 页
watch([isBreak, () => props.game?.status], ([v]) => {
  if (v) startRotation()
  else stopRotation()
}, { immediate: true })

// 轮播队列：
//   · 进行中暂停/节间：高效页只播一次，之后在主队/客队数据页间循环
//   · 比赛结束：MVP 页 + 主客队数据页循环（评分与 MVP 随轮播反复展示）
let rotationQueue = []
function startRotation() {
  stopRotation()
  if (isFinished.value) {
    rotationQueue = ['mvp', 'home', 'away']
    page.value = rotationQueue[0]
    mvpAnim.value++   // 触发 MVP 页入场动画重放
    rotateTimer = setInterval(() => {
      rotationQueue.shift()
      if (!rotationQueue.length) rotationQueue = ['mvp', 'home', 'away']
      page.value = rotationQueue[0]
    }, ROTATE_MS)
    return
  }
  rotationQueue = ['hot', 'home', 'away']
  page.value = rotationQueue[0]
  hotAnim.value++   // 触发高效页入场动画重放
  rotateTimer = setInterval(() => {
    rotationQueue.shift()
    if (!rotationQueue.length) rotationQueue = ['home', 'away']
    page.value = rotationQueue[0]
  }, ROTATE_MS)
}

function stopRotation() {
  if (rotateTimer) { clearInterval(rotateTimer); rotateTimer = null }
  rotationQueue = []
  page.value = 'score'
}

// ── 全屏与退出 ──
// ESC 行为：全屏中按 ESC 先退出全屏（浏览器原生处理），回到窗口模式后
// 再按 ESC（或点右上角 ✕）才退出大屏模式
function onKeydown(e) {
  if (e.key !== 'Escape') return
  if (document.fullscreenElement) return   // 交给浏览器退出全屏
  emit('close')
}
function onMouseMove() {
  controlsVisible.value = true
  clearTimeout(hideControlsTimer)
  hideControlsTimer = setTimeout(() => { controlsVisible.value = false }, 3000)
}
function exit() {
  if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {})
  emit('close')
}

onMounted(() => {
  ticker = setInterval(() => { nowTs.value = Date.now() }, 1000)
  window.addEventListener('keydown', onKeydown)
  window.addEventListener('mousemove', onMouseMove)
  setTimeout(() => { showHint.value = false }, 4000)
  rootEl.value?.requestFullscreen?.()
    .catch(() => { /* 浏览器拒绝全屏时仍以覆盖层铺满显示 */ })
})

onBeforeUnmount(() => {
  if (ticker) clearInterval(ticker)
  stopRotation()
  stopTableScroll()
  if (tableRO) { tableRO.disconnect(); tableRO = null }
  clearTimeout(hideControlsTimer)
  clearTimeout(scoreFxTimer)
  clearTimeout(annHideT)
  clearTimeout(annClearT)
  unsubscribeAnnounce()
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('mousemove', onMouseMove)
  if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {})
})
</script>

<style scoped>
.sc-root {
  position: fixed; inset: 0; z-index: 9999;
  background: #000; color: #fff;
  display: flex; flex-direction: column; overflow: hidden;
}

/* ── 背景：队色呼吸灯 + 球场线稿（仅比分页渲染） ── */
.sc-bg {
  position: absolute; inset: 0; z-index: 0;
  overflow: hidden; pointer-events: none;
}
/* 左右队色静态底场 */
.scbg-clash {
  position: absolute; inset: 0;
  background:
    radial-gradient(ellipse 52% 95% at -8% 50%, var(--ch, #3b82f62b) 0%, transparent 62%),
    radial-gradient(ellipse 52% 95% at 108% 50%, var(--ca, #f973162b) 0%, transparent 62%);
}
/* 强力呼吸灯：两队颜色大幅明暗脉动（缩放 + 透明度双重呼吸） */
.scbg-breathe {
  position: absolute; inset: 0;
  will-change: transform, opacity;
}
.scbg-breathe-home {
  background: radial-gradient(ellipse 50% 88% at -6% 50%, var(--chp, #3b82f652) 0%, transparent 66%);
  animation: scbg-breathe-h 2.8s ease-in-out infinite;
}
.scbg-breathe-away {
  background: radial-gradient(ellipse 50% 88% at 106% 50%, var(--cap, #f9731652) 0%, transparent 66%);
  animation: scbg-breathe-a 2.8s ease-in-out infinite;
}
@keyframes scbg-breathe-h {
  0%, 100% { opacity: 0.18; transform: scale(1); }
  50% { opacity: 1; transform: scale(1.08); }
}
@keyframes scbg-breathe-a {
  0%, 100% { opacity: 0.18; transform: scale(1); }
  50% { opacity: 1; transform: scale(1.08); }
}
.scbg-court {
  position: absolute; inset: 0; width: 100%; height: 100%;
  stroke: rgba(255, 255, 255, 0.09); stroke-width: 2;
}
.scbg-court .accent { stroke: rgba(249, 115, 22, 0.22); }
.scbg-vignette {
  position: absolute; inset: 0;
  background: radial-gradient(ellipse 92% 88% at 50% 45%, transparent 55%, rgba(0, 0, 0, 0.55) 100%);
}

/* ── 比分页漂浮粒子 ── */
.sc-particles { position: absolute; inset: 0; overflow: hidden; }
.sc-pt {
  position: absolute; bottom: -4vh;
  width: var(--sz); height: var(--sz); border-radius: 50%;
  background: var(--pc); box-shadow: 0 0 8px var(--pc);
  opacity: 0;
  animation: sc-pt-rise var(--dur) linear var(--delay) infinite;
}
@keyframes sc-pt-rise {
  0% { opacity: 0; transform: translateY(0) scale(0.6); }
  12% { opacity: 0.75; }
  75% { opacity: 0.5; }
  100% { opacity: 0; transform: translateY(-106vh) scale(1.15); }
}

/* ── 得分瞬间队色闪光 ── */
.sc-flash {
  position: absolute; inset: 0; z-index: 0; pointer-events: none;
  animation: sc-flash-fade 1.6s ease-out forwards;
}
@keyframes sc-flash-fade {
  0% { opacity: 0; } 12% { opacity: 1; } 100% { opacity: 0; }
}

/* ── 顶部 ── */
.sc-header {
  position: relative; z-index: 2;
  display: flex; align-items: center; justify-content: space-between;
  padding: 0.9vh 2vw; opacity: 0.85;
}
.sc-header-left { display: flex; align-items: center; gap: 0.8vw; min-height: 1em; }
.sc-header-page {
  font-size: clamp(12px, 1.2vw, 24px); color: #4b5563; font-weight: 600;
  padding: 0.2em 0.9em; border-radius: 999px; border: 1px solid #1f2937;
  white-space: nowrap;
}
.sc-header-page-active { color: #fff; border-color: #fff; background: rgba(255, 255, 255, 0.08); }
.sc-header-right { display: flex; align-items: center; gap: 1.2vw; }
.sc-venue { font-size: clamp(12px, 1.2vw, 22px); color: #888; }
.sc-status {
  font-size: clamp(12px, 1.3vw, 24px); font-weight: 800;
  padding: 0.3em 0.9em; border-radius: 999px; letter-spacing: 0.1em;
}
.sc-status-live { background: #dc2626; animation: sc-pulse 1.6s infinite; }
.sc-status-paused { background: #b45309; }
.sc-status-done { background: #1d4ed8; }
.sc-status-idle { background: #374151; }

/* ── 比分页 ── */
.sc-main {
  position: relative; z-index: 1;
  flex: 1; display: flex; align-items: center; justify-content: space-evenly;
  padding: 0 3vw 2vh;
}
.sc-team {
  position: relative; z-index: 1;
  flex: 1; display: flex; flex-direction: column; align-items: center;
  padding: 2vh 1vw; border-radius: 2vw;
}
.sc-team-name {
  font-size: clamp(20px, 3vw, 60px); font-weight: 800; letter-spacing: 0.05em;
  margin-bottom: 1.5vh;
}
.sc-score {
  font-size: clamp(72px, 14vw, 340px); font-weight: 900; line-height: 1;
  font-variant-numeric: tabular-nums;
}
.sc-fouls { margin-top: 2.5vh; display: flex; align-items: center; gap: 0.8vw; }
.sc-fouls-label { font-size: clamp(13px, 1.4vw, 26px); color: #9ca3af; }
/* 全队犯规格子：单节 5 格（FIBA），满 5 次变红并提示加罚 */
.sc-foul-boxes { display: inline-flex; align-items: center; gap: 0.5vw; }
.sc-foul-box {
  width: clamp(18px, 1.9vw, 40px); height: clamp(18px, 1.9vw, 40px);
  border-radius: 0.22em; display: inline-block;
  background: rgba(255, 255, 255, 0.05);
  border: 2px solid #374151;
  transition: background 0.25s, border-color 0.25s;
}
.sc-foul-box-on { background: #e5e7eb; border-color: #e5e7eb; box-shadow: 0 0 0.6em rgba(229, 231, 235, 0.45); }
.sc-foul-box-danger { background: #ef4444; border-color: #ef4444; box-shadow: 0 0 0.8em rgba(239, 68, 68, 0.7); animation: sc-pulse 1.2s infinite; }
.sc-foul-penalty {
  font-size: clamp(13px, 1.4vw, 28px); font-weight: 800; color: #ef4444;
  border: 1px solid #ef4444; border-radius: 999px; padding: 0.1em 0.7em; white-space: nowrap;
  animation: sc-pulse 1.2s infinite;
}
/* 剩余暂停数（FIBA 半场规则） */
.sc-timeouts { margin-top: 1.2vh; display: flex; align-items: baseline; gap: 0.6vw; }
.sc-timeouts-label { font-size: clamp(13px, 1.4vw, 26px); color: #9ca3af; }
.sc-timeouts-num { font-size: clamp(26px, 3.4vw, 72px); font-weight: 800; font-variant-numeric: tabular-nums; color: #e5e7eb; }
.sc-timeouts-empty { color: #ef4444; }
.sc-timeouts-max { font-size: clamp(12px, 1.2vw, 24px); color: #6b7280; font-weight: 700; }

/* ── 中间信息 ── */
.sc-center {
  display: flex; flex-direction: column; align-items: center;
  gap: 1.2vh; padding: 0 1vw; min-width: 18vw;
}
.sc-quarter { font-size: clamp(18px, 2.2vw, 44px); font-weight: 700; color: #e5e7eb; }
.sc-clock {
  font-size: clamp(36px, 5vw, 110px); font-weight: 900;
  font-variant-numeric: tabular-nums; color: #fff;
}
.sc-clock-danger { color: #ef4444; animation: sc-pulse 1s infinite; }
.sc-break-badge {
  font-size: clamp(20px, 2.6vw, 52px); font-weight: 800; color: #fbbf24;
  animation: sc-pulse 2s infinite;
}
.sc-target { font-size: clamp(18px, 2.2vw, 44px); font-weight: 700; color: #e5e7eb; }

/* ── 球权指示 ── */
.sc-possession {
  display: flex; align-items: center; gap: 0.6vw;
  margin-top: 1vh;
  font-size: clamp(13px, 1.3vw, 26px); font-weight: 600; color: #9ca3af;
}
.sc-possession-unset { color: #6b7280; }
.sc-possession-arrow {
  width: clamp(22px, 2.4vw, 48px); height: auto;
  animation: sc-nudge 1.4s infinite;
}
.sc-arrow-flip { transform: scaleX(-1); }

/* ── 比分数字弹跳 ── */
.sc-score-num { display: inline-block; }
.sc-score-pop { animation: sc-score-pop 0.9s cubic-bezier(0.22, 1.4, 0.36, 1); }
@keyframes sc-score-pop {
  0% { transform: scale(1); }
  20% { transform: scale(1.22); }
  50% { transform: scale(0.96); }
  75% { transform: scale(1.04); }
  100% { transform: scale(1); }
}

/* ── 数据页：顶部比分条 ── */
.sc-stats {
  position: relative; z-index: 1;
  flex: 1; display: flex; flex-direction: column; min-height: 0;
}
.sc-strip {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0.6vh 3vw 0.9vh;
  border-bottom: 1px solid #1f2937;
}
.sc-strip-side { display: flex; align-items: baseline; gap: 1vw; min-width: 0; }
.sc-strip-name {
  font-size: clamp(16px, 1.9vw, 38px); font-weight: 800;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 24vw;
}
.sc-strip-score {
  font-size: clamp(30px, 3.6vw, 76px); font-weight: 900; line-height: 1;
  font-variant-numeric: tabular-nums;
}
.sc-strip-right { justify-content: flex-end; }
.sc-strip-center { display: flex; align-items: center; gap: 1vw; }
.sc-strip-quarter { font-size: clamp(15px, 1.6vw, 32px); font-weight: 700; color: #d1d5db; }
.sc-strip-clock { font-size: clamp(24px, 2.6vw, 56px); font-weight: 900; font-variant-numeric: tabular-nums; }
.sc-strip-clock-danger { color: #ef4444; animation: sc-pulse 1s infinite; }
.sc-strip-badge { font-size: clamp(15px, 1.6vw, 32px); font-weight: 800; color: #fbbf24; animation: sc-pulse 2s infinite; }
.sc-strip-status { font-size: clamp(15px, 1.6vw, 32px); font-weight: 700; color: #d1d5db; }

/* ── 数据页：队伍条 ── */
.sc-teambar {
  display: flex; align-items: center; gap: 1vw;
  padding: 1.1vh 3vw 0.8vh;
}
.sc-teambar-accent {
  width: clamp(8px, 0.7vw, 16px); height: clamp(26px, 2.6vw, 52px);
  border-radius: 999px; flex: 0 0 auto;
}
.sc-teambar-name { font-size: clamp(24px, 2.8vw, 58px); font-weight: 900; letter-spacing: 0.02em; }
.sc-teambar-tag {
  font-size: clamp(13px, 1.3vw, 26px); font-weight: 600; color: #9ca3af;
  border: 1px solid #374151; border-radius: 999px; padding: 0.25em 1em; white-space: nowrap;
}
.sc-teambar-fouls {
  margin-left: auto; display: flex; align-items: center; gap: 0.6vw;
  font-size: clamp(14px, 1.4vw, 28px); color: #9ca3af; white-space: nowrap;
}
.sc-teambar-fouls b { font-size: clamp(22px, 2.2vw, 46px); font-weight: 800; font-variant-numeric: tabular-nums; }
.sc-foul-boxes-sm { gap: 0.35vw; }
.sc-foul-boxes-sm .sc-foul-box {
  width: clamp(13px, 1.15vw, 24px); height: clamp(13px, 1.15vw, 24px); border-width: 2px;
}
.sc-teambar-to { margin-left: 0.6vw; }
.sc-teambar-to b { margin-left: 0.2vw; }

/* ── 数据页：表格 ── */
.sc-table-wrap { flex: 1; min-height: 0; overflow: hidden; padding: 0 3vw 2.5vh; }
.sc-table { width: 100%; border-collapse: collapse; text-align: center; }
.sc-table thead th {
  position: sticky; top: 0; z-index: 2;
  background: #000; color: #6b7280; font-weight: 700;
  padding: 1vh 0.5vw; border-bottom: 2px solid #1f2937; white-space: nowrap;
}
.sc-table tbody td { padding: 0 0.5vw; color: #d1d5db; white-space: nowrap; font-variant-numeric: tabular-nums; vertical-align: middle; }
.sc-table tbody tr { border-bottom: 1px solid #111827; height: var(--row-h, auto); }
.sc-table tbody tr:nth-child(even) { background: rgba(255, 255, 255, 0.02); }
.sc-row-top td { background: rgba(255, 255, 255, 0.06); }
.sc-cell-pts { color: #fff; font-weight: 800; }
.sc-row-top .sc-cell-pts { color: #fbbf24; }
.sc-cell-danger { color: #ef4444; font-weight: 800; }
.sc-col-no { color: #6b7280; width: 3.5em; }
.sc-col-name { text-align: left; }
.sc-player { display: flex; align-items: center; gap: 0.5em; min-width: 0; }
.sc-pname { color: #fff; font-weight: 700; overflow: hidden; text-overflow: ellipsis; }
.sc-avatar {
  flex: 0 0 auto;
  width: 1.5em; height: 1.5em; border-radius: 50%; overflow: hidden;
  display: flex; align-items: center; justify-content: center;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.14);
}
.sc-avatar img { width: 100%; height: 100%; object-fit: cover; display: block; }
.sc-avatar-fb { font-size: 0.52em; font-weight: 800; color: #d1d5db; }
.sc-oncourt {
  flex: 0 0 auto;
  width: 0.5em; height: 0.5em; border-radius: 999px;
  background: #22c55e;
  box-shadow: 0 0 0.4em #22c55e; animation: sc-pulse 1.8s infinite;
}
.sc-empty { padding: 6vh 0 !important; color: #4b5563 !important; }

/* ── 本节高效球员页 ── */
.sc-hot {
  position: relative; z-index: 1;
  flex: 1; min-height: 0;
  display: flex; flex-direction: column;
  padding: 1vh 3vw 2.5vh;
}
.sc-hot-head {
  display: flex; align-items: baseline; gap: 1.4vw; flex-wrap: wrap;
  padding-bottom: 1.2vh; border-bottom: 1px solid #1f2937;
}
.sc-hot-title { font-size: clamp(26px, 3vw, 62px); font-weight: 900; letter-spacing: 0.02em; }
.sc-hot-sub { font-size: clamp(12px, 1.15vw, 22px); color: #6b7280; font-weight: 600; }
.sc-hot-cols {
  flex: 1; min-height: 0;
  display: grid; grid-template-columns: 1fr 1fr; gap: 2.4vw;
  padding-top: 2vh;
}
.sc-hot-col { display: flex; flex-direction: column; min-height: 0; }
.sc-hot-col-head { display: flex; align-items: baseline; gap: 0.8vw; padding-bottom: 1vh; }
.sc-hot-team { font-size: clamp(22px, 2.4vw, 50px); font-weight: 900; }
.sc-hot-role {
  font-size: clamp(12px, 1.1vw, 22px); font-weight: 700; color: #9ca3af;
  border: 1px solid #374151; border-radius: 999px; padding: 0.2em 0.9em; white-space: nowrap;
}
.sc-hot-list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 1.4vh; }
.sc-hot-item {
  flex: 1; min-height: 0;
  display: flex; align-items: center; gap: 1vw;
  padding: 0 1.2vw;
  border-radius: 1.2vh;
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid rgba(255, 255, 255, 0.07);
}
.sc-hot-item:first-child { background: rgba(255, 255, 255, 0.07); border-color: rgba(255, 255, 255, 0.16); }
.sc-hot-rank {
  flex: 0 0 auto; width: 1.7em; text-align: center;
  font-size: clamp(20px, 2.1vw, 44px); font-weight: 900; font-style: italic; color: #4b5563;
}
.sc-hot-rank-top { color: #fbbf24; }
.sc-hot-avatar { font-size: clamp(30px, 3.2vw, 66px); width: 1.7em; height: 1.7em; }
.sc-hot-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.25em; }
.sc-hot-name {
  font-size: clamp(20px, 2vw, 42px); font-weight: 800; color: #fff;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.sc-hot-jersey { color: #9ca3af; margin-right: 0.35em; font-weight: 700; }
.sc-hot-line { font-size: clamp(12px, 1.15vw, 24px); color: #9ca3af; font-weight: 600; }
.sc-hot-eff {
  flex: 0 0 auto; display: flex; flex-direction: column; align-items: center; padding-left: 0.6vw;
}
.sc-hot-eff b { font-size: clamp(30px, 3.4vw, 72px); font-weight: 900; font-variant-numeric: tabular-nums; color: #fff; }
.sc-hot-eff em { font-size: clamp(11px, 1vw, 20px); font-style: normal; font-weight: 700; color: #6b7280; letter-spacing: 0.1em; }
.sc-hot-empty { margin: auto; font-size: clamp(16px, 1.6vw, 32px); color: #4b5563; }

/* 高效页入场动画：标题淡入下滑、队伍从两侧错开飞入、球员逐行弹入 */
.sc-hot-head { animation: scHotHeadIn 0.55s cubic-bezier(0.22, 1, 0.36, 1) both; }
@keyframes scHotHeadIn {
  from { opacity: 0; transform: translateY(-2.4vh); }
  to   { opacity: 1; transform: translateY(0); }
}
.sc-hot-col {
  animation: scHotColIn 0.6s cubic-bezier(0.22, 1, 0.36, 1) both;
  animation-delay: calc(var(--ci) * 0.14s);
}
@keyframes scHotColIn {
  from { opacity: 0; transform: translateX(calc(var(--ci) * 8vw - 4vw)) scale(0.97); }
  to   { opacity: 1; transform: translateX(0) scale(1); }
}
.sc-hot-item {
  position: relative; overflow: hidden;
  animation: scHotItemIn 0.62s cubic-bezier(0.22, 1, 0.36, 1) both;
  animation-delay: calc(var(--ci) * 0.14s + var(--i) * 0.1s + 0.2s);
}
@keyframes scHotItemIn {
  0%   { opacity: 0; transform: translateY(3.4vh) scale(0.94); }
  60%  { opacity: 1; transform: translateY(-0.5vh) scale(1.015); }
  100% { opacity: 1; transform: translateY(0) scale(1); }
}
/* 队伍色描边高亮 */
.sc-hot-item::before {
  content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 0.45vw;
  background: var(--tc); opacity: 0.85;
  animation: scHotBar 0.5s ease-out both;
  animation-delay: calc(var(--ci) * 0.14s + var(--i) * 0.1s + 0.2s);
}
@keyframes scHotBar { from { transform: scaleY(0); } to { transform: scaleY(1); } }
/* 头名：金色光晕呼吸 + 掠光扫过 */
.sc-hot-item-top {
  background: linear-gradient(100deg, rgba(251, 191, 36, 0.16), rgba(255, 255, 255, 0.06)) !important;
  border-color: rgba(251, 191, 36, 0.5) !important;
  box-shadow: 0 0 2.6vh rgba(251, 191, 36, 0.22), inset 0 0 2.2vh rgba(251, 191, 36, 0.1);
  animation: scHotItemIn 0.62s cubic-bezier(0.22, 1, 0.36, 1) both,
             scHotTopGlow 2.4s ease-in-out infinite 1s;
  animation-delay: calc(var(--ci) * 0.14s + 0.2s), calc(var(--ci) * 0.14s + 0.9s);
}
@keyframes scHotTopGlow {
  0%, 100% { box-shadow: 0 0 2.6vh rgba(251, 191, 36, 0.22), inset 0 0 2.2vh rgba(251, 191, 36, 0.1); }
  50%      { box-shadow: 0 0 4.2vh rgba(251, 191, 36, 0.42), inset 0 0 3vh rgba(251, 191, 36, 0.18); }
}
.sc-hot-item-top::after {
  content: ''; position: absolute; top: 0; bottom: 0; width: 32%;
  left: -40%; pointer-events: none;
  background: linear-gradient(100deg, transparent, rgba(255, 255, 255, 0.28), transparent);
  animation: scHotShine 1.6s ease-out 1.1s both;
}
@keyframes scHotShine { from { left: -40%; } to { left: 130%; } }
.sc-hot-rank-top { animation: scHotCrown 1.6s ease-in-out infinite; display: inline-block; }
@keyframes scHotCrown {
  0%, 100% { transform: translateY(0) rotate(-4deg); }
  50%      { transform: translateY(-0.5vh) rotate(4deg); }
}
.sc-hot-eff b { animation: scHotEffPop 0.5s cubic-bezier(0.22, 1, 0.36, 1) both; }
@keyframes scHotEffPop {
  from { opacity: 0; transform: scale(0.5); }
  to   { opacity: 1; transform: scale(1); }
}

/* ── 结束态：MVP + 评分页 ── */
.sc-mvp {
  position: relative; z-index: 1;
  flex: 1; min-height: 0;
  display: flex; flex-direction: column;
  padding: 2vh 3vw 2.5vh; gap: 2.2vh;
}
.sc-mvp-hero {
  position: relative; overflow: hidden;
  display: flex; align-items: center; gap: 2.4vw;
  padding: 2.4vh 2.6vw; border-radius: 1.6vh;
  background: linear-gradient(100deg, rgba(251, 191, 36, 0.16), rgba(255, 255, 255, 0.04));
  border: 2px solid rgba(251, 191, 36, 0.5);
  box-shadow: 0 0 5vh rgba(251, 191, 36, 0.28), inset 0 0 3vh rgba(251, 191, 36, 0.1);
  animation: scMvpIn 0.7s cubic-bezier(0.22, 1, 0.36, 1) both;
}
@keyframes scMvpIn {
  from { opacity: 0; transform: translateY(-3vh) scale(0.96); }
  to   { opacity: 1; transform: translateY(0) scale(1); }
}
.sc-mvp-glow {
  position: absolute; inset: -40% -10%; pointer-events: none;
  background: radial-gradient(ellipse at 28% 50%, rgba(251, 191, 36, 0.4), transparent 62%);
  animation: scMvpGlow 3s ease-in-out infinite;
}
@keyframes scMvpGlow { 0%, 100% { opacity: 0.55; } 50% { opacity: 1; } }
.sc-mvp-trophy {
  font-size: clamp(48px, 6vw, 120px); line-height: 1; position: relative;
  filter: drop-shadow(0 0 2vh rgba(251, 191, 36, 0.7));
  animation: scMvpTrophy 2.6s ease-in-out infinite;
}
@keyframes scMvpTrophy {
  0%, 100% { transform: translateY(0) rotate(-6deg); }
  50%      { transform: translateY(-1.2vh) rotate(6deg); }
}
.sc-mvp-hero-main { display: flex; flex-direction: column; gap: 0.4vh; min-width: 0; position: relative; }
.sc-mvp-label { font-size: clamp(14px, 1.4vw, 28px); font-weight: 900; letter-spacing: 0.22em; color: #fbbf24; }
.sc-mvp-name { font-size: clamp(34px, 4.2vw, 90px); font-weight: 900; color: #fff; line-height: 1.05; text-shadow: 0 0 3vh rgba(251, 191, 36, 0.5); }
.sc-mvp-jersey { color: #fbbf24; margin-right: 0.3em; }
.sc-mvp-team { font-size: clamp(16px, 1.6vw, 32px); font-weight: 800; }
.sc-mvp-score { margin-left: auto; display: flex; flex-direction: column; align-items: center; flex: 0 0 auto; position: relative; }
.sc-mvp-score b { font-size: clamp(44px, 5.5vw, 120px); font-weight: 900; font-variant-numeric: tabular-nums; color: #fbbf24; text-shadow: 0 0 4vh rgba(251, 191, 36, 0.6); line-height: 1; }
.sc-mvp-score em { font-size: clamp(11px, 1.05vw, 20px); font-style: normal; font-weight: 700; color: #d1a24a; letter-spacing: 0.14em; }
.sc-mvp-stats { display: flex; gap: 1.4vw; padding-left: 1.6vw; border-left: 1px solid rgba(251, 191, 36, 0.3); flex: 0 0 auto; position: relative; }
.sc-mvp-stats span { display: flex; flex-direction: column; align-items: center; font-size: clamp(12px, 1.1vw, 22px); color: #9ca3af; font-weight: 700; }
.sc-mvp-stats b { font-size: clamp(22px, 2.4vw, 48px); color: #fff; font-weight: 900; font-variant-numeric: tabular-nums; }
.sc-mvp-nomvp { margin: 6vh auto; font-size: clamp(20px, 2.2vw, 44px); font-weight: 800; color: #6b7280; }

.sc-mvp-cols { flex: 1; min-height: 0; display: grid; grid-template-columns: 1fr 1fr; gap: 2.4vw; }
.sc-mvp-col {
  display: flex; flex-direction: column; min-height: 0;
  animation: scMvpColIn 0.6s cubic-bezier(0.22, 1, 0.36, 1) both;
  animation-delay: calc(var(--ci) * 0.14s);
}
@keyframes scMvpColIn {
  from { opacity: 0; transform: translateX(calc(var(--ci) * 8vw - 4vw)); }
  to   { opacity: 1; transform: translateX(0); }
}
.sc-mvp-col-head { display: flex; align-items: baseline; gap: 0.8vw; padding-bottom: 1vh; }
.sc-mvp-col-name { font-size: clamp(22px, 2.4vw, 50px); font-weight: 900; }
.sc-mvp-col-tag { font-size: clamp(12px, 1.1vw, 22px); font-weight: 700; color: #9ca3af; }
.sc-mvp-list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 1.2vh; overflow: hidden; }
.sc-mvp-row {
  flex: 1; min-height: 0; display: flex; align-items: center; gap: 0.9vw;
  padding: 0 1.2vw; border-radius: 1.2vh;
  font-size: clamp(16px, 1.7vw, 36px);
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid rgba(255, 255, 255, 0.07);
  animation: scHotItemIn 0.55s cubic-bezier(0.22, 1, 0.36, 1) both;
  animation-delay: calc(var(--ci) * 0.14s + var(--i) * 0.08s + 0.15s);
}
.sc-mvp-row-mvp {
  background: linear-gradient(100deg, rgba(251, 191, 36, 0.16), rgba(255, 255, 255, 0.05));
  border-color: rgba(251, 191, 36, 0.5);
  box-shadow: 0 0 2.4vh rgba(251, 191, 36, 0.22);
}
.sc-mvp-rank { flex: 0 0 auto; width: 1.6em; text-align: center; font-size: 0.9em; font-weight: 900; font-style: italic; color: #4b5563; }
.sc-mvp-avatar { font-size: 1.5em; width: 1.6em; height: 1.6em; }
.sc-mvp-pname { flex: 1; min-width: 0; font-size: 1em; font-weight: 800; color: #fff; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sc-mvp-pjersey { color: #9ca3af; margin-right: 0.3em; font-weight: 700; }
.sc-mvp-crown { margin-left: 0.4em; }
.sc-mvp-empty { margin: auto; font-size: clamp(16px, 1.6vw, 32px); color: #4b5563; }

/* 评分徽章（结束态通用；em 随行高/字号自适应缩放）*/
.sc-rating-badge {
  flex: 0 0 auto; display: inline-flex; align-items: center; gap: 0.35em;
  padding: 0.2em 0.6em; border-radius: 0.6em; line-height: 1;
  background: linear-gradient(145deg, var(--rc), color-mix(in srgb, var(--rc) 55%, #000));
  color: var(--rt, #fff);
  border: 1px solid rgba(255, 255, 255, 0.28);
  box-shadow: 0 0 0.7em var(--rs, transparent), inset 0 1px 0 rgba(255, 255, 255, 0.25);
}
.sc-rating-grade { font-size: 1em; font-weight: 900; font-style: italic; }
.sc-rating-score { font-size: 0.78em; font-weight: 800; font-variant-numeric: tabular-nums; opacity: 0.95; }
.sc-col-rating { text-align: center; }
.sc-cell-rating { text-align: center; white-space: nowrap; }
.sc-rating-na { color: #4b5563; font-weight: 700; }

/* ── 得分播报 ── */
.sc-announce {
  position: absolute; left: 50%; bottom: 8vh; z-index: 6;
  display: flex; align-items: center; gap: 1.1vw;
  padding: 1.2vh 2vw 1.2vh 1vw;
  border-radius: 999px;
  background: rgba(10, 10, 14, 0.86);
  border: 2px solid var(--ac);
  box-shadow: 0 0 50px var(--ac-glow), inset 0 0 26px rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(6px);
  pointer-events: none;
  transform: translateX(-50%);
}
/* 犯规播报：入场后轻微抖动警示 */
.sc-announce-foul { animation: sc-ann-shake 0.55s ease-in-out; }
@keyframes sc-ann-shake {
  0%, 100% { transform: translateX(-50%) rotate(0); }
  25% { transform: translateX(-50%) rotate(-1.4deg); }
  50% { transform: translateX(-50%) rotate(1.4deg); }
  75% { transform: translateX(-50%) rotate(-0.7deg); }
}
/* 播报粒子迸发 */
.sc-burst { position: absolute; left: 50%; top: 50%; width: 0; height: 0; pointer-events: none; }
.sc-burst-dot {
  position: absolute; left: 0; top: 0;
  width: 8px; height: 8px; border-radius: 50%;
  background: var(--ac); box-shadow: 0 0 10px var(--ac-glow);
  opacity: 0;
  animation: sc-burst-fly 0.9s cubic-bezier(0.2, 0.7, 0.3, 1) var(--bd) 1 both;
}
@keyframes sc-burst-fly {
  0% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
  70% { opacity: 0.9; }
  100% { opacity: 0; transform: translate(calc(-50% + var(--bx)), calc(-50% + var(--by))) scale(0.15); }
}
.sc-announce::after {
  content: ''; position: absolute; inset: 0; border-radius: inherit; pointer-events: none;
  background: linear-gradient(110deg, transparent 25%, rgba(255, 255, 255, 0.1) 48%, transparent 68%);
  background-size: 240% 100%;
  animation: sc-ann-sheen 1.7s ease-out 1 both;
}
@keyframes sc-ann-sheen { from { background-position: 135% 0; } to { background-position: -70% 0; } }
.sc-ann-avatar {
  flex: 0 0 auto;
  width: clamp(46px, 4.4vw, 96px); height: clamp(46px, 4.4vw, 96px);
  border-radius: 50%; overflow: hidden;
  display: flex; align-items: center; justify-content: center;
  background: var(--ac-dim);
  border: 2px solid var(--ac);
  box-shadow: 0 0 0.5em var(--ac-glow);
  animation: sc-ann-ring 1.7s ease-in-out infinite;
}
@keyframes sc-ann-ring {
  0%, 100% { box-shadow: 0 0 0.4em var(--ac-glow); }
  50% { box-shadow: 0 0 1.1em var(--ac-glow); }
}
.sc-ann-avatar img { width: 100%; height: 100%; object-fit: cover; display: block; }
.sc-ann-avatar-fb { font-size: clamp(20px, 2vw, 44px); font-weight: 900; color: var(--ac); }
.sc-ann-mid { display: flex; flex-direction: column; gap: 0.4vh; min-width: 0; }
.sc-ann-name {
  font-size: clamp(22px, 2.5vw, 52px); font-weight: 900; color: #fff;
  white-space: nowrap;
}
.sc-ann-jersey { color: var(--ac); margin-right: 0.35em; }
.sc-ann-team {
  font-size: clamp(13px, 1.4vw, 28px); font-weight: 600; color: var(--ac);
  white-space: nowrap;
}
.sc-ann-pts { display: flex; flex-direction: column; align-items: center; gap: 0.2vh; padding-left: 0.6vw; }
.sc-ann-pts-num {
  font-size: clamp(30px, 3.8vw, 80px); font-weight: 900; font-style: italic; line-height: 1;
  color: var(--ac); text-shadow: 0 0 0.5em var(--ac-glow);
  font-variant-numeric: tabular-nums;
  animation: sc-ann-pop 0.75s cubic-bezier(0.22, 1.4, 0.36, 1) 0.12s both;
}
@keyframes sc-ann-pop {
  0% { transform: scale(0.3); opacity: 0; }
  55% { transform: scale(1.22); opacity: 1; }
  100% { transform: scale(1); opacity: 1; }
}
.sc-ann-pts-label {
  font-size: clamp(13px, 1.4vw, 28px); font-weight: 700; color: #e5e7eb; white-space: nowrap;
}
.sc-ann-foul-txt {
  font-size: clamp(30px, 3.6vw, 76px); font-weight: 900; font-style: italic; line-height: 1;
  color: var(--ac); text-shadow: 0 0 0.5em var(--ac-glow);
  animation: sc-ann-pop 0.75s cubic-bezier(0.22, 1.4, 0.36, 1) 0.12s both;
}
.sc-ann-enter-active { animation: sc-ann-in 0.6s cubic-bezier(0.18, 1.25, 0.4, 1) both; }
.sc-ann-leave-active { animation: sc-ann-out 0.42s ease-in both; }
@keyframes sc-ann-in {
  0% { opacity: 0; transform: translate(-50%, 70%) scale(0.6); }
  60% { opacity: 1; transform: translate(-50%, -6%) scale(1.05); }
  100% { opacity: 1; transform: translate(-50%, 0) scale(1); }
}
@keyframes sc-ann-out {
  0% { opacity: 1; transform: translate(-50%, 0) scale(1); }
  100% { opacity: 0; transform: translate(-50%, 45%) scale(0.85); }
}

/* ── 退出控件 ── */
.sc-exit {
  position: absolute; top: 1.5vh; right: 1.5vw; z-index: 10;
  width: clamp(36px, 3vw, 56px); height: clamp(36px, 3vw, 56px);
  border-radius: 999px; border: 1px solid #374151;
  background: rgba(0, 0, 0, 0.6); color: #9ca3af;
  font-size: clamp(16px, 1.6vw, 30px); cursor: pointer;
  opacity: 0; pointer-events: none; transition: opacity 0.3s;
  display: flex; align-items: center; justify-content: center;
}
.sc-exit-visible { opacity: 1; pointer-events: auto; }
.sc-exit:hover { color: #fff; border-color: #fff; }
.sc-exit-hint {
  position: absolute; top: 1.5vh; right: calc(1.5vw + clamp(36px, 3vw, 56px) + 1vw); z-index: 10;
  font-size: clamp(12px, 1.2vw, 22px); color: #6b7280;
  background: rgba(0, 0, 0, 0.6); padding: 0.4em 1em; border-radius: 999px;
}

@keyframes sc-pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.45; } }
@keyframes sc-nudge { 0%, 100% { transform: translateX(0); } 50% { transform: translateX(-0.25em); } }
</style>
