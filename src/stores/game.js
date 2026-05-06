import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/utils/supabase'
import { useAuthStore } from '@/stores/auth'

export const useGameStore = defineStore('game', () => {
  const currentGame = ref(null)
  const homeLineup = ref([])   // 当前上场5人 [{...player, slot_no: 1-5}]
  const awayLineup = ref([])
  const actionStack = ref([])  // 前端操作栈（用于撤销）
  const realtimeChannel = ref(null)
  const isConnected = ref(false)

  // 加载赛事详情
  async function loadGame(gameId) {
    // 清空上一场的操作栈
    actionStack.value = []
    const { data, error } = await supabase
      .from('games')
      .select(`
        *,
        home_team:home_team_id(*),
        away_team:away_team_id(*)
      `)
      .eq('id', gameId)
      .single()
    if (error) throw error
    currentGame.value = data
    await loadLineup(gameId)
    return data
  }

  // 加载当前阵容
  async function loadLineup(gameId) {
    const { data: lineupData, error } = await supabase
      .from('game_lineup')
      .select(`
        id, game_id, team_id, player_id, slot_no, quarter, is_current, on_at, off_at,
        player:player_id(id, name, avatar_url, position)
      `)
      .eq('game_id', gameId)
      .eq('is_current', true)
    if (error) throw error
    if (!lineupData || lineupData.length === 0) {
      homeLineup.value = []
      awayLineup.value = []
      return
    }

    // 查询对应 team_players 获取球衣号和球队位置
    const teamIds = [...new Set(lineupData.map(l => l.team_id))]
    const playerIds = [...new Set(lineupData.map(l => l.player_id))]
    const { data: tpData } = await supabase
      .from('team_players')
      .select('team_id, player_id, jersey_no, position')
      .in('team_id', teamIds)
      .in('player_id', playerIds)
      .eq('is_active', true)

    // 构建 player_id -> { jersey_no, team_position } 映射（优先用 team_id 匹配）
    const tpMap = {}
    if (tpData) {
      for (const tp of tpData) {
        const key = `${tp.team_id}_${tp.player_id}`
        tpMap[key] = { jersey_no: tp.jersey_no, team_position: tp.position }
      }
    }

    // 补充 jersey_no 和 team_position 到 player 对象
    const enriched = lineupData.map(l => {
      const tp = tpMap[`${l.team_id}_${l.player_id}`]
      return {
        ...l,
        player: {
          ...l.player,
          jersey_no: tp?.jersey_no || l.player?.jersey_no || null,
          position: tp?.team_position || l.player?.position || ''
        }
      }
    })

    homeLineup.value = enriched.filter(l => l.team_id === currentGame.value?.home_team_id)
      .sort((a, b) => a.slot_no - b.slot_no)
    awayLineup.value = enriched.filter(l => l.team_id === currentGame.value?.away_team_id)
      .sort((a, b) => a.slot_no - b.slot_no)
  }

  // 记录一个动作（得分/篮板等）— 通过 RPC 一次性完成
  async function recordAction(playerId, teamId, actionType, delta = 1, playerName = '') {
    if (!currentGame.value) return
    const gameId = currentGame.value.id
    const auth = useAuthStore()

    const { data, error } = await supabase.rpc('record_action', {
      p_game_id: gameId,
      p_player_id: playerId,
      p_team_id: teamId,
      p_action_type: actionType,
      p_delta: delta,
      p_quarter: currentGame.value.current_quarter || 1,
      p_recorded_by: auth.user?.id || null
    })
    if (error) throw error

    // 更新本地比分（如果是得分动作）
    if (['pts_1', 'pts_2', 'pts_3'].includes(actionType)) {
      const pts = actionType === 'pts_1' ? 1 : actionType === 'pts_2' ? 2 : 3
      const isHome = teamId === currentGame.value.home_team_id
      const scoreField = isHome ? 'home_score' : 'away_score'
      const newScore = (currentGame.value[scoreField] || 0) + pts * delta
      currentGame.value = { ...currentGame.value, [scoreField]: Math.max(0, newScore) }
    }

    // 推入前端操作栈（用于撤销）
    actionStack.value.push({ actionType, delta, playerId, teamId, player_name: playerName })
    return data
  }

  // 撤销指定操作（由调用方传入要撤销的 action 对象）
  async function undoAction(action) {
    if (!action) return
    // 从 actionStack 中按属性匹配移除该条记录
    const idx = actionStack.value.findIndex(
      a => a.playerId === action.playerId && a.teamId === action.teamId && a.actionType === action.actionType
    )
    if (idx !== -1) actionStack.value.splice(idx, 1)
    // 调用 RPC 撤销（delta=-1），不经过 recordAction 避免再次 push
    const auth = useAuthStore()
    const { data, error } = await supabase.rpc('record_action', {
      p_game_id: currentGame.value.id,
      p_player_id: action.playerId,
      p_team_id: action.teamId,
      p_action_type: action.actionType,
      p_delta: -1,
      p_quarter: currentGame.value.current_quarter || 1,
      p_recorded_by: auth.user?.id || null
    })
    if (error) throw error
    // 更新本地比分
    if (['pts_1', 'pts_2', 'pts_3'].includes(action.actionType)) {
      const pts = action.actionType === 'pts_1' ? 1 : action.actionType === 'pts_2' ? 2 : 3
      const isHome = action.teamId == currentGame.value.home_team_id
      const scoreField = isHome ? 'home_score' : 'away_score'
      const newScore = (currentGame.value[scoreField] || 0) - pts
      currentGame.value = { ...currentGame.value, [scoreField]: Math.max(0, newScore) }
    }
    return data
  }

  // 换人操作
  async function substitutePlayer(gameId, teamId, outPlayerId, inPlayerId, slotNo) {
    const now = new Date().toISOString()
    // 结束换出球员
    await supabase.from('game_lineup')
      .update({ is_current: false, off_at: now })
      .eq('game_id', gameId)
      .eq('team_id', teamId)
      .eq('player_id', outPlayerId)
      .eq('is_current', true)
    // 添加换入球员
    await supabase.from('game_lineup').insert({
      game_id: gameId,
      team_id: teamId,
      player_id: inPlayerId,
      slot_no: slotNo,
      quarter: currentGame.value?.current_quarter || 1,
      on_at: now,
      is_current: true
    })
    await loadLineup(gameId)
    // 记录日志
    await supabase.from('action_logs').insert([
      { game_id: gameId, player_id: outPlayerId, team_id: teamId, action_type: 'lineup_off', delta: 0, quarter: currentGame.value?.current_quarter },
      { game_id: gameId, player_id: inPlayerId,  team_id: teamId, action_type: 'lineup_on',  delta: 0, quarter: currentGame.value?.current_quarter }
    ])
  }

  // 订阅 Realtime
  function subscribeRealtime(gameId) {
    if (realtimeChannel.value) {
      supabase.removeChannel(realtimeChannel.value)
    }
    realtimeChannel.value = supabase
      .channel(`game:${gameId}`, {
        config: {
          broadcast: { self: false },
          presence: { key: '' },
          private: false
        }
      })
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'games',
        filter: `id=eq.${gameId}`
      }, (payload) => {
        if (payload.new) currentGame.value = { ...currentGame.value, ...payload.new }
      })
      .on('postgres_changes', {
        event: '*', schema: 'public', table: 'game_lineup',
        filter: `game_id=eq.${gameId}`
      }, () => {
        // 不再自动 loadLineup，避免覆盖 TeamPanel 的乐观更新
        // lineup 变化由 TeamPanel 内部处理（乐观更新 + RPC）
      })
      .subscribe((status, err) => {
        isConnected.value = status === 'SUBSCRIBED'
        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          console.warn('[GameStore] Realtime 连接异常，5秒后重试...', status, err)
          setTimeout(() => {
            if (currentGame.value?.id === gameId) {
              subscribeRealtime(gameId)
            }
          }, 5000)
        }
      })
  }

  function unsubscribeRealtime() {
    if (realtimeChannel.value) {
      supabase.removeChannel(realtimeChannel.value)
      realtimeChannel.value = null
    }
    isConnected.value = false
  }

  return {
    currentGame,
    homeLineup,
    awayLineup,
    actionStack,
    isConnected,
    loadGame,
    loadLineup,
    recordAction,
    undoAction,
    substitutePlayer,
    subscribeRealtime,
    unsubscribeRealtime
  }
})

