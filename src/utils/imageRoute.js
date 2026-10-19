import { getActiveUrl, getRouteUrls } from './supabase'

/**
 * 图片线路跟随 + 自动重试
 * 背景：数据库里存的头像/队标是 Supabase 直连的绝对地址。当某台设备访问直连很差、
 * 接口已自动切到中转时，图片仍会去硬连直连地址，表现为「比分正常、只有图裂」。
 *
 * 做法：
 * 1. 全局拦截 <img>，把指向 Supabase Storage 的地址改写到「当前生效线路」；
 * 2. 加载失败时自动换另一条线路重试一次；
 * 3. 两条都失败才隐藏该图片（并打日志），避免出现破图图标。
 */

// 匹配 https://任意域名/storage/v1/object/... 及相对路径写法
const STORAGE_RE = /^(?:https?:\/\/[^/]+)?(\/storage\/v1\/object\/.+)$/i

function storagePath(src) {
  if (!src || typeof src !== 'string') return ''
  const m = STORAGE_RE.exec(src)
  return m ? m[1] : ''
}

function origin(url) {
  return String(url || '').replace(/\/+$/, '')
}

/** 去掉重试用的防缓存参数，用于比较「是否已尝试过某条线路」 */
function stripBuster(u) {
  return String(u || '').replace(/([?&])_r=\d+/g, '$1').replace(/[?&]$/, '')
}

/** 把任意 Supabase Storage 地址改写到当前线路；非 Storage 地址原样返回 */
export function routeImageUrl(src) {
  const path = storagePath(src)
  if (!path) return src
  return origin(getActiveUrl()) + path
}

/** 同一张图在各线路下的所有候选地址（当前线路优先） */
function variantsOf(src) {
  const path = storagePath(src)
  if (!path) return []
  return getRouteUrls().map((u) => origin(u) + path)
}

function rewrite(el) {
  if (!el || el.tagName !== 'IMG') return
  if (el.dataset.imgDead === '1' || el.dataset.imgGuard === '1') return
  const src = el.getAttribute('src')
  const path = storagePath(src)
  if (!path) return
  const target = origin(getActiveUrl()) + path
  if (src === target) return
  el.dataset.imgRaw = el.dataset.imgRaw || src
  el.setAttribute('src', target)
}

function onImageError(e) {
  const el = e.target
  if (!el || el.tagName !== 'IMG') return

  const raw = el.dataset.imgRaw || el.getAttribute('src') || ''
  const variants = variantsOf(raw)
  if (!variants.length) return

  // 只记录「已经真正尝试过的线路」，且忽略防缓存参数，避免误判为「全部失败」
  const tried = new Set(
    (el.dataset.imgTried || '').split('|').filter(Boolean).map(stripBuster)
  )
  const current = stripBuster(el.getAttribute('src') || '')
  if (current) tried.add(current)

  const next = variants.find((u) => !tried.has(stripBuster(u)))
  if (next) {
    el.dataset.imgTried = [...tried, stripBuster(next)].join('|')
    el.dataset.imgRaw = raw
    el.dataset.imgGuard = '1'
    // 加时间戳绕过失败的负缓存
    el.setAttribute('src', next + (next.includes('?') ? '&' : '?') + '_r=' + Date.now())
    // MutationObserver 是微任务、setTimeout 是宏任务，确保观察器先跳过这次改写
    setTimeout(() => { delete el.dataset.imgGuard }, 0)
  } else if (el.dataset.imgDead !== '1') {
    el.dataset.imgDead = '1'
    el.style.visibility = 'hidden'
    console.warn('[img] 所有线路均加载失败:', raw)
  }
}

let installed = false

export function installImageRouting() {
  if (installed || typeof window === 'undefined') return
  installed = true

  // 老设备（电视盒子/旧浏览器）可能缺 MutationObserver，绝不能因此影响应用启动
  try {
    // 捕获阶段监听：<img> 的 error 不冒泡，必须用 capture
    document.addEventListener('error', onImageError, true)

    const scan = (root) => {
      if (!root || root.nodeType !== 1) return
      if (root.tagName === 'IMG') {
        rewrite(root)
      } else if (root.querySelectorAll) {
        root.querySelectorAll('img').forEach(rewrite)
      }
    }

    if (typeof MutationObserver === 'undefined') {
      console.warn('[img] 当前浏览器不支持 MutationObserver，跳过图片线路跟随')
      return
    }

    const mo = new MutationObserver((records) => {
      for (const r of records) {
        if (r.type === 'attributes') {
          rewrite(r.target)
        } else {
          r.addedNodes.forEach(scan)
        }
      }
    })

    mo.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src']
    })

    document.querySelectorAll('img').forEach(rewrite)
  } catch (e) {
    console.warn('[img] 图片线路跟随初始化失败（不影响使用）', e)
  }
}
