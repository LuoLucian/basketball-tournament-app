import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  // ── 登录页（按需登录）─────────────────────────────────
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/auth/LoginView.vue')
  },

  // ── 主应用（公开浏览，写操作受角色控制）───────────────
  {
    path: '/',
    component: () => import('@/layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'Home',
        component: () => import('@/views/HomeView.vue')
      },
      // 赛事（公开浏览）
      {
        path: 'games',
        name: 'Games',
        component: () => import('@/views/game/GamesView.vue')
      },
      // 创建赛事（需管理员）
      {
        path: 'games/create',
        name: 'GameCreate',
        component: () => import('@/views/game/GameCreateView.vue'),
        meta: { requiresRole: ['super_admin', 'admin'] }
      },
      // 赛事详情（公开浏览）
      {
        path: 'games/:id',
        name: 'GameDetail',
        component: () => import('@/views/game/GameDetailView.vue')
      },
      // 比赛录入（需管理员/记录员）
      {
        path: 'games/:id/record',
        name: 'GameRecord',
        component: () => import('@/views/game/GameRecordView.vue'),
        meta: { requiresRole: ['super_admin', 'admin', 'recorder'] }
      },
      // 统计（公开浏览）
      {
        path: 'stats',
        name: 'Stats',
        component: () => import('@/views/stats/StatsView.vue')
      },
      {
        path: 'stats/leaderboard',
        name: 'Leaderboard',
        component: () => import('@/views/stats/LeaderboardView.vue')
      },
      // 球员（公开浏览）
      {
        path: 'players',
        name: 'Players',
        component: () => import('@/views/admin/PlayersView.vue')
      },
      {
        path: 'players/:id',
        name: 'PlayerDetail',
        component: () => import('@/views/admin/PlayerDetailView.vue')
      },
      // 管理（需管理员）
      {
        path: 'admin',
        name: 'Admin',
        component: () => import('@/views/admin/AdminView.vue'),
        meta: { requiresRole: ['super_admin', 'admin'] }
      },
      // 球队（公开浏览）
      {
        path: 'teams',
        name: 'Teams',
        component: () => import('@/views/admin/TeamsView.vue')
      },
      {
        path: 'admin/users',
        name: 'AdminUsers',
        component: () => import('@/views/admin/UsersView.vue'),
        meta: { requiresRole: ['super_admin'] }
      },
      // 个人中心（需登录）
      {
        path: 'profile',
        name: 'Profile',
        component: () => import('@/views/ProfileView.vue'),
        meta: { requiresAuth: true }
      }
    ]
  },

  // 404
  {
    path: '/:pathMatch(.*)*',
    redirect: '/'
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition
    return { top: 0 }
  }
})

// ── 全局导航守卫 ─────────────────────────────────────────
router.beforeEach(async (to, from) => {
  const auth = useAuthStore()

  // 等待初始化完成
  if (auth.loading) {
    await new Promise(resolve => {
      const stop = setInterval(() => {
        if (!auth.loading) { clearInterval(stop); resolve() }
      }, 50)
    })
  }

  // 需要登录的页面（个人中心）
  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    return { name: 'Login', query: { redirect: to.fullPath } }
  }

  // 需要特定角色的页面（管理/录入等操作）
  if (to.meta.requiresRole) {
    if (!auth.isLoggedIn) {
      return { name: 'Login', query: { redirect: to.fullPath } }
    }
    if (!to.meta.requiresRole.includes(auth.role)) {
      return { name: 'Home' }
    }
  }
})

export default router
