<template>
  <div>
    <div class="flex items-center gap-3 mb-3">
      <div class="w-14 h-14 rounded-2xl flex-shrink-0 flex items-center justify-center border-2 overflow-hidden p-1"
        :style="{ backgroundColor: tint, borderColor: border }">
        <img v-if="modelValue" :src="modelValue" class="w-full h-full object-contain" alt="队标" />
        <span v-else class="text-lg font-bold" :style="{ color: accent }">{{ fallbackChar }}</span>
      </div>
      <div class="text-xs text-dark-500 leading-relaxed">
        <p>选择默认队标，或上传自己的图片</p>
        <p>长条形图片会等比缩放完整显示，不会被裁掉</p>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <button v-for="p in TEAM_LOGO_PRESETS" :key="p.id" type="button" :title="p.label"
        @click="$emit('update:modelValue', p.url)"
        class="w-11 h-11 rounded-xl overflow-hidden border-2 p-1 transition-all duration-200 hover:scale-105"
        :class="modelValue === p.url ? 'border-white shadow-lg scale-105' : 'border-dark-700'"
        :style="{ backgroundColor: tint }">
        <img :src="p.url" class="w-full h-full object-contain" :alt="p.label" />
      </button>

      <button type="button" @click="pickFile" :disabled="uploading" title="上传图片"
        class="w-11 h-11 rounded-xl border-2 border-dashed border-dark-600 hover:border-primary-500
               text-dark-500 hover:text-primary-400 flex items-center justify-center transition-colors
               disabled:opacity-60">
        <svg v-if="!uploading" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        <svg v-else class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
        </svg>
      </button>

      <button v-if="modelValue" type="button" @click="$emit('update:modelValue', '')"
        class="h-11 px-3 rounded-xl border border-dark-700 text-xs text-dark-500
               hover:text-danger hover:border-danger/40 transition-colors">
        清除
      </button>

      <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="handleFile" />
    </div>
    <p class="text-[10px] text-dark-600 mt-2">预设图标来自 Twemoji（CC-BY 4.0）</p>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { supabase, storagePublicUrl } from '@/utils/supabase'
import { compressImage } from '@/utils/image'
import { TEAM_LOGO_PRESETS } from '@/utils/teamLogos'

const props = defineProps({
  modelValue: { type: String, default: '' },
  teamColor: { type: String, default: '' },
  fallbackChar: { type: String, default: '队' },
  // 上传路径用的稳定标识：编辑球队时传球队 ID，创建时留空自动生成
  uid: { type: String, default: '' }
})
const emit = defineEmits(['update:modelValue'])

const fileInput = ref(null)
const uploading = ref(false)

const accent = computed(() => props.teamColor || '#3b82f6')
const tint = computed(() => accent.value + '20')
const border = computed(() => accent.value + '60')

function pickFile() {
  fileInput.value?.click()
}

async function handleFile(e) {
  const file = e.target.files?.[0]
  e.target.value = '' // 允许再次选择同一张图片
  if (!file) return
  if (!file.type || !file.type.startsWith('image/')) {
    alert('请选择图片文件')
    return
  }
  uploading.value = true
  try {
    // PNG/WebP/SVG 带透明通道，输出 PNG 以免透明区域变成黑底
    const keepAlpha = ['image/png', 'image/webp', 'image/svg+xml'].includes(file.type)
    const res = await compressImage(file, {
      maxDim: 512,
      maxSize: 300 * 1024,
      mimeType: keepAlpha ? 'image/png' : 'image/jpeg'
    })
    if (!res) {
      alert('图片处理失败，请换一张重试')
      return
    }
    const ext = (res.file.name.split('.').pop() || 'jpg').toLowerCase()
    const key = props.uid || (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()))
    const path = `teams/${key}.${ext}`
    const { error } = await supabase.storage
      .from('avatars')
      .upload(path, res.file, { upsert: true, contentType: res.file.type })
    if (error) throw error
    const publicUrl = storagePublicUrl('avatars', path)
    emit('update:modelValue', publicUrl + '?t=' + Date.now())
  } catch (err) {
    console.error('队标上传失败:', err)
    alert('队标上传失败：' + (err.message || '请稍后重试'))
  } finally {
    uploading.value = false
  }
}
</script>
