import { createClient } from '@supabase/supabase-js'

/**
 * 双线路 Supabase 客户端（竞速选路版）
 * - 主线路 VITE_SUPABASE_URL：香港中转（比赛高峰直连劣化时更快）
 * - 备用线路 VITE_SUPABASE_URL_BACKUP：Supabase 直连（Cloudflare 边缘，平峰更快）
 * 两条线路指向同一个 Supabase 项目，数据/账号/Realtime 完全一致。
 *
 * 选路策略：
 * 1. 首次启动：两条线路并行竞速，取响应更快的一条（最多等 1.6s）
 * 2. 之后 10 分钟内：沿用 sessionStorage 记录的最快线路，秒开
 * 3. 每次启动后台再测一次，为下次启动更新最优线路（不阻塞界面）
 */

const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const PRIMARY_URL = import.meta.env.VITE_SUPABASE_URL
const BACKUP_URL = import.meta.env.VITE_SUPABASE_URL_BACKUP || ''
const ROUTE_KEY = 'sb_route_choice_v2'
const ROUTE_TTL = 10 * 60 * 1000

if (!PRIMARY_URL || !supabaseAnonKey) {
  console.warn('⚠️ 请配置 VITE_SUPABASE_URL 和 VITE_SUPABASE_ANON_KEY')
}

function makeClient(url) {
  return createClient(url || 'https://placeholder.supabase.co', supabaseAnonKey || 'placeholder-key', {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false
    },
    realtime: {
      params: {
        eventsPerSecond: 10
      }
    },
    global: {
      headers: {
        apikey: supabaseAnonKey || 'placeholder-key'
      }
    }
  })
}

// 模块加载时先建占位客户端，initSupabase() 后按选中线路重建
export let supabase = makeClient(PRIMARY_URL)

/**
 * Storage 公开地址：固定走「直连」域名，不跟随竞速选中的线路。
 * 原因：头像/队标的 publicUrl 会被写入数据库长期保存，若写入时用中转域名，
 * 中转服务器到期/停用后图片全部失效（裂图）。直连域名是 Supabase 官方地址，永久有效。
 */
const STORAGE_ORIGIN = (BACKUP_URL || PRIMARY_URL || '').replace(/\/+$/, '')

export function storagePublicUrl(bucket, path) {
  const safePath = String(path)
    .split('/')
    .filter((s) => s !== '')
    .map((s) => encodeURIComponent(s))
    .join('/')
  return `${STORAGE_ORIGIN}/storage/v1/object/public/${bucket}/${safePath}`
}

// 单线路测速：任何 HTTP 响应（含 401）都算可达，返回耗时；超时/网络错误记 Infinity
function timed(url, timeoutMs) {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  const t0 = performance.now()
  return fetch(`${url}/rest/v1/`, { signal: ctrl.signal, headers: { apikey: supabaseAnonKey } })
    .then(() => ({ url, ms: performance.now() - t0 }))
    .catch(() => ({ url, ms: Infinity }))
    .finally(() => clearTimeout(timer))
}

function readCache() {
  try {
    const s = JSON.parse(sessionStorage.getItem(ROUTE_KEY) || 'null')
    if (s && typeof s.ms === 'number' && Date.now() - s.ts < ROUTE_TTL) return s
  } catch (e) { /* 忽略 */ }
  return null
}

function writeCache(url, ms) {
  try {
    sessionStorage.setItem(ROUTE_KEY, JSON.stringify({ url, ms, ts: Date.now() }))
  } catch (e) { /* 忽略 */ }
}

function label(url) {
  return url === PRIMARY_URL ? '主(中转)' : '备(直连)'
}

// 后台刷新最优线路，供下次启动使用
async function refreshRoute() {
  const [a, b] = await Promise.all([timed(PRIMARY_URL, 2000), timed(BACKUP_URL, 2000)])
  const best = a.ms <= b.ms ? a : b
  if (best.ms !== Infinity) writeCache(best.url, best.ms)
}

export async function initSupabase() {
  if (!PRIMARY_URL) return

  if (!BACKUP_URL || BACKUP_URL === PRIMARY_URL) {
    supabase = makeClient(PRIMARY_URL)
    return
  }

  // 有近期测速结果：直接用，后台再更新
  const cache = readCache()
  if (cache) {
    supabase = makeClient(cache.url)
    console.info(`[supabase] 使用线路: ${label(cache.url)} → ${cache.url}（上次 ${Math.round(cache.ms)}ms）`)
    refreshRoute()
    return
  }

  // 首次：并行竞速，谁快用谁（最多等 1.6s）
  const [a, b] = await Promise.all([timed(PRIMARY_URL, 1600), timed(BACKUP_URL, 1600)])
  const best = a.ms <= b.ms ? a : b
  if (best.ms === Infinity) {
    supabase = makeClient(PRIMARY_URL)
    console.warn('[supabase] 两条线路均不可达，暂用主线路，等待网络恢复')
    return
  }
  supabase = makeClient(best.url)
  writeCache(best.url, best.ms)
  const fmt = (r) => (r.ms === Infinity ? '超时' : `${Math.round(r.ms)}ms`)
  console.info(`[supabase] 路径竞速: 主 ${fmt(a)} / 备 ${fmt(b)} → 选 ${label(best.url)} → ${best.url}`)
}
