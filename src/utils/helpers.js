// MVP 评分公式
// pts*1.2 + reb*1.1 + ast*1.5 + stl*2 + blk*2 - tov*1.5 - pf*0.8
export function calcMvpScore(stats) {
  const { pts = 0, reb = 0, ast = 0, stl = 0, blk = 0, tov = 0, pf = 0 } = stats
  return (
    pts * 1.2 +
    reb * 1.1 +
    ast * 1.5 +
    stl * 2 +
    blk * 2 -
    tov * 1.5 -
    pf * 0.8
  ).toFixed(1)
}

// 命中率格式化
export function fmtPct(made, attempted) {
  if (!attempted) return '-'
  return ((made / attempted) * 100).toFixed(1) + '%'
}

// 格式化时间 秒 -> MM:SS
export function fmtClock(secs) {
  const m = Math.floor(secs / 60)
  const s = secs % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}

// 格式化日期
export function fmtDate(dateStr) {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('zh-CN', {
    year: 'numeric', month: '2-digit', day: '2-digit'
  })
}

// 格式化完整时间
export function fmtDateTime(dateStr) {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString('zh-CN', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit'
  })
}

// 获取球员姓名首字母（头像占位符用）
export function getInitials(name) {
  if (!name) return '?'
  // 中文姓名取最后一个字，英文取首字母
  const trimmed = name.trim()
  if (/[\u4e00-\u9fa5]/.test(trimmed)) {
    return trimmed[trimmed.length - 1]
  }
  return trimmed.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2)
}

// 角色显示名称
export const ROLE_LABELS = {
  super_admin: '总管理员',
  admin: '普通管理员',
  recorder: '记录员',
  user: '普通用户'
}

// 赛制显示名称
export const GAME_TYPE_LABELS = {
  entertainment: '🎮 120分娱乐制',
  official: '🏆 正式标准制'
}

// 赛事状态
export const GAME_STATUS_LABELS = {
  pending:   { text: '未开始', color: 'gray' },
  active:    { text: '进行中', color: 'green' },
  halftime:  { text: '中场休息', color: 'orange' },
  finished:  { text: '已结束', color: 'blue' },
  cancelled: { text: '已取消', color: 'red' }
}

// 位置显示
export const POSITION_LABELS = {
  PG: '控球后卫',
  SG: '得分后卫',
  SF: '小前锋',
  PF: '大前锋',
  C:  '中锋',
  FLEX: '全能'
}

// 球队主题色（高对比度，暗色背景下清晰可辨）
export const TEAM_COLORS = [
  // 基础高对比度色
  '#1565c0', '#c62828', '#2e7d32', '#6a1b9a',
  '#ef6c00', '#00838f', '#558b2f', '#37474f',
  '#d81b60', '#4527a0', '#1b5e20', '#e65100',
  '#006064', '#f9a825', '#4e342e', '#283593',
  '#ad1457', '#00897b', '#9e9d24', '#bf360c',
  // 新增高对比度色（更鲜艳，暗背景下更醒目）
  '#ff1744', '#2979ff', '#00e676', '#ffea00',
  '#ff9100', '#d500f9', '#ff4081', '#1de9b6',
  '#76ff03', '#ffab00', '#00b0ff', '#ea80fc',
  '#b2ff59', '#ffd740', '#ff5252', '#448aff'
]
