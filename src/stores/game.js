import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/utils/supabase'
import { useAuthStore } from '@/stores/auth'

export const useGameStore = defineStore('game', () => {
  const currentGame = ref(null)
  const homeLineup = ref([])
  const awayLineup = ref([])
  const actionStack = ref([])
  const realtimeChannel = ref(null)
  const isConnected = ref(false)
  const localStats = ref({})

  // ── 离线待同步队列 ──
  const PENDING_KEY = 'basketball_pending_actions'
  const saved = localStorage.getItem(PENDING_KEY)
  const pendingActions = ref(saved ? JSON.parse(saved) : [])
  const pendingCount = computed(() => pendingActions.value.length)
  let isUploading = false
  let uploadTimer = null
  let syncInterval = null
  let networkListener = null

  function savePendingToStorage() {
    try {
      localStorage.setItem(PENDING_KEY, JSON.stringify(pendingActions.value))
    } catch (e) {
      console.warn('[savePending] localStorage 写入失败:', e.message)
    }
  }

  function isOnline() {
    return navigator.onLine === true
  }

  // 加入待同步队列
  function enqueuePending(gameId, playerId, teamId, actionType, delta, recordedBy) {
    const action = {
      id: Date.now() + Math.random(),
      p_game_id: gameId,
      p_player_id: playerId,
      p_team_id: teamId,
      p_action_type: actionType,
      p_delta: delta,
      p_quarter: currentGame.value?.current_quarter || 1,
      p_recorded_by: recordedBy || null,
      retries: 0
    }
    pendingActions.value = [...pendingActions.value, action]
    savePendingToStorage()
    scheduleUpload()
  }

  // ── 防抖上传 ──
  function scheduleUpload() {
    if (uploadTimer) clearTimeout(uploadTimer)
    if (isOnline()) {
      uploadTimer = setTimeout(() => flushPendingActions(), 500)
    }
  }

  // ── 上传所有待同步数据 ──
  async function flushPendingActions() {
    if (isUploading || pendingActions.value.length === 0) return
    if (!isOnline()) return

    isUploading = true
    const batch = [...pendingActions.value]
    let successCount = 0

    for (const action of batch) {
      try {
        // 换人操作
        if (action.type === 'substitute') {
          const result = await syncSubstituteAction(action)
          if (result.success) {
            pendingActions.value = pendingActions.value.filter(a => a.id !== action.id)
            successCount++
          }
          continue
        }

        // 统计操作
        const { error } = await supabase.rpc('record_action', {
          p_game_id: action.p_game_id,
          p_player_id: action.p_player_id,
          p_team_id: action.p_team_id,
          p_action_type: action.p_action_type,
          p_delta: action.p_delta,
          p_quarter: action.p_quarter,
          p_recorded_by: action.p_recorded_by
        })
        if (error) throw error
        pendingActions.value = pendingActions.value.filter(a => a.id !== action.id)
        successCount++
      } catch (e) {
        console.error('[flush] 上传失败:', action.p_action_type || action.type, e.message)
        if (!isOnline()) break
      }
    }

    if (successCount > 0) savePendingToStorage()
    isUploading = false
  }

  // ── 同步换人操作（从离线队列恢复时调用） ──
  async function syncSubstituteAction(action) {
    try {
      if (action.p_out_player_id && !action.p_in_player_id) {
        const { error } = await supabase.rpc('swap_player', {
          p_game_id: action.p_game_id, p_team_id: action.p_team_id,
          p_player_id: action.p_out_player_id, p_slot_no: 0, p_mode: 'remove'
        })
        if (error) throw error
      } else if (action.p_in_player_id && !action.p_out_player_id) {
        const { error } = await supabase.rpc('swap_player', {
          p_game_id: action.p_game_id, p_team_id: action.p_team_id,
          p_player_id: action.p_in_player_id, p_slot_no: action.p_slot_no, p_mode: 'add'
        })
        if (error) throw error
      } else if (action.p_out_player_id && action.p_in_player_id) {
        const { error: e1 } = await supabase.rpc('swap_player', {
          p_game_id: action.p_game_id, p_team_id: action.p_team_id,
          p_player_id: action.p_out_player_id, p_slot_no: 0, p_mode: 'remove'
        })
        if (e1) throw e1
        const { error: e2 } = await supabase.rpc('swap_player', {
          p_game_id: action.p_game_id, p_team_id: action.p_team_id,
          p_player_id: action.p_in_player_id, p_slot_no: action.p_slot_no, p_mode: 'add'
        })
        if (e2) throw e2
      }
      return { success: true }
    } catch (e) {
      console.error('[syncSubstitute] 换人同步失败:', e.message)
      return { success: false, error: e.message }
    }
  }

  // ── 定时同步 ──
  function startPeriodicSync() {
    if (syncInterval) return
    syncInterval = setInterval(() => {
      if (pendingActions.value.length > 0) flushPendingActions()
    }, 30000)

    if (!networkListener) {
      networkListener = window.addEventListener('online', async () => {
        if (pendingActions.value.length > 0) await flushPendingActions()
        if (currentGame.value?.id) await loadGame(currentGame.value.id)
      })
    }
  }

  function stopPeriodicSync() {
    if (syncInterval) { clearInterval(syncInterval); syncInterval = null }
  }

  // ── 强制同步所有本地数据到服务器 ──
  async function forceSyncToServer() {
    // 先上传队列中的操作
    if (pendingActions.value.length > 0) {
      await flushPendingActions()
    }
    if (!isOnline()) return { success: false, message: '离线状态，无法同步' }
    return { success: true, message: '同步完成' }
  }

  // ── 清除本地数据 ──
  function clearLocalData() {
    localStorage.removeItem(PENDING_KEY)
    pendingActions.value = []
    actionStack.value = []
  }

  // ── 加载赛事详情 ──
  async function loadGame(gameId) {
    actionStack.value = []
    loadLocalStats(gameId)
    try {
      const { data, error } = await supabase
        .from('games')
        .select(`*, home_team:home_team_id(*), away_team:away_team_id(*)`)
        .eq('id', gameId)
        .single()
      if (error) throw error
      currentGame.value = data
    } catch (e) {
      console.warn('[loadGame] 从服务器加载失败:', e.message)
    }
    await loadLineup(gameId)
  }

  // ── 加载阵容 ──
  async function loadLineup(gameId) {
    try {
      const { data: lineupData, error } = await supabase
        .from('game_lineup')
        .select(`id, game_id, team_id, player_id, slot_no, quarter, is_current, on_at, off_at,
          player:player_id(id, name, avatar_url, position)`)
        .eq('game_id', gameId)
        .eq('is_current', true)
      if (error) throw error
      if (!lineupData || lineupData.length === 0) {
        homeLineup.value = []
        awayLineup.value = []
        return
      }
      const teamIds = [...new Set(lineupData.map(l => l.team_id))]
      const playerIds = [...new Set(lineupData.map(l => l.player_id))]
      const { data: tpData } = await supabase
        .from('team_players')
        .select('team_id, player_id, jersey_no, position')
        .in('team_id', teamIds).in('player_id', playerIds).eq('is_active', true)
      const tpMap = {}
      if (tpData) for (const tp of tpData) tpMap[`${tp.team_id}_${tp.player_id}`] = { jersey_no: tp.jersey_no, team_position: tp.position }
      const enriched = lineupData.map(l => {
        const tp = tpMap[`${l.team_id}_${l.player_id}`]
        return { ...l, player: { ...l.player, jersey_no: tp?.jersey_no || null, position: tp?.team_position || l.player?.position || '' } }
      })
      homeLineup.value = enriched.filter(l => l.team_id === currentGame.value?.home_team_id).sort((a, b) => a.slot_no - b.slot_no)
      awayLineup.value = enriched.filter(l => l.team_id === currentGame.value?.away_team_id).sort((a, b) => a.slot_no - b.slot_no)
    } catch (e) {
      console.warn('[loadLineup] 加载阵容失败:', e.message)
    }
  }

  // ── 录分（在线直写，离线/失败入队，支持本地统计追踪）──
  function applyActionToLocal(playerId, actionType, delta, teamId) {
    if (!localStats.value[playerId]) {
      localStats.value[playerId] = {
        pts: 0, reb: 0, ast: 0, stl: 0, blk: 0, tov: 0, pf: 0,
        fg2m: 0, fg2a: 0, fg3m: 0, fg3a: 0, ftm: 0, fta: 0,
        team_id: teamId
      }
    }
    const s = localStats.value[playerId]
    s.pts += (actionType === 'pts_1' ? 1 : actionType === 'pts_2' ? 2 : actionType === 'pts_3' ? 3 : 0) * delta
    if (actionType === 'pts_1') { s.ftm += delta; s.fta += delta }
    else if (actionType === 'pts_2') { s.fg2m += delta; s.fg2a += delta }
    else if (actionType === 'pts_3') { s.fg3m += delta; s.fg3a += delta }
    else if (actionType === 'fga_miss') { s.fg2a += delta }
    else if (actionType === 'fg3a_miss') { s.fg3a += delta }
    else if (actionType === 'fta_miss') { s.fta += delta }
    else if (['reb', 'ast', 'stl', 'blk', 'tov', 'pf'].includes(actionType)) { s[actionType] += delta }
    localStats.value = { ...localStats.value }
  }

  function getPlayerLocalStats(playerId) {
    return localStats.value[playerId] || null
  }

  async function recordAction(playerId, teamId, actionType, delta = 1, playerName = '') {
    if (!currentGame.value) return
    const gameId = currentGame.value.id
    const auth = useAuthStore()

    // 更新本地比分
    if (['pts_1', 'pts_2', 'pts_3'].includes(actionType)) {
      const pts = actionType === 'pts_1' ? 1 : actionType === 'pts_2' ? 2 : 3
      const isHome = teamId === currentGame.value.home_team_id
      const scoreField = isHome ? 'home_score' : 'away_score'
      currentGame.value = { ...currentGame.value, [scoreField]: Math.max(0, (currentGame.value[scoreField] || 0) + pts * delta) }
    }

    // 本地球员统计
    applyActionToLocal(playerId, actionType, delta, teamId)
    saveLocalStats(gameId)

    // 推入操作栈
    actionStack.value.push({ actionType, delta, playerId, teamId, player_name: playerName })

    // 在线时直接调RPC
    if (isOnline()) {
      const { error } = await supabase.rpc('record_action', {
        p_game_id: gameId, p_player_id: playerId, p_team_id: teamId,
        p_action_type: actionType, p_delta: delta,
        p_quarter: currentGame.value.current_quarter || 1,
        p_recorded_by: auth.user?.id || null
      })
      if (error) {
        console.warn('[recordAction] RPC失败，入队:', error.message)
        enqueuePending(gameId, playerId, teamId, actionType, delta, auth.user?.id)
      }
    } else {
      enqueuePending(gameId, playerId, teamId, actionType, delta, auth.user?.id)
    }
  }

  // ── 本地统计持久化 ──
  const STATS_KEY_PREFIX = 'basketball_local_stats_'
  function saveLocalStats(gameId) {
    try { localStorage.setItem(STATS_KEY_PREFIX + gameId, JSON.stringify(localStats.value)) } catch (e) {}
  }
  function loadLocalStats(gameId) {
    try {
      const saved = localStorage.getItem(STATS_KEY_PREFIX + gameId)
      if (saved) localStats.value = JSON.parse(saved)
    } catch (e) {}
  }

  // ── 撤销（回滚比分+回滚本地统计+入队反向操作）──
  async function undoAction(action) {
    if (!action) return
    const idx = actionStack.value.findIndex(a => a.playerId === action.playerId && a.teamId === action.teamId && a.actionType === action.actionType)
    if (idx !== -1) actionStack.value.splice(idx, 1)

    if (['pts_1', 'pts_2', 'pts_3'].includes(action.actionType)) {
      const pts = action.actionType === 'pts_1' ? 1 : action.actionType === 'pts_2' ? 2 : 3
      const isHome = action.teamId == currentGame.value.home_team_id
      const scoreField = isHome ? 'home_score' : 'away_score'
      currentGame.value = { ...currentGame.value, [scoreField]: Math.max(0, (currentGame.value[scoreField] || 0) - pts) }
    }

    // 回滚本地统计
    applyActionToLocal(action.playerId, action.actionType, -1, action.teamId)
    if (currentGame.value?.id) saveLocalStats(currentGame.value.id)

    // 从队列找回退（如果还没上传）或追加反向操作
    const pendingIdx = pendingActions.value.findLastIndex(p => p.p_player_id === action.playerId && p.p_team_id === action.teamId && p.p_action_type === action.actionType)
    if (pendingIdx !== -1) {
      pendingActions.value.splice(pendingIdx, 1)
      savePendingToStorage()
    } else {
      // 不在待同步队列中：在线直写反向操作，失败或离线则入队，保证撤销不丢失
      const auth = useAuthStore()
      if (isOnline()) {
        const { error } = await supabase.rpc('record_action', {
          p_game_id: currentGame.value.id, p_player_id: action.playerId, p_team_id: action.teamId,
          p_action_type: action.actionType, p_delta: -1,
          p_quarter: currentGame.value.current_quarter || 1, p_recorded_by: auth.user?.id || null
        })
        if (error) {
          enqueuePending(currentGame.value.id, action.playerId, action.teamId, action.actionType, -1, auth.user?.id)
        }
      } else {
        enqueuePending(currentGame.value.id, action.playerId, action.teamId, action.actionType, -1, auth.user?.id)
      }
    }
  }

  // ── 换人操作（在线直写RPC，失败入队；离线直接入队）──
  async function substitutePlayer(gameId, teamId, outPlayerId, inPlayerId, slotNo) {
    if (isOnline()) {
      const { error } = await supabase.rpc('swap_player', {
        p_game_id: gameId, p_team_id: teamId,
        p_player_id: outPlayerId || inPlayerId,
        p_slot_no: outPlayerId ? 0 : slotNo,
        p_mode: outPlayerId ? 'remove' : 'add'
      })
      if (error) {
        console.warn('[substitutePlayer] RPC失败，入队:', error.message)
        pendingActions.value = [...pendingActions.value, {
          id: Date.now() + Math.random(), type: 'substitute',
          p_game_id: gameId, p_team_id: teamId, p_slot_no: slotNo,
          p_out_player_id: outPlayerId, p_in_player_id: inPlayerId,
          p_quarter: currentGame.value?.current_quarter || 1,
          p_timestamp: new Date().toISOString(),
          p_recorded_by: useAuthStore().user?.id || null, retries: 0
        }]
        savePendingToStorage()
      } else {
        await loadLineup(gameId)
      }
    } else {
      pendingActions.value = [...pendingActions.value, {
        id: Date.now() + Math.random(), type: 'substitute',
        p_game_id: gameId, p_team_id: teamId, p_slot_no: slotNo,
        p_out_player_id: outPlayerId, p_in_player_id: inPlayerId,
        p_quarter: currentGame.value?.current_quarter || 1,
        p_timestamp: new Date().toISOString(),
        p_recorded_by: useAuthStore().user?.id || null, retries: 0
      }]
      savePendingToStorage()
    }
  }

  // ── Realtime ──
  let lineupReloadTimer = null

  function subscribeRealtime(gameId) {
    if (realtimeChannel.value) supabase.removeChannel(realtimeChannel.value)
    realtimeChannel.value = supabase
      .channel(`game:${gameId}`, { config: { broadcast: { self: false }, presence: { key: '' }, private: false } })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'games', filter: `id=eq.${gameId}` }, (payload) => {
        if (payload.new) currentGame.value = { ...currentGame.value, ...payload.new }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'game_lineup', filter: `game_id=eq.${gameId}` }, () => {
        // 防抖：多个 lineup 变更事件合并为一次重拉，避免弱网下查询排队卡顿
        if (lineupReloadTimer) clearTimeout(lineupReloadTimer)
        lineupReloadTimer = setTimeout(() => {
          lineupReloadTimer = null
          if (currentGame.value?.id === gameId) loadLineup(gameId)
        }, 1000)
      })
      .subscribe((status, err) => {
        isConnected.value = status === 'SUBSCRIBED'
        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          console.warn('[GameStore] Realtime异常，5秒后重试...', status, err)
          setTimeout(() => { if (currentGame.value?.id === gameId) subscribeRealtime(gameId) }, 5000)
        }
      })
  }

  function unsubscribeRealtime() {
    if (realtimeChannel.value) { supabase.removeChannel(realtimeChannel.value); realtimeChannel.value = null }
    isConnected.value = false
  }

  return {
    currentGame, homeLineup, awayLineup, actionStack, isConnected,
    pendingActions, pendingCount, localStats,
    loadGame, loadLineup,
    recordAction, undoAction, substitutePlayer,
    getPlayerLocalStats, loadLocalStats,
    subscribeRealtime, unsubscribeRealtime,
    flushPendingActions, forceSyncToServer,
    startPeriodicSync, stopPeriodicSync, clearLocalData
  }
})
