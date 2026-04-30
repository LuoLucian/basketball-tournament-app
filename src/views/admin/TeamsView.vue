<template>
  <div class="page-container max-w-3xl mx-auto">
    <div class="flex items-center justify-between mb-5">
      <h1 class="page-title">球队</h1>
      <button v-if="auth.isAdmin" @click="showCreateModal = true" class="btn-primary btn-sm">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        创建球队
      </button>
    </div>

    <div class="space-y-3">
      <div v-for="(team, idx) in teams" :key="team.id"
        class="animate-fade-in"
        :style="{ animationDelay: `${idx * 60}ms` }"
      >
        <!-- 球队卡片 -->
        <div class="card card-body flex items-center gap-3 group cursor-pointer
                    hover:border-primary-600/30 transition-all duration-300"
          :class="expandedTeamId === team.id ? 'border-primary-600/40 rounded-b-none' : ''"
          @click="toggleExpand(team)"
        >
          <!-- 球队色块 -->
          <div class="w-11 h-11 rounded-xl flex-shrink-0 flex items-center justify-center text-lg font-bold border-2"
            :style="{
              backgroundColor: (team.color || '#3b82f6') + '20',
              borderColor: (team.color || '#3b82f6') + '60',
              color: team.color || '#3b82f6'
            }">
            {{ team.name[0] }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-semibold text-white">{{ team.name }}</p>
            <p class="text-xs text-dark-500">{{ team.player_count || 0 }} 名成员</p>
          </div>
          <!-- 管理按钮：超管全部显示，普通管理员只显示自己的 -->
          <button v-if="canManage(team)"
            @click.stop="toggleExpand(team)"
            class="btn-secondary btn-sm opacity-0 group-hover:opacity-100 transition-all duration-200"
            :class="expandedTeamId === team.id ? '!opacity-100' : ''"
          >
            {{ expandedTeamId === team.id ? '收起' : '管理' }}
          </button>
          <!-- 游客/普通用户：展开箭头 -->
          <svg v-else class="w-4 h-4 text-dark-600 transition-transform duration-200 ml-auto"
            :class="expandedTeamId === team.id ? 'rotate-180' : ''"
            fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </div>

        <!-- 内嵌展开面板 -->
        <Transition name="slide-down">
          <div v-if="expandedTeamId === team.id"
            class="card rounded-t-none border-t-0 border-primary-600/30 p-5 space-y-5 shadow-neon-blue">
            <!-- ═══ 球队信息编辑 ═══ -->
            <div v-if="canManage(team)">
              <h3 class="font-semibold text-white text-sm mb-3 flex items-center gap-2">
                <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
                球队信息
              </h3>
              <div class="grid grid-cols-2 gap-3 mb-3">
                <div class="form-group">
                  <label class="label">球队名称</label>
                  <input v-model="editForm.name" type="text" class="input" />
                </div>
                <div class="form-group">
                  <label class="label">简称</label>
                  <input v-model="editForm.shortName" type="text" class="input" maxlength="10" />
                </div>
              </div>
              <div class="form-group mb-3">
                <label class="label">主题色</label>
                <div class="flex gap-2 flex-wrap">
                  <button v-for="c in TEAM_COLORS" :key="c" type="button"
                    @click="editForm.color = c"
                    class="w-7 h-7 rounded-full border-2 transition-all duration-200 hover:scale-110"
                    :style="{ backgroundColor: c }"
                    :class="editForm.color === c ? 'border-white scale-110 shadow-lg' : 'border-transparent'"
                  ></button>
                </div>
              </div>
              <div class="flex gap-3 pt-3">
                <button @click="saveTeamInfo" :disabled="saving"
                  class="flex-1 py-2.5 rounded-xl text-sm font-bold
                         bg-gradient-to-r from-primary-600 to-primary-500
                         text-white shadow-lg shadow-primary-600/20
                         hover:shadow-primary-600/40 hover:from-primary-500 hover:to-primary-400
                         active:scale-[0.98] transition-all duration-200 disabled:opacity-50">
                  <span v-if="saving" class="flex items-center justify-center gap-2">
                    <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                    </svg>
                    保存中...
                  </span>
                  <span v-else class="flex items-center justify-center gap-1.5">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                    保存信息
                  </span>
                </button>
                <button @click="confirmDeleteTeam(team)" class="px-4 py-2.5 rounded-xl text-sm font-semibold
                  bg-danger/10 border border-danger/20 text-danger hover:bg-danger/20 transition-all active:scale-[0.98]">
                  删除球队
                </button>
              </div>
            </div>

            <!-- ═══ 成员列表 ═══ -->
            <div>
              <h3 class="font-semibold text-white text-sm mb-3 flex items-center justify-between">
                <span class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-accent-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/>
                  </svg>
                  球队成员
                </span>
                <span class="text-dark-500 text-xs">{{ members.length }} 人</span>
              </h3>

              <!-- 成员网格 -->
              <div v-if="members.length > 0" class="grid grid-cols-2 sm:grid-cols-3 gap-2.5 mb-3">
                <router-link v-for="m in members" :key="m.player_id"
                  :to="`/players/${m.player_id}?from=teams`"
                  class="relative group/member flex flex-col items-center gap-2 p-3 rounded-2xl
                         border border-dark-700/30 bg-dark-800/30
                         hover:border-primary-600/40 hover:bg-dark-800/60
                         hover:shadow-neon-blue
                         active:scale-[0.97]
                         transition-all duration-200 cursor-pointer"
                >
                  <!-- 球员头像 -->
                  <div class="w-11 h-11 rounded-full overflow-hidden flex items-center justify-center text-sm font-bold border-2 flex-shrink-0"
                    :style="{
                      backgroundColor: m.avatar_url ? 'transparent' : (team.color || '#3b82f6') + '20',
                      borderColor: (team.color || '#3b82f6') + '40',
                      color: team.color || '#3b82f6'
                    }">
                    <img v-if="m.avatar_url" :src="m.avatar_url" class="w-full h-full object-cover" />
                    <span v-else>{{ m.player_name[0] }}</span>
                  </div>
                  <!-- 球衣号 + 姓名 -->
                  <div class="text-center">
                    <p class="text-sm font-semibold text-white group-hover/member:text-primary-300 transition-colors">
                      {{ m.player_name }}
                    </p>
                    <!-- 管理员：球衣号可点击编辑 -->
                    <button v-if="canManage(team)" @click.prevent="openJerseyEdit(m)"
                      class="flex items-center justify-center gap-0.5 mt-0.5 mx-auto px-2 py-0.5 rounded-lg
                             hover:bg-primary-500/15 border border-transparent hover:border-primary-500/30
                             transition-all duration-150"
                      :title="'点击修改 ' + m.player_name + ' 的球衣号'">
                      <span class="text-[11px] font-bold" :style="{ color: team.color || '#3b82f6' }">
                        #{{ m.jersey_no || '?' }}
                      </span>
                      <svg class="w-2.5 h-2.5 text-dark-600 group-hover/member:text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
                      </svg>
                    </button>
                    <!-- 游客：只读球衣号 -->
                    <div v-else class="flex items-center justify-center gap-1 mt-0.5">
                      <span class="text-[11px] font-bold" :style="{ color: team.color || '#3b82f6' }">
                        #{{ m.jersey_no || '?' }}
                      </span>
                      <span v-if="m.position" class="text-[10px] text-dark-500">
                        {{ m.position.split(',').map(p => POSITION_LABELS[p] || p).join('/') }}
                      </span>
                    </div>
                  </div>
                  <!-- 跳转提示箭头 -->
                  <svg class="absolute top-2 right-2 w-3.5 h-3.5 text-dark-600
                             group-hover/member:text-primary-400 opacity-0 group-hover/member:opacity-100
                             transition-all duration-200 group-hover/member:translate-x-0.5"
                    fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                  </svg>
                  <!-- 管理员移除按钮 -->
                  <button v-if="canManage(team)" @click.prevent="removeMember(m)"
                    class="absolute top-2 left-2 w-5 h-5 rounded-md flex items-center justify-center
                           text-dark-600 hover:text-danger hover:bg-danger/10
                           opacity-0 group-hover/member:opacity-100 transition-all duration-150"
                    title="移除成员">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </router-link>
              </div>
              <div v-else class="text-center py-6 text-dark-500 text-sm border border-dark-700/30 rounded-xl mb-3">
                暂无成员
              </div>

              <!-- 添加成员按钮 -->
              <div v-if="canManage(team)">
                <button @click="openPlayerPicker" class="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold
                  bg-primary-600/15 border border-primary-600/30 text-primary-300
                  hover:bg-primary-600/25 hover:border-primary-500/40 transition-all duration-200">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                  </svg>
                  添加成员
                </button>
              </div>
            </div>
          </div>
        </Transition>
      </div>

      <!-- 空状态 -->
      <div v-if="teams.length === 0 && !loading" class="empty-state">
        <svg class="w-16 h-16 text-dark-600 mb-3" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="M16 20 L32 12 L48 20 L48 44 L32 52 L16 44 Z" opacity="0.3"/>
          <path d="M32 12 L32 52" opacity="0.2"/>
          <path d="M16 20 L48 44" opacity="0.15"/>
          <path d="M48 20 L16 44" opacity="0.15"/>
        </svg>
        <p class="text-dark-500 text-sm">{{ auth.isAdmin ? '暂无球队，点击上方按钮创建' : '暂无球队' }}</p>
      </div>
    </div>

    <!-- 创建球队弹窗 -->
    <Teleport v-if="showCreateModal" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="showCreateModal = false">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showCreateModal = false"></div>
          <div class="relative bg-dark-850 rounded-2xl w-full max-w-md p-6 shadow-glass border border-dark-700/50">
            <h3 class="font-semibold text-white mb-5">创建球队</h3>
            <form @submit.prevent="createTeam" class="space-y-4">
              <div class="form-group">
                <label class="label">球队名称 *</label>
                <input v-model="newTeam.name" type="text" class="input" required />
              </div>
              <div class="form-group">
                <label class="label">简称</label>
                <input v-model="newTeam.shortName" type="text" class="input" maxlength="10" placeholder="最多10字" />
              </div>
              <div class="form-group">
                <label class="label">主题色</label>
                <div class="flex gap-2 flex-wrap">
                  <button v-for="c in TEAM_COLORS" :key="c" type="button"
                    @click="newTeam.color = c"
                    class="w-8 h-8 rounded-full border-2 transition-all duration-200 hover:scale-110"
                    :style="{ backgroundColor: c }"
                    :class="newTeam.color === c ? 'border-white scale-110 shadow-lg' : 'border-transparent'"
                  ></button>
                </div>
              </div>
              <div class="flex gap-2 pt-2">
                <button type="button" @click="showCreateModal = false" class="btn-secondary flex-1">取消</button>
                <button type="submit" class="btn-primary flex-1" :disabled="creating">
                  {{ creating ? '创建中...' : '创建' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- 球衣号编辑弹窗 -->
    <Teleport v-if="jerseyEditPlayer" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="jerseyEditPlayer = null">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click.self="jerseyEditPlayer = null"></div>
          <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass">
            <div class="text-center">
              <div class="w-14 h-14 rounded-full bg-primary-600/10 border border-primary-600/20 flex items-center justify-center mx-auto mb-4">
                <span class="text-2xl font-black" :style="{ color: jerseyEditPlayer.teamColor || '#3b82f6' }">
                  #{{ jerseyEditPlayer.jersey_no }}
                </span>
              </div>
              <h3 class="text-lg font-semibold text-white mb-1">修改球衣号</h3>
              <p class="text-sm text-dark-400 mb-4">{{ jerseyEditPlayer.player_name }}</p>
              <input v-model.number="jerseyEditNo" type="number" min="0" max="99"
                class="input text-center text-2xl font-bold mb-4" placeholder="0-99"
                @keyup.enter="saveJersey" />
              <div class="flex gap-3">
                <button @click="jerseyEditPlayer = null" class="btn-secondary flex-1">取消</button>
                <button @click="saveJersey" :disabled="savingJersey || jerseyEditNo < 0 || jerseyEditNo > 99"
                  class="btn-primary flex-1" :class="{ 'opacity-50': savingJersey }">
                  {{ savingJersey ? '保存中...' : '确认' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- 删除确认弹窗 -->
    <Teleport v-if="deletingTeam" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="deletingTeam = null">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm"></div>
          <div class="relative bg-dark-850 border border-dark-700/50 rounded-2xl p-6 max-w-sm w-full shadow-glass">
            <div class="text-center">
              <div class="w-14 h-14 rounded-full bg-danger/10 border border-danger/20 flex items-center justify-center mx-auto mb-4">
                <svg class="w-7 h-7 text-danger" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
              </div>
              <h3 class="text-lg font-semibold text-white mb-2">删除球队</h3>
              <p class="text-sm text-dark-400 mb-1">确定要删除 <span class="text-white font-medium">"{{ deletingTeam.name }}"</span> 吗？</p>
              <p class="text-xs text-dark-500 mb-5">球队将被标记为已删除，成员关联保留</p>
              <div class="flex gap-3">
                <button @click="deletingTeam = null" class="btn-secondary flex-1">取消</button>
                <button @click="doDeleteTeam" :disabled="deleting" class="flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold
                  bg-danger/20 border border-danger/30 text-danger hover:bg-danger/30 transition-all">
                  {{ deleting ? '删除中...' : '确认删除' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
    <!-- 球员选择器弹窗 -->
    <Teleport v-if="showPlayerPicker" to="body">
      <Transition name="modal">
        <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center" @click.self="showPlayerPicker = false">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showPlayerPicker = false"></div>
          <div class="relative bg-dark-850 rounded-t-2xl sm:rounded-2xl w-full sm:max-w-lg max-h-[85vh] flex flex-col shadow-glass border border-dark-700/50">
            <!-- 头部 -->
            <div class="flex items-center justify-between p-4 border-b border-dark-700/30 flex-shrink-0">
              <h3 class="font-semibold text-white flex items-center gap-2">
                <svg class="w-4 h-4 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                选择球员
                <span v-if="pickerSelected.size > 0" class="text-xs font-normal text-primary-400">
                  (已选 {{ pickerSelected.size }} 人)
                </span>
              </h3>
              <button @click="showPlayerPicker = false" class="text-dark-500 hover:text-white transition-colors p-1 rounded-lg hover:bg-dark-800">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- 搜索 -->
            <div class="p-4 pb-2 flex-shrink-0">
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-dark-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <input v-model="pickerSearch" type="text" class="input pl-10 text-sm" placeholder="输入姓名搜索..." />
              </div>
            </div>

            <!-- 列表 -->
            <div class="flex-1 overflow-y-auto px-4 pb-2">
              <div v-if="pickerList.length === 0" class="text-center py-10 text-dark-500 text-sm">
                {{ pickerSearch ? '没有匹配的球员' : '暂无可添加的球员' }}
              </div>
              <div v-else class="space-y-1">
                <button v-for="p in pickerList" :key="p.id" type="button"
                  @click="togglePickerSelect(p)"
                  class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-150 text-left"
                  :class="p._inTeam
                    ? 'opacity-40 cursor-not-allowed bg-dark-800/30'
                    : pickerSelected.has(p.id)
                      ? 'bg-primary-600/15 border border-primary-600/30'
                      : 'hover:bg-dark-800/60'"
                >
                  <!-- 勾选框 -->
                  <div class="w-5 h-5 rounded-md border-2 flex items-center justify-center flex-shrink-0 transition-all duration-150"
                    :class="p._inTeam
                      ? 'border-dark-700 bg-dark-800'
                      : pickerSelected.has(p.id)
                        ? 'border-primary-500 bg-primary-600'
                        : 'border-dark-600'">
                    <svg v-if="pickerSelected.has(p.id)" class="w-3 h-3 text-white" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                  <!-- 球员信息 -->
                  <div class="w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold flex-shrink-0 bg-dark-800 text-dark-400">
                    {{ p.name[0] }}
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm text-white truncate">{{ p.name }}</p>
                    <p class="text-[10px] text-dark-500">
                      <span v-if="p.height">{{ p.height }}cm</span>
                      <span v-if="p.height && p.position"> · </span>
                      <span v-if="p.position">{{ p.position.split(',').map(pos => POSITION_LABELS[pos] || pos).join('/') }}</span>
                    </p>
                  </div>
                  <!-- 状态 -->
                  <span v-if="p._inTeam" class="text-[10px] text-dark-600 flex-shrink-0">已在队中</span>
                </button>
              </div>
            </div>

            <!-- 底部操作栏 -->
            <div class="p-4 border-t border-dark-700/30 flex items-center justify-between flex-shrink-0">
              <button @click="pickerSelectAll" class="text-xs text-primary-400 hover:text-primary-300 transition-colors">
                {{ pickerSelected.size === selectableCount && selectableCount > 0 ? '取消全选' : '全选' }}
              </button>
              <div class="flex gap-2">
                <button @click="showPlayerPicker = false" class="btn-secondary btn-sm">取消</button>
                <button @click="confirmBatchAdd" :disabled="pickerSelected.size === 0 || batchAdding"
                  class="btn-primary btn-sm">
                  {{ batchAdding ? '添加中...' : `确认添加 (${pickerSelected.size})` }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'
import { TEAM_COLORS, POSITION_LABELS } from '@/utils/helpers'

const auth = useAuthStore()

// ── 数据 ──
const teams = ref([])
const allPlayers = ref([])  // 球员库
const members = ref([])     // 当前展开球队的成员
const loading = ref(true)

// ── 创建球队 ──
const showCreateModal = ref(false)
const creating = ref(false)
const newTeam = reactive({ name: '', shortName: '', color: TEAM_COLORS[0] })

// ── 展开面板 ──
const expandedTeamId = ref(null)
const saving = ref(false)
const editForm = reactive({ name: '', shortName: '', color: TEAM_COLORS[0] })

// ── 添加成员（选择器模式） ──
const showPlayerPicker = ref(false)
const pickerSearch = ref('')
const pickerSelected = ref(new Set())  // 选中的球员ID集合
const batchAdding = ref(false)

// 可选球员列表（排除已在队中的，支持搜索过滤，排序）
const pickerList = computed(() => {
  const q = pickerSearch.value.trim().toLowerCase()
  const memberIds = new Set(members.value.map(m => m.player_id))
  let list = allPlayers.value.map(p => ({ ...p, _inTeam: memberIds.has(p.id) }))
  if (q) {
    list = list.filter(p => p.name.toLowerCase().includes(q))
  }
  // 排序：中文拼音 + 数字字母
  return [...list].sort((a, b) => a.name.localeCompare(b.name, 'zh-CN-u-co-pinyin'))
})

// 可选数量（排除已在队中的）
const selectableCount = computed(() => pickerList.value.filter(p => !p._inTeam).length)

function openPlayerPicker() {
  pickerSearch.value = ''
  pickerSelected.value = new Set()
  showPlayerPicker.value = true
}

function togglePickerSelect(p) {
  if (p._inTeam) return
  const newSet = new Set(pickerSelected.value)
  if (newSet.has(p.id)) newSet.delete(p.id)
  else newSet.add(p.id)
  pickerSelected.value = newSet
}

function pickerSelectAll() {
  const selectable = pickerList.value.filter(p => !p._inTeam)
  if (pickerSelected.value.size === selectable.length) {
    pickerSelected.value = new Set()
  } else {
    pickerSelected.value = new Set(selectable.map(p => p.id))
  }
}

async function confirmBatchAdd() {
  if (pickerSelected.value.size === 0 || !expandedTeamId.value) return
  batchAdding.value = true
  const ids = [...pickerSelected.value]
  let successCount = 0
  let failCount = 0
  for (const playerId of ids) {
    try {
      const { error } = await supabase.rpc('add_team_player', {
        p_team_id: expandedTeamId.value,
        p_player_id: playerId,
        p_jersey_no: null
      })
      if (error) throw error
      successCount++
    } catch {
      failCount++
    }
  }
  if (failCount > 0) {
    alert(`成功添加 ${successCount} 人，${failCount} 人添加失败（可能已在队中）`)
  }
  pickerSelected.value = new Set()
  showPlayerPicker.value = false
  await loadMembers(expandedTeamId.value)
  await loadTeams()
  batchAdding.value = false
}

// ── 删除 ──
const deletingTeam = ref(null)
const deleting = ref(false)

// ── 球衣号编辑 ──
const jerseyEditPlayer = ref(null)
const jerseyEditNo = ref(0)
const savingJersey = ref(false)

function openJerseyEdit(m) {
  jerseyEditPlayer.value = {
    player_id: m.player_id,
    player_name: m.player_name,
    jersey_no: m.jersey_no,
    teamColor: teams.value.find(t => t.id === expandedTeamId.value)?.color || '#3b82f6'
  }
  jerseyEditNo.value = m.jersey_no || 0
}

async function saveJersey() {
  if (!jerseyEditPlayer.value || jerseyEditNo.value === null) return
  savingJersey.value = true
  try {
    const { error } = await supabase.rpc('update_player_jersey', {
      p_team_id: expandedTeamId.value,
      p_player_id: jerseyEditPlayer.value.player_id,
      p_new_jersey_no: jerseyEditNo.value
    })
    if (error) throw error
    jerseyEditPlayer.value = null
    await loadMembers(expandedTeamId.value)
  } catch (e) {
    alert('修改失败：' + (e.message || '未知错误'))
  } finally {
    savingJersey.value = false
  }
}

// ── 权限判断 ──
function canManage(team) {
  return auth.isSuperAdmin || team.owner_id === auth.user?.id
}

// ── 加载球队列表 ──
async function loadTeams() {
  loading.value = true
  const { data } = await supabase
    .from('teams')
    .select(`*, team_players(count), profiles:owner_id(username, display_name)`)
    .eq('is_active', true)
    .order('name')
  if (data) {
    teams.value = data.map(t => ({
      ...t,
      player_count: t.team_players?.[0]?.count || 0
    })).sort((a, b) => a.name.localeCompare(b.name, 'zh-CN-u-co-pinyin'))
  }
  loading.value = false
}

// ── 加载球员库（添加成员用） ──
async function loadAllPlayers() {
  const { data } = await supabase
    .from('players')
    .select('id, name, position, height, weight')
    .eq('is_active', true)
  if (data) allPlayers.value = data
}

// ── 展开/收起球队 ──
async function toggleExpand(team) {
  if (expandedTeamId.value === team.id) {
    expandedTeamId.value = null
    return
  }
  expandedTeamId.value = team.id
  // 回填编辑表单
  editForm.name = team.name || ''
  editForm.shortName = team.short_name || ''
  editForm.color = team.color || TEAM_COLORS[0]
  // 加载成员
  await loadMembers(team.id)
}

// ── 加载球队成员 ──
async function loadMembers(teamId) {
  const { data } = await supabase
    .from('team_players')
    .select(`*, players!inner(id, name, position, height, avatar_url)`)
    .eq('team_id', teamId)
    .eq('is_active', true)
    .order('jersey_no')
  if (data) {
    members.value = data.map(m => ({
      player_id: m.player_id,
      jersey_no: m.jersey_no,
      player_name: m.players?.name || '',
      position: m.players?.position || '',
      height: m.players?.height || null,
      avatar_url: m.players?.avatar_url || null
    }))
  } else {
    members.value = []
  }
}

// ── 保存球队信息 ──
async function saveTeamInfo() {
  saving.value = true
  try {
    const { error } = await supabase.rpc('update_team', {
      p_team_id: expandedTeamId.value,
      p_name: editForm.name.trim() || null,
      p_short_name: editForm.shortName || null,
      p_color: editForm.color
    })
    if (error) throw error
    await loadTeams()
    // 更新展开中的球队卡片数据
    const updated = teams.value.find(t => t.id === expandedTeamId.value)
    if (updated) {
      editForm.name = updated.name
      editForm.shortName = updated.short_name || ''
      editForm.color = updated.color
    }
  } catch (e) {
    alert('保存失败：' + (e.message || '未知错误'))
  } finally {
    saving.value = false
  }
}

// ── 删除球队 ──
function confirmDeleteTeam(team) {
  deletingTeam.value = team
}

async function doDeleteTeam() {
  if (!deletingTeam.value) return
  deleting.value = true
  try {
    const { error } = await supabase.rpc('delete_team', { p_team_id: deletingTeam.value.id })
    if (error) throw error
    expandedTeamId.value = null
    deletingTeam.value = null
    await loadTeams()
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  } finally {
    deleting.value = false
  }
}


// ── 移除成员 ──
async function removeMember(m) {
  if (!confirm(`确定将 ${m.player_name} 从球队移除？`)) return
  try {
    const { error } = await supabase.rpc('remove_team_player', {
      p_team_id: expandedTeamId.value,
      p_player_id: m.player_id
    })
    if (error) throw error
    await loadMembers(expandedTeamId.value)
    await loadTeams()
  } catch (e) {
    alert('移除失败：' + (e.message || '未知错误'))
  }
}

// ── 创建球队 ──
async function createTeam() {
  if (!newTeam.name.trim()) return
  creating.value = true
  try {
    const { error } = await supabase.rpc('add_team', {
      p_name: newTeam.name.trim(),
      p_short_name: newTeam.shortName || null,
      p_color: newTeam.color,
      p_owner_id: auth.user?.id || null
    })
    if (error) throw error
    showCreateModal.value = false
    newTeam.name = ''; newTeam.shortName = ''
    await loadTeams()
  } catch (e) {
    alert('创建失败：' + (e.message || '未知错误'))
  } finally {
    creating.value = false
  }
}

onMounted(() => {
  loadTeams()
  if (auth.isAdmin) loadAllPlayers()
})
</script>

<style scoped>
.slide-down-enter-active {
  transition: all 0.3s ease-out;
}
.slide-down-leave-active {
  transition: all 0.2s ease-in;
}
.slide-down-enter-from {
  opacity: 0;
  max-height: 0;
  transform: translateY(-5px);
  overflow: hidden;
}
.slide-down-leave-to {
  opacity: 0;
  max-height: 0;
  overflow: hidden;
}
.modal-enter-active { transition: all 0.2s ease; }
.modal-leave-active { transition: all 0.15s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-from > div:last-child { transform: scale(0.95); }
</style>
