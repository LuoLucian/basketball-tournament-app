import { ref } from 'vue'
import { supabase } from '@/utils/supabase'

// 队伍犯规统计（本节），记录页与详情页共用
// getGame: () => game 对象（含 game_type/home_team_id/away_team_id/current_quarter/target_score）
// gameId: 比赛 ID（字符串或 () => string，独立大屏页会动态切换比赛）
// getPending: () => 离线待同步操作列表（仅录入端有，查看端传空）
export function useTeamFouls(getGame, gameId, getPending = () => []) {
  const gidOf = () => (typeof gameId === 'function' ? gameId() : gameId)
  const teamFouls = ref({ home: 0, away: 0 })
  const virtualQuarter = ref(1)   // 娱乐赛虚拟节（领先方得分每满 target/4 分切节）

  async function loadTeamFouls() {
    const g = getGame()
    if (!g) return
    const { data } = await supabase
      .from('action_logs')
      .select('action_type, delta, team_id, quarter')
      .eq('game_id', gidOf())
      .in('action_type', ['pf', 'pts_1', 'pts_2', 'pts_3'])
      .order('created_at', { ascending: true })
    const logs = data || []

    // 离线队列中尚未入库的犯规
    const pendingPf = { home: 0, away: 0 }
    for (const a of getPending()) {
      if (a.p_action_type !== 'pf' || a.p_game_id !== gidOf()) continue
      if (a.p_team_id === g.home_team_id) pendingPf.home += a.p_delta || 1
      else pendingPf.away += a.p_delta || 1
    }

    if (g.game_type === 'entertainment') {
      // 娱乐赛：领先方得分每满 target/4 分进入下一虚拟节，犯规随之重置
      const perQ = Math.max(1, Math.round((g.target_score || 120) / 4))
      const vqOf = (lead) => Math.min(4, Math.floor(lead / perQ) + 1)
      let home = 0, away = 0
      const pfByVq = {}
      for (const log of logs) {
        if (log.action_type === 'pf') {
          const vq = vqOf(Math.max(home, away))
          if (!pfByVq[vq]) pfByVq[vq] = { home: 0, away: 0 }
          if (log.team_id === g.home_team_id) pfByVq[vq].home += log.delta || 1
          else pfByVq[vq].away += log.delta || 1
        } else {
          const pts = (log.action_type === 'pts_1' ? 1 : log.action_type === 'pts_2' ? 2 : 3) * (log.delta || 1)
          if (log.team_id === g.home_team_id) home += pts
          else away += pts
        }
      }
      const curVq = vqOf(Math.max(g.home_score || 0, g.away_score || 0))
      virtualQuarter.value = curVq
      teamFouls.value = {
        home: (pfByVq[curVq]?.home || 0) + pendingPf.home,
        away: (pfByVq[curVq]?.away || 0) + pendingPf.away
      }
    } else {
      // 正式赛：按 action_logs 记录的节次统计
      const q = g.current_quarter || 1
      let h = 0, a = 0
      for (const log of logs) {
        if (log.action_type !== 'pf' || (log.quarter || 1) !== q) continue
        if (log.team_id === g.home_team_id) h += log.delta || 1
        else a += log.delta || 1
      }
      teamFouls.value = { home: h + pendingPf.home, away: a + pendingPf.away }
    }
  }

  return { teamFouls, virtualQuarter, loadTeamFouls }
}
