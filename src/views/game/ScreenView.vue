<template>
  <div class="scrv-root">
    <!-- 启动中 -->
    <div v-if="state === 'boot'" class="scrv-center">
      <div class="scrv-spinner"></div>
      <p class="scrv-hint">正在连接大屏服务...</p>
    </div>

    <!-- 登录 -->
    <div v-else-if="state === 'login'" class="scrv-center">
      <div class="scrv-login">
        <div class="scrv-logo">🏀</div>
        <h1 class="scrv-login-title">比赛大屏</h1>
        <form class="scrv-form" @submit.prevent="handleLogin">
          <input v-model="loginForm.username" class="scrv-input" type="text" placeholder="用户名"
            autocomplete="username" autocapitalize="off" spellcheck="false" />
          <input v-model="loginForm.password" class="scrv-input" type="password" placeholder="密码"
            autocomplete="current-password" />
          <p v-if="loginError" class="scrv-error">{{ loginError }}</p>
          <button class="scrv-btn" type="submit" :disabled="loginLoading || !loginForm.username || !loginForm.password">
            {{ loginLoading ? '登录中...' : '登 录' }}
          </button>
        </form>
        <p class="scrv-note">请使用已授予「投屏」权限的账号登录，登录状态会保留在本设备</p>
      </div>
    </div>

    <!-- 无权限 -->
    <div v-else-if="state === 'denied'" class="scrv-center">
      <div class="scrv-denied">
        <div class="scrv-denied-icon">🔒</div>
        <h1 class="scrv-title">暂无投屏权限</h1>
        <p class="scrv-hint">当前账号「{{ auth.profile?.display_name || auth.user?.username }}」未被授予投屏权限</p>
        <p class="scrv-hint">请联系总管理员在「用户管理」中开启投屏开关</p>
        <button class="scrv-btn scrv-btn-ghost" @click="switchAccount">切换账号</button>
      </div>
    </div>

    <!-- 等待比赛开始 -->
    <div v-else-if="state === 'waiting'" class="scrv-center">
      <div class="scrv-waiting">
        <div class="scrv-wait-dot"></div>
        <h1 class="scrv-title">等待比赛开始</h1>
        <p class="scrv-hint">比赛开始后将自动进入大屏画面</p>
        <button class="scrv-btn scrv-btn-ghost" @click="switchAccount">退出登录</button>
      </div>
    </div>

    <!-- 选择比赛（多场同时进行） -->
    <div v-else-if="state === 'select'" class="scrv-center">
      <div class="scrv-select">
        <h1 class="scrv-title">选择要投屏的比赛</h1>
        <button v-for="g in gameList" :key="g.id" class="scrv-game" @click="openGame(g.id)">
          <span class="scrv-game-team" :style="{ color: g.home_team?.color || '#3b82f6' }">
            {{ g.home_team?.name || '主队' }}
          </span>
          <span class="scrv-game-score">{{ g.home_score ?? 0 }} : {{ g.away_score ?? 0 }}</span>
          <span class="scrv-game-team" :style="{ color: g.away_team?.color || '#f97316' }">
            {{ g.away_team?.name || '客队' }}
          </span>
          <span class="scrv-game-badge">{{ g.status === 'halftime' ? '中场' : '进行中' }}</span>
        </button>
        <button class="scrv-btn scrv-btn-ghost" @click="switchAccount">退出登录</button>
      </div>
    </div>

    <!-- 大屏展示 -->
    <ScreenDisplay v-if="state === 'live' && game" :game="game" :stats="stats" :team-fouls="teamFouls"
      :court-lineup="courtLineup" @close="closeGame" />
  </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeUnmount } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { useTeamFouls } from '@/composables/useTeamFouls'
import ScreenDisplay from '@/components/game/ScreenDisplay.vue'

// 独立大屏页（/screen）：
// 电视/投影浏览器收藏本地址，登录一次后常驻：
//   - 无进行中比赛 → 等待画面，实时监听，开赛自动进入
//   - 一场进行中   → 自动进入该场大屏
//   - 多场进行中   → 显示大按钮选择
//   - /screen?game=<id> 可直接指定某场比赛
const auth = useAuthStore()
const route = useRoute()

const state = ref('boot') // boot | login | denied | select | waiting | live
const loginForm = ref({ username: '', password: '' })
const loginError = ref('')
const loginLoading = ref(false)
const gameList = ref([])
const game = ref(null)
const stats = ref([])
const courtLineup = ref([])

const { teamFouls, loadTeamFouls } = useTeamFouls(() => game.value, () => game.value?.id)

let liveChannel = null
let listChannel = null
let foulTimer = null
let listTimer = null
let finishedTimer = null
let pollTimer = null

// ── 认证流程 ──
async function evaluateAuth() {
  if (!auth.isLoggedIn) { state.value = 'login'; return }
  if (!auth.canScreen) { state.value = 'denied'; return }
  const forced = route.query.game
  if (forced) {
    openGame(String(forced))
  } else {
    loadList()
    subscribeList()
  }
}

async function handleLogin() {
  loginError.value = ''
  loginLoading.value = true
  try {
    await auth.signIn(loginForm.value.username.trim(), loginForm.value.password)
    evaluateAuth()
  } catch (e) {
    loginError.value = e.message || '登录失败'
  } finally {
    loginLoading.value = false
  }
}

function switchAccount() {
  auth.signOut()
  state.value = 'login'
  loginForm.value = { username: '', password: '' }
  loginError.value = ''
}

// ── 比赛列表（自动选择 / 等待）──
// force=true：由 closeGame 主动调用（已退出大屏），允许重新匹配；
// 平时（正在直播某场）任何比赛表变更都不应打断当前大屏。
// afterClose=true：用户主动退出大屏 —— 还有进行中的比赛就停留在选择页，绝不自动跳到另一场。
async function loadList(force = false, afterClose = false) {
  if (state.value === 'live' && !force) return
  const { data, error } = await supabase
    .from('games')
    .select('id, title, status, game_type, home_score, away_score, home_team:home_team_id(id, name, color), away_team:away_team_id(id, name, color)')
    .in('status', ['active', 'halftime'])
  if (error) return
  gameList.value = data || []

  if (afterClose) {
    state.value = gameList.value.length ? 'select' : 'waiting'
    return
  }

  // 自动匹配（等待画面 / 初始进入）：仅一场时自动进入，多场显示选择
  if (gameList.value.length === 1) { openGame(gameList.value[0].id); return }
  if (gameList.value.length > 1) { state.value = 'select'; return }
  state.value = 'waiting'
}

function debounceList() {
  clearTimeout(listTimer)
  listTimer = setTimeout(loadList, 800)
}

function subscribeList() {
  unsubscribeList()
  listChannel = supabase
    .channel('screen:list')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'games' }, debounceList)
    .subscribe()
}

function unsubscribeList() {
  if (listChannel) { supabase.removeChannel(listChannel); listChannel = null }
}

// ── 进入某场比赛的大屏 ──
async function openGame(gid) {
  const { data: g, error } = await supabase
    .from('games')
    .select('*, home_team:home_team_id(*), away_team:away_team_id(*)')
    .eq('id', gid)
    .single()
  if (error || !g) { loadList(); return }

  game.value = g
  stats.value = []
  courtLineup.value = []
  state.value = 'live'
  // 直播期间不再监听比赛列表：其他比赛的任何变更都不应打断当前大屏
  unsubscribeList()

  loadTeamFouls()
  loadStats(g)
  loadCourtLineup(gid)
  subscribeLive(gid)
  startPolling(gid)
}

async function loadStats(g) {
  const gid = g.id
  const [tpRes, statsRes] = await Promise.allSettled([
    supabase.from('team_players')
      .select('team_id, player_id, jersey_no, position, player:player_id(id, name, avatar_url)')
      .in('team_id', [g.home_team_id, g.away_team_id])
      .eq('is_active', true),
    supabase.from('game_stats')
      .select('player_id, team_id, pts, reb, ast, stl, blk, tov, pf, fg2m, fg2a, fg3m, fg3a, ftm, fta, player_name, player_avatar_url, jersey_no')
      .eq('game_id', gid)
  ])
  const statsMap = {}
  if (statsRes.status === 'fulfilled' && statsRes.value.data) {
    for (const s of statsRes.value.data) statsMap[s.player_id] = s
  }
  const merged = []
  if (tpRes.status === 'fulfilled' && tpRes.value.data) {
    // 报名球员全量展示，无数据补 0
    for (const tp of tpRes.value.data) {
      const s = statsMap[tp.player_id]
      if (s) {
        merged.push({
          ...s,
          team_id: s.team_id || tp.team_id,
          player_name: s.player_name || tp.player?.name || '未知',
          jersey_no: s.jersey_no ?? tp.jersey_no,
          player_avatar_url: s.player_avatar_url || tp.player?.avatar_url || null,
          player_position: s.player_position || tp.position || 'FLEX'
        })
      } else {
        merged.push({
          game_id: gid, player_id: tp.player_id, team_id: tp.team_id,
          pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
          fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0, ftm: 0, fta: 0,
          player_name: tp.player?.name || '未知', jersey_no: tp.jersey_no,
          player_avatar_url: tp.player?.avatar_url || null,
          player_position: tp.position || 'FLEX'
        })
      }
    }
  } else if (statsRes.status === 'fulfilled' && statsRes.value.data) {
    merged.push(...statsRes.value.data)
  }
  if (game.value?.id === gid) stats.value = merged
}

async function loadCourtLineup(gid) {
  const { data } = await supabase
    .from('game_lineup')
    .select('player_id, team_id, slot_no, on_at')
    .eq('game_id', gid)
    .eq('is_current', true)
  if (data && game.value?.id === gid) courtLineup.value = data
}

// ── 实时同步 ──
function subscribeLive(gid) {
  unsubscribeLive()
  liveChannel = supabase
    .channel(`screen:${gid}`)
    .on('postgres_changes', {
      event: 'UPDATE', schema: 'public', table: 'games', filter: `id=eq.${gid}`
    }, (p) => {
      if (p.new && game.value?.id === gid) {
        game.value = { ...game.value, ...p.new }
        debounceFouls()
      }
    })
    .on('postgres_changes', {
      event: 'INSERT', schema: 'public', table: 'action_logs', filter: `game_id=eq.${gid}`
    }, () => {
      debounceFouls()
      if (game.value) loadStats(game.value)
    })
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'game_lineup', filter: `game_id=eq.${gid}`
    }, () => loadCourtLineup(gid))
    .subscribe()
}

function unsubscribeLive() {
  if (liveChannel) { supabase.removeChannel(liveChannel); liveChannel = null }
}

// 兜底轮询：现场网络丢包时 realtime 可能漏事件（尤其暂停状态），
// 每 5 秒重拉一次比赛行，保证大屏的暂停/节次/比分状态最终一致
function startPolling(gid) {
  stopPolling()
  pollTimer = setInterval(async () => {
    if (state.value !== 'live' || game.value?.id !== gid) return
    const { data } = await supabase.from('games').select('*').eq('id', gid).maybeSingle()
    if (data && game.value?.id === gid) {
      game.value = { ...game.value, ...data }
      debounceFouls()
    }
  }, 5000)
}

function stopPolling() {
  if (pollTimer) { clearInterval(pollTimer); pollTimer = null }
}

function debounceFouls() {
  clearTimeout(foulTimer)
  foulTimer = setTimeout(loadTeamFouls, 600)
}

// 比赛结束后 2 分钟自动回到列表（全天挂机的电视可接续下一场）
watch(() => game.value?.status, (s) => {
  clearTimeout(finishedTimer)
  if (s === 'finished') finishedTimer = setTimeout(closeGame, 120000)
})

function closeGame() {
  clearTimeout(finishedTimer)
  unsubscribeLive()
  stopPolling()
  game.value = null
  stats.value = []
  courtLineup.value = []
  loadList(true, true)
  subscribeList()
}

onMounted(async () => {
  // 等待 auth 初始化（恢复本地登录状态）
  while (auth.loading) {
    await new Promise(r => setTimeout(r, 50))
  }
  evaluateAuth()
})

onBeforeUnmount(() => {
  clearTimeout(foulTimer)
  clearTimeout(listTimer)
  clearTimeout(finishedTimer)
  stopPolling()
  unsubscribeLive()
  unsubscribeList()
})
</script>

<style scoped>
.scrv-root {
  position: fixed; inset: 0; z-index: 9998;
  background: #000; color: #fff;
  overflow: hidden;
}

/* ── 通用居中容器 ── */
.scrv-center {
  height: 100%; display: flex; align-items: center; justify-content: center;
  padding: 4vw;
}
.scrv-title {
  font-size: clamp(28px, 3.4vw, 68px); font-weight: 800; margin: 0 0 1.5vh;
}
.scrv-hint {
  font-size: clamp(14px, 1.4vw, 26px); color: #6b7280; margin: 0.6vh 0;
}
.scrv-spinner {
  width: clamp(36px, 3vw, 60px); height: clamp(36px, 3vw, 60px);
  border: 4px solid #1f2937; border-top-color: #3b82f6; border-radius: 999px;
  animation: scrv-spin 0.9s linear infinite; margin-bottom: 2vh;
}
@keyframes scrv-spin { to { transform: rotate(360deg); } }

/* ── 登录 ── */
.scrv-login { width: min(480px, 88vw); text-align: center; }
.scrv-logo { font-size: clamp(48px, 5vw, 96px); margin-bottom: 1vh; }
.scrv-login-title { font-size: clamp(28px, 3vw, 60px); font-weight: 800; margin: 0 0 3vh; }
.scrv-form { display: flex; flex-direction: column; gap: 1.6vh; }
.scrv-input {
  width: 100%; padding: 0.8em 1em; border-radius: 14px;
  background: #111827; border: 2px solid #1f2937; color: #fff;
  font-size: clamp(16px, 1.6vw, 28px); outline: none; transition: border-color 0.2s;
  box-sizing: border-box;
}
.scrv-input:focus { border-color: #3b82f6; }
.scrv-input::placeholder { color: #4b5563; }
.scrv-btn {
  padding: 0.8em 1em; border-radius: 14px; border: none;
  background: #2563eb; color: #fff; font-weight: 800;
  font-size: clamp(16px, 1.6vw, 28px); cursor: pointer; transition: background 0.2s;
}
.scrv-btn:hover { background: #1d4ed8; }
.scrv-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.scrv-btn-ghost {
  margin-top: 2vh; background: transparent; border: 2px solid #374151;
  color: #9ca3af; font-weight: 600;
}
.scrv-btn-ghost:hover { color: #fff; border-color: #fff; background: transparent; }
.scrv-error { color: #ef4444; font-size: clamp(14px, 1.4vw, 24px); margin: 0; }
.scrv-note { color: #4b5563; font-size: clamp(12px, 1.2vw, 20px); margin-top: 3vh; line-height: 1.6; }

/* ── 无权限 / 等待 ── */
.scrv-denied, .scrv-waiting { text-align: center; display: flex; flex-direction: column; align-items: center; }
.scrv-denied-icon { font-size: clamp(44px, 4.4vw, 88px); margin-bottom: 1.5vh; }
.scrv-wait-dot {
  width: clamp(14px, 1.3vw, 26px); height: clamp(14px, 1.3vw, 26px);
  border-radius: 999px; background: #22c55e; margin-bottom: 2.5vh;
  animation: scrv-pulse 1.6s infinite;
}
@keyframes scrv-pulse { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.4; transform: scale(0.8); } }

/* ── 选择比赛 ── */
.scrv-select { display: flex; flex-direction: column; align-items: center; gap: 2vh; width: min(1100px, 92vw); }
.scrv-game {
  position: relative; width: 100%; display: flex; align-items: center; justify-content: space-evenly;
  padding: 3.2vh 2vw; border-radius: 20px; cursor: pointer;
  background: #0d1117; border: 2px solid #1f2937; transition: border-color 0.2s, background 0.2s;
}
.scrv-game:hover { border-color: #3b82f6; background: #101828; }
.scrv-game-team { font-size: clamp(22px, 2.6vw, 52px); font-weight: 800; }
.scrv-game-score { font-size: clamp(26px, 3.2vw, 64px); font-weight: 900; color: #fff; font-variant-numeric: tabular-nums; }
.scrv-game-badge {
  position: absolute; top: -12px; right: 20px;
  font-size: clamp(11px, 1vw, 18px); font-weight: 700; color: #fff;
  background: #dc2626; padding: 0.2em 0.9em; border-radius: 999px;
  animation: scrv-pulse 1.6s infinite;
}
</style>
