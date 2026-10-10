// 位置加权效率评分权重（与「教练面板」效率评分算法同源）
// 教练页 GameDetailView 的 calcRating 使用同一套权重，保持两处口径一致
export const POSITION_WEIGHTS = {
  PG:   { pts: 0.9, reb: 0.9, ast: 1.8, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fga_miss: -0.5, fta_miss: -0.3 },
  SG:   { pts: 1.2, reb: 1.0, ast: 1.3, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fga_miss: -0.6, fta_miss: -0.3 },
  SF:   { pts: 1.1, reb: 1.2, ast: 1.1, stl: 1.0, blk: 0.9, tov: -0.8, pf: -0.5, fga_miss: -0.6, fta_miss: -0.3 },
  PF:   { pts: 1.0, reb: 1.5, ast: 0.9, stl: 0.9, blk: 1.3, tov: -0.7, pf: -0.6, fga_miss: -0.5, fta_miss: -0.3 },
  C:    { pts: 1.0, reb: 1.8, ast: 0.7, stl: 0.7, blk: 1.6, tov: -0.6, pf: -0.6, fga_miss: -0.4, fta_miss: -0.3 },
  FLEX: { pts: 1.0, reb: 1.2, ast: 1.2, stl: 1.0, blk: 1.0, tov: -0.7, pf: -0.5, fga_miss: -0.5, fta_miss: -0.3 }
}

// 位置核心指标（用于「位置贡献度」）
export const POSITION_FOCUS = {
  PG:   { offense: 'ast', defense: 'stl' },
  SG:   { offense: 'pts', defense: 'stl' },
  SF:   { offense: 'pts', defense: 'reb' },
  PF:   { offense: 'reb', defense: 'blk' },
  C:    { offense: 'reb', defense: 'blk' },
  FLEX: { offense: 'pts', defense: 'reb' }
}

// 位置加权基础分（教练面板 calcRating 的第一步 rawScore）
// s 需包含：pts/reb/ast/stl/blk/tov/pf/fg2a/fg2m/fg3a/fg3m/fta/ftm
export function weightedEfficiency(s, pos = 'FLEX') {
  const w = POSITION_WEIGHTS[pos] || POSITION_WEIGHTS.FLEX
  const fgaMiss = (s.fg2a || 0) - (s.fg2m || 0)
  const ftaMiss = (s.fta || 0) - (s.ftm || 0)
  const raw =
    (s.pts || 0) * w.pts +
    (s.reb || 0) * w.reb +
    (s.ast || 0) * w.ast +
    (s.stl || 0) * w.stl +
    (s.blk || 0) * w.blk +
    (s.tov || 0) * w.tov +
    (s.pf || 0) * w.pf +
    fgaMiss * w.fga_miss +
    ftaMiss * w.fta_miss
  return Math.round(raw * 10) / 10
}

// ════════════════════════════════════════════════════════════
// MVP 与球员评分（与「赛事详情页」GameDetailView 完全同源）
// 大屏结束态展示评分/MVP 时复用本模块，确保与详情页结果一致
// ════════════════════════════════════════════════════════════

// MVP / 评分权重（投丢按 2 分/3 分/罚球分别计罚，与详情页一致）
export const MVP_POSITION_WEIGHTS = {
  PG:  { pts: 0.9, reb: 0.9, ast: 1.8, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  SG:  { pts: 1.2, reb: 1.0, ast: 1.3, stl: 1.2, blk: 0.7, tov: -0.8, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  SF:  { pts: 1.1, reb: 1.2, ast: 1.1, stl: 1.0, blk: 0.9, tov: -0.8, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  PF:  { pts: 1.0, reb: 1.5, ast: 0.9, stl: 0.9, blk: 1.3, tov: -0.7, pf: -0.6, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  C:   { pts: 1.0, reb: 1.8, ast: 0.7, stl: 0.7, blk: 1.6, tov: -0.6, pf: -0.6, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 },
  FLEX:{ pts: 1.0, reb: 1.2, ast: 1.2, stl: 1.0, blk: 1.0, tov: -0.7, pf: -0.5, fg2_miss: -0.4, fg3_miss: -0.4, ft_miss: -0.3 }
}

// MVP 基础分（位置加权，含投丢惩罚）
export function calcMvpRating(s, pos = 'FLEX') {
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

// 球员评分基础分（不取整，供命中率加成后统一映射）
export function calcRawPlayerScore(s, pos = 'FLEX') {
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

// 命中率加成（仅奖励高效、惩罚极低效）
export function calcShootingBonus(s) {
  let bonus = 0
  const fg2a = s.fg2a || 0
  if (fg2a >= 5) {
    const p = (s.fg2m || 0) / fg2a
    if (p >= 0.65) bonus += 1.5
    else if (p >= 0.55) bonus += 0.8
    else if (p < 0.25) bonus -= 0.5
  }
  const fg3a = s.fg3a || 0
  if (fg3a >= 4) {
    const p = (s.fg3m || 0) / fg3a
    if (p >= 0.5) bonus += 2
    else if (p >= 0.38) bonus += 1
    else if (p < 0.2) bonus -= 0.5
  }
  const fta = s.fta || 0
  if (fta >= 4) {
    const p = (s.ftm || 0) / fta
    if (p >= 0.9) bonus += 1
    else if (p >= 0.8) bonus += 0.5
    else if (p < 0.4) bonus -= 0.5
  }
  return bonus
}

// 评分等级（SS / S / A / B / C / D）
export const RATING_TIERS = [
  { min: 14, grade: 'SS', cssClass: 'rating-ss', label: '绝世',   color: '#FF8C00', shadow: 'rgba(255,140,0,0.8)',   textColor: '#FFF' },
  { min: 11, grade: 'S',  cssClass: 'rating-s',  label: '卓越',   color: '#E040FB', shadow: 'rgba(224,64,251,0.7)',  textColor: '#FFF' },
  { min: 8,  grade: 'A',  cssClass: 'rating-a',  label: '优秀',   color: '#448AFF', shadow: 'rgba(68,138,255,0.6)',  textColor: '#FFF' },
  { min: 5,  grade: 'B',  cssClass: 'rating-b',  label: '良好',   color: '#00E676', shadow: 'rgba(0,230,118,0.5)',   textColor: '#FFF' },
  { min: 2,  grade: 'C',  cssClass: 'rating-c',  label: '一般',   color: '#78909C', shadow: 'rgba(120,144,156,0.4)', textColor: '#FFF' },
  { min: 0,  grade: 'D',  cssClass: 'rating-d',  label: '需努力', color: '#546E7A', shadow: 'rgba(84,110,122,0.3)',  textColor: '#B0BEC5' }
]

export function getGradeFromScore(score) {
  for (const tier of RATING_TIERS) {
    if (score >= tier.min) return tier
  }
  return RATING_TIERS[RATING_TIERS.length - 1]
}

// 理论满分基准：娱乐制数据膨胀用高基准，正式制用低基准
export const ENTERTAINMENT_MAX_RAW = 60
export const OFFICIAL_MAX_RAW = 30

// 原始分 → 0~16 分（非线性，越往上越难），返回 { score, tier }
export function calcPlayerScore(rawScore, gameType) {
  const maxRaw = gameType === 'official' ? OFFICIAL_MAX_RAW : ENTERTAINMENT_MAX_RAW
  let ratio = rawScore / maxRaw
  ratio = Math.min(1, Math.max(0, ratio))
  let normalized = 16 * Math.pow(ratio, 0.65)
  normalized = Math.min(16, Math.max(0, normalized))
  const score = Math.round(normalized * 10) / 10
  return { score, tier: getGradeFromScore(score) }
}