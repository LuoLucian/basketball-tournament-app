import { createClient } from '@supabase/supabase-js'

/**
 * 双线路 Supabase 客户端
 * - 主线路 VITE_SUPABASE_URL：香港中转代理（延迟低，比赛用）
 * - 备用线路 VITE_SUPABASE_URL_BACKUP：Supabase 直连（中转挂了自动切换）
 * 两条线路指向同一个 Supabase 项目，数据/账号/Realtime 完全一致。
 * 启动时探测主线路，不通则自动切备用；探测总耗时有上限，不阻塞启动。
 */

const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const PRIMARY_URL = import.meta.env.VITE_SUPABASE_URL
const BACKUP_URL = import.meta.env.VITE_SUPABASE_URL_BACKUP || ''

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

// 探测线路：任何 HTTP 响应（含 401）都算可达；超时/网络错误算不通
function ping(url, timeoutMs) {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  return fetch(`${url}/rest/v1/`, { signal: ctrl.signal, headers: { apikey: supabaseAnonKey } })
    .then(() => true)
    .catch(() => false)
    .finally(() => clearTimeout(timer))
}

/**
 * 线路选择：主线路 1.5s 内不通 → 试备用 → 都不行则仍用主线路（尽力而为）
 * 有备用线路时探测最多耗时 3s，无备用时跳过探测零开销
 */
export async function initSupabase() {
  if (!PRIMARY_URL) return
  let chosenUrl = PRIMARY_URL
  try {
    if (BACKUP_URL && BACKUP_URL !== PRIMARY_URL) {
      const primaryOk = await ping(PRIMARY_URL, 1500)
      if (!primaryOk) {
        const backupOk = await ping(BACKUP_URL, 1500)
        if (backupOk) chosenUrl = BACKUP_URL
      }
    }
  } catch (e) {
    // 探测异常时保持主线路兜底
  }
  supabase = makeClient(chosenUrl)
  console.info(`[supabase] 使用线路: ${chosenUrl === PRIMARY_URL ? '主' : '备'} → ${chosenUrl}`)
}
