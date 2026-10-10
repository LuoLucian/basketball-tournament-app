// FIBA 暂停规则：
//   · 常规时间：4 节制 上半场(Q1-Q2) 每队 2 次、下半场(Q3-Q4) 每队 3 次，不结转
//   · 加时：每个加时每队 1 次
// 计数存放于 games 表：
//   home_timeouts_h1 / home_timeouts_h2 / away_timeouts_h1 / away_timeouts_h2
//   home_timeouts_ot / away_timeouts_ot（进入新加时时由 end_quarter 清零）
export const TIMEOUT_MAX_H1 = 2
export const TIMEOUT_MAX_H2 = 3
export const TIMEOUT_MAX_OT = 1

function regularQuarters(quarters) {
  return Math.max(2, Number(quarters) || 4)
}

// 是否处于加时（节次超出常规节数）
export function isOvertime(game) {
  if (!game) return false
  return (Number(game.current_quarter) || 1) > regularQuarters(game.quarters)
}

// 当前节次属于上半场(1)还是下半场(2)
export function halfOfQuarter(quarter, quarters = 4) {
  const q = Math.max(1, Number(quarter) || 1)
  return q <= Math.ceil(regularQuarters(quarters) / 2) ? 1 : 2
}

// 当前节次的暂停上限（加时 1 次；常规按半场 2/3 次）
export function timeoutMax(quarter, quarters = 4) {
  const q = Number(quarter) || 1
  const regular = regularQuarters(quarters)
  if (q > regular) return TIMEOUT_MAX_OT
  return halfOfQuarter(q, regular) === 1 ? TIMEOUT_MAX_H1 : TIMEOUT_MAX_H2
}

// 计数所在字段名（用于乐观更新）
export function timeoutKey(game, side) {
  if (isOvertime(game)) return `${side}_timeouts_ot`
  const half = halfOfQuarter(game?.current_quarter, game?.quarters)
  return `${side}_timeouts_h${half}`
}

// 某队当前节次已用暂停数
export function timeoutsUsed(game, side) {
  if (!game) return 0
  return Number(game[timeoutKey(game, side)]) || 0
}

// 某队当前节次剩余暂停数
export function timeoutsRemaining(game, side) {
  if (!game) return 0
  return Math.max(0, timeoutMax(game.current_quarter, game.quarters) - timeoutsUsed(game, side))
}