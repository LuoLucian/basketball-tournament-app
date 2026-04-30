<template>
  <canvas ref="canvas" class="fixed inset-0 pointer-events-none z-0" />
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const canvas = ref(null)
let ctx = null
let animationId = null
let particles = []
const PARTICLE_COUNT = 50

const COLORS = [
  'rgba(59,130,246,',   // primary blue
  'rgba(249,115,22,',   // accent orange
  'rgba(34,197,94,',    // success green
  'rgba(139,92,246,',   // purple
  'rgba(234,179,8,',    // yellow
]

function createParticle(w, h) {
  const colorBase = COLORS[Math.floor(Math.random() * COLORS.length)]
  return {
    x: Math.random() * w,
    y: Math.random() * h,
    size: Math.random() * 2 + 0.5,
    speedX: (Math.random() - 0.5) * 0.3,
    speedY: (Math.random() - 0.5) * 0.3,
    opacity: Math.random() * 0.4 + 0.1,
    colorBase,
    pulse: Math.random() * Math.PI * 2,
    pulseSpeed: Math.random() * 0.02 + 0.005,
  }
}

function resize() {
  if (!canvas.value) return
  const dpr = window.devicePixelRatio || 1
  canvas.value.width = window.innerWidth * dpr
  canvas.value.height = window.innerHeight * dpr
  canvas.value.style.width = window.innerWidth + 'px'
  canvas.value.style.height = window.innerHeight + 'px'
  ctx = canvas.value.getContext('2d')
  ctx.scale(dpr, dpr)
}

function init() {
  resize()
  const w = window.innerWidth
  const h = window.innerHeight
  particles = Array.from({ length: PARTICLE_COUNT }, () => createParticle(w, h))
}

function draw() {
  if (!ctx) return
  const w = window.innerWidth
  const h = window.innerHeight
  ctx.clearRect(0, 0, w, h)

  for (const p of particles) {
    p.x += p.speedX
    p.y += p.speedY
    p.pulse += p.pulseSpeed

    // 边界循环
    if (p.x < -10) p.x = w + 10
    if (p.x > w + 10) p.x = -10
    if (p.y < -10) p.y = h + 10
    if (p.y > h + 10) p.y = -10

    const alpha = p.opacity * (0.5 + 0.5 * Math.sin(p.pulse))
    ctx.beginPath()
    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2)
    ctx.fillStyle = p.colorBase + alpha + ')'
    ctx.fill()

    // 光晕
    if (p.size > 1.2) {
      ctx.beginPath()
      ctx.arc(p.x, p.y, p.size * 3, 0, Math.PI * 2)
      ctx.fillStyle = p.colorBase + (alpha * 0.15) + ')'
      ctx.fill()
    }
  }

  animationId = requestAnimationFrame(draw)
}

onMounted(() => {
  init()
  draw()
  window.addEventListener('resize', resize)
})

onUnmounted(() => {
  if (animationId) cancelAnimationFrame(animationId)
  window.removeEventListener('resize', resize)
})
</script>
