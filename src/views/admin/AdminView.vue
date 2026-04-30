<template>
  <div class="page-container">
    <h1 class="text-xl font-bold text-white mb-5">系统管理</h1>

    <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <router-link v-for="(item, idx) in adminLinks" :key="item.to" :to="item.to"
        class="glow-card flex items-center gap-4 animate-slide-up group"
        :style="{ animationDelay: `${idx * 80}ms` }"
      >
        <div class="w-12 h-12 rounded-2xl flex items-center justify-center text-2xl flex-shrink-0 transition-transform duration-300 group-hover:scale-110"
          :style="{ backgroundColor: item.bg }">
          {{ item.icon }}
        </div>
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-white group-hover:text-primary-400 transition-colors">{{ item.label }}</p>
          <p class="text-xs text-dark-500 mt-0.5">{{ item.desc }}</p>
        </div>
        <svg class="w-4 h-4 text-dark-600 group-hover:text-primary-500 ml-auto flex-shrink-0 transition-all duration-200 group-hover:translate-x-1"
          fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </router-link>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const adminLinks = computed(() => {
  const links = [
    { to: '/teams', icon: '👕', label: '球队管理', desc: '创建和管理球队、球队成员', bg: 'rgba(139,92,246,0.15)' },
    { to: '/players', icon: '👤', label: '球员管理', desc: '球员档案、头像、统计', bg: 'rgba(6,182,212,0.15)' },
    { to: '/games/create', icon: '🏆', label: '创建赛事', desc: '发起新的比赛', bg: 'rgba(249,115,22,0.15)' },
    { to: '/stats', icon: '📊', label: '数据统计', desc: '综合统计与分析', bg: 'rgba(234,179,8,0.15)' }
  ]
  if (auth.isSuperAdmin) {
    links.push({ to: '/admin/users', icon: '👥', label: '用户管理', desc: '管理账号权限和角色', bg: 'rgba(59,130,246,0.15)' })
  }
  return links
})
</script>
